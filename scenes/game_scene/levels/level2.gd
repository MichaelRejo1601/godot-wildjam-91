extends "res://scenes/game_scene/levels/test_level.gd"


@export var playerCoord: Vector2i = Vector2i(2, 5)
@export var chestCoord: Vector2i = Vector2i(10, 5)
@export var bossSpawnCoord: Vector2i = Vector2i(2, 5)
@export var chest: PackedScene
@export var game_win_scene: PackedScene
@export var game_over_scene: PackedScene
@export var boss_health_bar_world_offset: Vector2 = Vector2(0, -54)


func _ready() -> void:
	# Keep shared level lifecycle metadata and editor cleanup from level 1.
	get_tree().root.set_meta("level_start_time", Time.get_ticks_msec())
	if game_over_scene != null:
		gameOver = game_over_scene.resource_path
	_clear_editor_placed_entities()
	call_deferred("_place_player_on_sand")
	call_deferred("_setup_health_bar")
	call_deferred("_setup_madness_bar")
	call_deferred("_setup_coin_bar")
	call_deferred("_setup_boss_health_bar")


func _process(_delta: float) -> void:
	_update_boss_health_bar_position()


func _place_player_on_sand() -> void:
	var player = get_node_or_null("Player")
	var boss = get_node_or_null("Boss")
	var sand_layer := _get_level2_sand_layer()
	if sand_layer == null or player == null:
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

	var spawn_chest: Vector2i = chestCoord
	var chest_instance = chest.instantiate()
	add_child(chest_instance)
	if chest_instance is Node2D:
		(chest_instance as Node2D).global_position = sand_layer.to_global(sand_layer.map_to_local(spawn_chest))
	if chest_instance.has_signal("spawnBoss"):
		chest_instance.spawnBoss.connect(_on_spawn_boss)


func _on_spawn_boss(_pos: Vector2) -> void:
	var boss = get_node_or_null("Boss")
	var sand_layer := _get_level2_sand_layer()
	if sand_layer == null or boss == null:
		return

	boss.global_position = sand_layer.to_global(sand_layer.map_to_local(bossSpawnCoord))
	boss.visible = true
	boss.process_mode = Node.PROCESS_MODE_INHERIT

	var boss_health_bar = get_node_or_null("UI/BossHealthBar")
	if boss_health_bar != null:
		if boss.has_method("get"):
			boss_health_bar.update_health(boss.get("current_health"))
		boss_health_bar.show()


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
