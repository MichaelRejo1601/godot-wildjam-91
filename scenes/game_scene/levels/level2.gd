extends "res://scenes/game_scene/levels/test_level.gd"

const SquareArenaDungeonScene = preload("res://scenes/DungeonLevel2/DungeonLevel2.tscn")


@export var playerCoord: Vector2i = Vector2i(2, 5)
@export var chestCoord: Vector2i = Vector2i(10, 5)
@export var bossSpawnCoord: Vector2i = Vector2i(2, 5)
@export var chest: PackedScene
@export var game_win_scene: PackedScene
@export var game_over_scene: PackedScene
@export var boss_health_bar_world_offset: Vector2 = Vector2(0, -54)
@export_file("*.mp3") var boss_ost_path: String = "res://assets/ost_2.mp3"
@export var boss_intro_zoom_in_factor: float = 1.02
@export var boss_intro_zoom_in_time: float = 0.30
@export var boss_intro_hold_time: float = 0.35
@export var boss_intro_drop_height: float = 220.0
@export var boss_intro_drop_time: float = 0.65
@export var boss_intro_zoom_out_time: float = 0.35
@export var boss_intro_final_vertical_offset: float = 70.0
@export var boss_intro_orbit_duration: float = 20.0
@export var boss_intro_orbit_turns: float = 3.0
@export var boss_intro_orbit_radius: float = 120.0
@export var boss_intro_orbit_vertical_offset: float = -20.0
@export var boss_ost_intro_end_time: float = 20.0
@export var boss_ost_loop_end_time: float = 42.0

var _boss_intro_in_progress: bool = false
var _boss_intro_watchdog_remaining: float = 0.0
var _boss_intro_player: Node2D = null
var _boss_intro_boss: Node2D = null
var _boss_intro_orbit_elapsed: float = 0.0
var _boss_intro_orbit_start_angle: float = 0.0
var _boss_music_player: AudioStreamPlayer = null
var _boss_music_loop_active: bool = false


func _ready() -> void:
	_disable_level1_runtime_nodes()
	_ensure_boss_music_player()
	if game_over_scene != null:
		gameOver = game_over_scene.resource_path
	_swap_in_square_arena_dungeon()
	# Reuse base level setup so shared UI and environment logic stay unified.
	super._ready()
	call_deferred("_restore_transition_player_stats")
	call_deferred("_setup_boss_health_bar")


func _process(_delta: float) -> void:
	_update_boss_intro_orbit(_delta)
	_update_boss_music_loop()
	_update_boss_intro_watchdog(_delta)
	_update_boss_health_bar_position()


func _place_player_on_sand() -> void:
	var player = get_node_or_null("Player")
	var boss = get_node_or_null("Boss")
	var sand_layer := _get_level2_sand_layer()
	if sand_layer == null or not is_instance_valid(sand_layer) or player == null:
		push_warning("Level2: Missing Dungeon or Player node; cannot place player on sand.")
		return

	var sand_cells = sand_layer.get_used_cells()
	if sand_cells.is_empty():
		push_warning("Level2: No generated sand cells found for player spawn.")
		return

	var spawn_cell: Vector2i = playerCoord
	player.global_position = sand_layer.to_global(sand_layer.map_to_local(spawn_cell))
	if boss != null:
		boss.global_position = sand_layer.to_global(sand_layer.map_to_local(bossSpawnCoord))
		# Hide boss until chest is opened.
		boss.visible = false
		boss.process_mode = Node.PROCESS_MODE_DISABLED

	var boss_health_bar = get_node_or_null("UI/BossHealthBar")
	if boss_health_bar != null:
		boss_health_bar.hide()

	if chest == null:
		push_warning("Level2: Missing chest scene; boss spawn sequence will not start.")
		return

	var spawn_chest: Vector2i = _get_arena_center_cell(sand_layer)
	var chest_instance = chest.instantiate()
	add_child(chest_instance)
	if chest_instance is Node2D:
		(chest_instance as Node2D).global_position = sand_layer.to_global(sand_layer.map_to_local(spawn_chest))
	if chest_instance.has_signal("spawnBoss"):
		chest_instance.spawnBoss.connect(_on_spawn_boss)


func _on_spawn_boss(_pos: Vector2) -> void:
	if _boss_intro_in_progress:
		return

	var boss = get_node_or_null("Boss")
	var sand_layer := _get_level2_sand_layer()
	if sand_layer == null or not is_instance_valid(sand_layer) or boss == null:
		return

	var player_for_intro := _get_level_player_body()
	if player_for_intro == null or not is_instance_valid(player_for_intro):
		return

	# Always stage the intro relative to player so the bee is visible and above the action.
	var intro_anchor := player_for_intro.global_position

	# Keep the bee's orbit centered above player/chest area.
	var boss_spawn_position := intro_anchor + Vector2(0.0, boss_intro_orbit_vertical_offset)
	boss.global_position = boss_spawn_position
	boss.visible = true
	boss.process_mode = Node.PROCESS_MODE_DISABLED

	var boss_health_bar = get_node_or_null("UI/BossHealthBar")
	if boss_health_bar != null:
		boss_health_bar.hide()

	_boss_intro_in_progress = true
	_boss_intro_player = player_for_intro
	_boss_intro_boss = boss
	_boss_intro_orbit_elapsed = 0.0
	_boss_intro_orbit_start_angle = (boss.global_position - (player_for_intro.global_position + Vector2(0.0, boss_intro_orbit_vertical_offset))).angle()
	_boss_intro_watchdog_remaining = maxf(
		boss_intro_orbit_duration + boss_intro_zoom_in_time + boss_intro_zoom_out_time + 1.5,
		1.5
	)
	_set_player_controls_locked(player_for_intro, true)
	_start_boss_music_intro()
	await _play_boss_intro_sequence(boss, boss_spawn_position)
	_finish_boss_intro()


func _finish_boss_intro() -> void:
	if _boss_intro_player != null and is_instance_valid(_boss_intro_player):
		_set_player_controls_locked(_boss_intro_player, false)

	var boss = get_node_or_null("Boss")
	var boss_health_bar = get_node_or_null("UI/BossHealthBar")
	if boss != null and is_instance_valid(boss):
		boss.process_mode = Node.PROCESS_MODE_INHERIT
		if boss_health_bar != null:
			if boss.has_method("get"):
				boss_health_bar.update_health(boss.get("current_health"))
			boss_health_bar.show()
	_start_boss_music_loop_segment()

	_boss_intro_player = null
	_boss_intro_boss = null
	_boss_intro_in_progress = false
	_boss_intro_watchdog_remaining = 0.0


func _update_boss_intro_watchdog(delta: float) -> void:
	if not _boss_intro_in_progress:
		return
	_boss_intro_watchdog_remaining -= delta
	if _boss_intro_watchdog_remaining > 0.0:
		return
	# Emergency fallback: never allow intro flow to soft-lock player controls.
	_finish_boss_intro()


func _play_boss_intro_sequence(boss: Node2D, target_position: Vector2) -> void:
	if boss == null or not is_instance_valid(boss):
		return

	var player := _get_level_player_body()
	var player_camera := _get_player_camera(player)
	var original_zoom := Vector2.ONE

	if player_camera != null:
		original_zoom = player_camera.zoom

	boss.global_position = target_position
	boss.visible = true

	var zoom_in_tween: Tween = null
	if player_camera != null:
		zoom_in_tween = create_tween()
		zoom_in_tween.set_trans(Tween.TRANS_SINE)
		zoom_in_tween.set_ease(Tween.EASE_OUT)
		zoom_in_tween.tween_property(
			player_camera,
			"zoom",
			original_zoom * boss_intro_zoom_in_factor,
			maxf(boss_intro_zoom_in_time, 0.05)
		)

	if zoom_in_tween != null:
		await zoom_in_tween.finished

	await get_tree().create_timer(maxf(boss_intro_orbit_duration, 0.01)).timeout

	if player_camera != null:
		var zoom_out_tween := create_tween()
		zoom_out_tween.set_trans(Tween.TRANS_SINE)
		zoom_out_tween.set_ease(Tween.EASE_IN_OUT)
		zoom_out_tween.tween_property(player_camera, "zoom", original_zoom, maxf(boss_intro_zoom_out_time, 0.05))
		await zoom_out_tween.finished


func _update_boss_intro_orbit(delta: float) -> void:
	if not _boss_intro_in_progress:
		return
	if _boss_intro_player == null or not is_instance_valid(_boss_intro_player):
		return
	if _boss_intro_boss == null or not is_instance_valid(_boss_intro_boss):
		return

	var duration := maxf(boss_intro_orbit_duration, 0.01)
	_boss_intro_orbit_elapsed = min(_boss_intro_orbit_elapsed + delta, duration)
	var t := clampf(_boss_intro_orbit_elapsed / duration, 0.0, 1.0)
	var angle := _boss_intro_orbit_start_angle + (TAU * boss_intro_orbit_turns * t)
	var center := _boss_intro_player.global_position + Vector2(0.0, boss_intro_orbit_vertical_offset)
	var orbit_pos := center + Vector2.RIGHT.rotated(angle) * boss_intro_orbit_radius
	_boss_intro_boss.global_position = orbit_pos


func _ensure_boss_music_player() -> void:
	if _boss_music_player != null and is_instance_valid(_boss_music_player):
		return
	var existing := get_node_or_null("BossMusicPlayer") as AudioStreamPlayer
	if existing != null:
		_boss_music_player = existing
		return
	_boss_music_player = AudioStreamPlayer.new()
	_boss_music_player.name = "BossMusicPlayer"
	add_child(_boss_music_player)


func _start_boss_music_intro() -> void:
	_ensure_boss_music_player()
	if _boss_music_player == null:
		return
	if _boss_music_player.stream == null:
		if not ResourceLoader.exists(boss_ost_path):
			push_warning("Level2: Missing boss OST at path: %s" % boss_ost_path)
			return
		_boss_music_player.stream = load(boss_ost_path) as AudioStream
		if _boss_music_player.stream == null:
			push_warning("Level2: Failed loading boss OST stream: %s" % boss_ost_path)
			return
	_boss_music_loop_active = false
	_boss_music_player.play(0.0)


func _start_boss_music_loop_segment() -> void:
	if _boss_music_player == null or _boss_music_player.stream == null:
		return
	_boss_music_loop_active = true
	if _boss_music_player.get_playback_position() < boss_ost_intro_end_time:
		_boss_music_player.seek(boss_ost_intro_end_time)
	if not _boss_music_player.playing:
		_boss_music_player.play()


func _update_boss_music_loop() -> void:
	if not _boss_music_loop_active:
		return
	if _boss_music_player == null or not is_instance_valid(_boss_music_player):
		return
	if _boss_music_player.stream == null or not _boss_music_player.playing:
		return

	if _boss_music_player.get_playback_position() >= boss_ost_loop_end_time:
		_boss_music_player.seek(boss_ost_intro_end_time)


func _get_level_player_body() -> Node2D:
	var player = get_node_or_null("Player/Player")
	if player == null:
		player = get_node_or_null("Player/CharacterBody2D")
	if player is Node2D:
		return player as Node2D
	return null


func _get_player_camera(player: Node2D) -> Camera2D:
	if player == null:
		return null
	return player.get_node_or_null("Camera2D") as Camera2D


func _set_player_controls_locked(player: Node2D, locked: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("set_controls_locked"):
		player.set_controls_locked(locked)


func _setup_exit_door() -> void:
	# Level 2 progression is boss-defeat based, not exit-door based.
	return


func _setup_boss_health_bar() -> void:
	var boss = get_node_or_null("Boss")
	var boss_health_bar = get_node_or_null("UI/BossHealthBar")
	if boss == null or boss_health_bar == null:
		push_warning("Level2: Missing Boss or BossHealthBar; cannot wire boss health UI.")
		return
	var boss_bar_sprite := boss_health_bar.get_node_or_null("Sprite2D") as Sprite2D
	if boss_bar_sprite != null:
		# Boss bar should be centered over the boss even though HUD bars may be top-left anchored.
		boss_bar_sprite.centered = true

	# Keep boss bar in a visible top-center position for this level UI.
	boss_health_bar.position = Vector2(320, 32)
	boss_health_bar.scale = Vector2(6, 6)

	if boss.has_signal("health_changed") and not boss.health_changed.is_connected(Callable(boss_health_bar, "update_health")):
		boss.health_changed.connect(Callable(boss_health_bar, "update_health"))

	if boss.has_signal("defeated") and not boss.defeated.is_connected(Callable(boss_health_bar, "hide")):
		boss.defeated.connect(Callable(boss_health_bar, "hide"))

	if boss_health_bar.has_method("set_max_health") and boss.has_method("get"):
		var boss_max_health = boss.get("max_health")
		if boss_max_health != null:
			boss_health_bar.set_max_health(int(boss_max_health))

	if boss.has_method("get"):
		boss_health_bar.update_health(boss.get("current_health"))

	# Boss is spawned by chest flow, so keep bar hidden until spawn callback fires.
	boss_health_bar.hide()


func _on_boss_defeated() -> void:
	var player = _get_level_player_body()
	var root = get_tree().root
	if player != null and root != null and player.has_method("get"):
		root.set_meta("win_coins", int(player.get("current_coins")))
		root.set_meta("win_bullets", int(player.get("current_bullets")))
	if game_win_scene != null:
		SceneLoader.load_scene(game_win_scene.resource_path, false)


func _update_boss_health_bar_position() -> void:
	var boss = get_node_or_null("Boss")
	var boss_health_bar = get_node_or_null("UI/BossHealthBar")
	if boss == null or boss_health_bar == null:
		return
	if not boss.visible or boss.process_mode == Node.PROCESS_MODE_DISABLED:
		return

	var world_position: Vector2 = boss.global_position + boss_health_bar_world_offset
	var screen_position: Vector2 = get_viewport().get_canvas_transform() * world_position
	boss_health_bar.position = screen_position


func _get_level2_sand_layer() -> TileMapLayer:
	var dungeon = get_node_or_null("Dungeon")
	if dungeon == null:
		return null
	return dungeon.get_node_or_null("SandTileMapLayer") as TileMapLayer


func _get_arena_center_cell(sand_layer: TileMapLayer) -> Vector2i:
	if sand_layer == null or not is_instance_valid(sand_layer):
		return Vector2i.ZERO
	var used_rect := sand_layer.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return Vector2i.ZERO
	var half_size := Vector2i(
		int(floor(float(used_rect.size.x) * 0.5)),
		int(floor(float(used_rect.size.y) * 0.5))
	)
	return used_rect.position + half_size


func _disable_level1_runtime_nodes() -> void:
	# Prevent inherited level-1 combat loop from running in boss level.
	var enemy_manager = get_node_or_null("EnemyManager")
	if enemy_manager != null:
		enemy_manager.queue_free()


func _swap_in_square_arena_dungeon() -> void:
	var old_dungeon = get_node_or_null("Dungeon")
	if old_dungeon != null:
		# Prevent path ambiguity while queued for deletion.
		old_dungeon.name = "DungeonOld"
		old_dungeon.queue_free()

	var new_dungeon = SquareArenaDungeonScene.instantiate()
	new_dungeon.name = "Dungeon"
	if new_dungeon.has_method("set"):
		new_dungeon.set("rectangleW", 40)
		new_dungeon.set("rectangleH", 40)
	if new_dungeon is Node2D:
		(new_dungeon as Node2D).z_index = -1
	add_child(new_dungeon)
	move_child(new_dungeon, 0)


func _restore_transition_player_stats() -> void:
	var player = get_node_or_null("Player/Player")
	if player == null:
		player = get_node_or_null("Player/CharacterBody2D")
	if player == null:
		return

	var root = get_tree().root
	if root == null:
		return

	if root.has_meta("transition_player_health"):
		player.current_health = int(root.get_meta("transition_player_health"))
	if root.has_meta("transition_player_madness"):
		player.current_madness = int(root.get_meta("transition_player_madness"))
	if root.has_meta("transition_player_coins"):
		player.current_coins = int(root.get_meta("transition_player_coins"))
	if root.has_meta("transition_player_bullets"):
		player.current_bullets = int(root.get_meta("transition_player_bullets"))

	if player.has_signal("health_changed"):
		player.health_changed.emit(player.current_health)
	if player.has_signal("madness_changed"):
		player.madness_changed.emit(player.current_madness)
	if player.has_signal("coins_changed"):
		player.coins_changed.emit(player.current_coins)
	if player.has_signal("bullets_changed"):
		player.bullets_changed.emit(player.current_bullets)

	if player.has_method("update_lantern_from_health"):
		player.update_lantern_from_health()
	if player.has_method("update_lantern_from_madness"):
		player.update_lantern_from_madness()

	root.remove_meta("transition_player_health")
	root.remove_meta("transition_player_madness")
	root.remove_meta("transition_player_coins")
	root.remove_meta("transition_player_bullets")
