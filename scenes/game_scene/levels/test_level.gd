extends Node2D

func _ready() -> void:
	print("Test level loaded: spawning test objects")
	# Defer so Dungeon._ready() has generated the tilemap before we query sand cells.
	call_deferred("_place_player_on_sand")
	call_deferred("_setup_health_bar")
	call_deferred("_setup_madness_bar")


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
