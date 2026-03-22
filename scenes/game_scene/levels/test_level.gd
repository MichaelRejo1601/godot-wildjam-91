extends Node2D

signal level_lost
@export_file("*.tscn") var gameOver : String
@export_file("*.tscn") var nextLevel : String
const PLACEHOLDER_SCENES := {
	"res://scenes/Sentinel/Sentinel.tscn": true,
	"res://scenes/Mummy/Mummy.tscn": true,
	"res://scenes/Chest/Chest.tscn": true,
}

func _ready() -> void:
	# Store the level start time for death screen to calculate time survived
	get_tree().root.set_meta("level_start_time", Time.get_ticks_msec())

	_clear_editor_placed_entities()
	print("Test level loaded: spawning test objects")
	# Defer so Dungeon._ready() has generated the tilemap before we query sand cells.
	call_deferred("_place_player_on_sand")
	call_deferred("_setup_health_bar")
	call_deferred("_setup_madness_bar")
	call_deferred("_setup_coin_bar")
	call_deferred("_setup_exit_door")


func _clear_editor_placed_entities() -> void:
	# Remove pre-placed actors/props from the level so runtime generation is authoritative.
	_clear_placeholder_children(self)

	var dungeon = get_node_or_null("Dungeon")
	if dungeon != null:
		_clear_placeholder_children(dungeon)


func _clear_placeholder_children(parent_node: Node) -> void:
	for child in parent_node.get_children():
		# Runtime-instanced nodes have no owner; editor-placed placeholders do.
		if child.owner != null and PLACEHOLDER_SCENES.has(child.scene_file_path):
			child.queue_free()


func _place_player_on_sand() -> void:
	var dungeon = get_node_or_null("Dungeon")
	var player = get_node_or_null("Player")
	if dungeon == null or player == null:
		push_warning("TestLevel: Missing Dungeon or Player node; cannot place player on sand.")
		return

	var sand_layer = dungeon.get_node_or_null("SandTileMapLayer") as TileMapLayer
	if sand_layer == null:
		push_warning("TestLevel: Missing SandTileMapLayer; cannot place player on sand.")
		return

	var sand_cells = sand_layer.get_used_cells()
	if sand_cells.is_empty():
		push_warning("TestLevel: No generated sand cells found for player spawn.")
		return

	var spawn_cell: Vector2i = sand_cells.pick_random()
	player.global_position = sand_layer.to_global(sand_layer.map_to_local(spawn_cell))


func _setup_health_bar() -> void:
	var player = get_node_or_null("Player/Player")
	if player == null:
		# Backward compatibility if the character body keeps its older node name.
		player = get_node_or_null("Player/CharacterBody2D")
	var health_bar = get_node_or_null("UI/HealthBar")
	if player == null or health_bar == null:
		push_warning("TestLevel: Missing Player or HealthBar; cannot wire health UI.")
		return

	if player.has_signal("health_changed"):
		player.health_changed.connect(Callable(health_bar, "update_health"))

	if health_bar.has_method("set_max_health") and player.has_method("get_max_health"):
		health_bar.set_max_health(int(player.get_max_health()))

	health_bar.update_health(player.current_health)


func _setup_madness_bar() -> void:
	var player = get_node_or_null("Player/Player")
	if player == null:
		# Backward compatibility if the character body keeps its older node name.
		player = get_node_or_null("Player/CharacterBody2D")
	var madness_bar = get_node_or_null("UI/MadnessBar")
	if player == null or madness_bar == null:
		push_warning("TestLevel: Missing Player or MadnessBar; cannot wire madness UI.")
		return

	if player.has_signal("madness_changed"):
		player.madness_changed.connect(Callable(madness_bar, "update_madness"))

	madness_bar.update_madness(player.current_madness)


func _setup_coin_bar() -> void:
	var player = get_node_or_null("Player/Player")
	if player == null:
		# Backward compatibility if the character body keeps its older node name.
		player = get_node_or_null("Player/CharacterBody2D")
	var coin_bar = get_node_or_null("UI/CoinBar")
	if player == null or coin_bar == null:
		push_warning("TestLevel: Missing Player or CoinBar; cannot wire coin UI.")
		return

	if player.has_signal("coins_changed"):
		player.coins_changed.connect(Callable(coin_bar, "update_coins"))

	if coin_bar.has_method("update_coins"):
		coin_bar.update_coins(player.current_coins)


func _on_health_bar_death() -> void:
	level_lost.emit()

	# Lock player controls to prevent further input
	var player = get_node_or_null("Player/Player")
	if player == null:
		player = get_node_or_null("Player/CharacterBody2D")
	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)

	# Store the current level path so death screen can reload it
	var level_path = get_scene_file_path()
	get_tree().root.set_meta("last_level_path", level_path)

	if gameOver and not gameOver.is_empty():
		SceneLoader.load_scene(gameOver, false)
	else:
		# Fallback to death screen if gameOver path not set
		SceneLoader.load_scene("res://scenes/windows/death_screen.tscn", false)


func _setup_exit_door() -> void:
	var dungeon = get_node_or_null("Dungeon")
	if dungeon == null:
		return
	if dungeon.has_signal("exit_door_entered"):
		dungeon.exit_door_entered.connect(_on_exit_door_entered)


func _on_exit_door_entered() -> void:
	var target := nextLevel if not nextLevel.is_empty() else gameOver
	if not target.is_empty():
		SceneLoader.load_scene(target, false)
