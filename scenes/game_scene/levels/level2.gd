extends Node2D


@export var playerCoord: Vector2i = Vector2i(2, 5)
@export var chestCoord: Vector2i = Vector2i(10, 5)
@export var bossSpawnCoord: Vector2i = Vector2i(2, 5)
@export var chest: PackedScene
@export var healthBarScene : PackedScene
# Called when the node enters the scene tree for the first time.
func _ready() -> void:	
	# var bar = healthBarScene.instantiate()
	# add_child(bar)
	call_deferred("_place_player_on_sand")
	pass # Replace with function body.

func _place_player_on_sand() -> void:
	var dungeon = get_node_or_null("DungeonLevel2")
	var player = get_node_or_null("Player")
	var boss = get_node_or_null("Boss")
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

	var spawn_cell: Vector2i = playerCoord
	player.global_position = sand_layer.to_global(sand_layer.map_to_local(spawn_cell))

	# Hide boss until chest is opened
	if boss != null:
		boss.visible = false
		boss.process_mode = Node.PROCESS_MODE_DISABLED

	var spawnChest := chestCoord
	var c = chest.instantiate()
	add_child(c)
	c.global_position = sand_layer.to_global(sand_layer.map_to_local(spawnChest))
	c.spawnBoss.connect(_on_spawn_boss)


func _on_spawn_boss(pos: Vector2) -> void:
	var dungeon = get_node_or_null("DungeonLevel2")
	var player = get_node_or_null("Player")
	var boss = get_node_or_null("Boss")
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
	if boss == null:
		return
	boss.global_position = sand_layer.to_global(sand_layer.map_to_local(bossSpawnCoord))
	boss.visible = true
	boss.process_mode = Node.PROCESS_MODE_INHERIT
