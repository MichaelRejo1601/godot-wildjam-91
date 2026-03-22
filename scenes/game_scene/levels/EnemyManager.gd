
extends Node2D

const sentinal = preload("res://scenes/Sentinel/Sentinel.tscn")
const mummy = preload("res://scenes/Mummy/Mummy.tscn")
const mummyDeath = preload("res://scenes/Mummy/MummyDeath.tscn")
@export var dungeon_path: NodePath

@export var minEnemiesPerRoom: int = 1
@export var maxEnemiesPerRoom: int = 3
@export_range(0.0, 1.0, 0.01) var sentinel_spawn_chance: float = 0.5

var seen = {}

var rooms: Array = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Defer so Dungeon._ready() (and generate_dungeon) runs first
	call_deferred("_load_rooms")


func _load_rooms() -> void:

	var dungeon = get_node_or_null(dungeon_path)
	var sand_layer = dungeon.get_node("SandTileMapLayer") as TileMapLayer
	var player_node = get_tree().get_first_node_in_group("player")

	if dungeon:
		rooms = dungeon.rooms
		for r in rooms:
			var enemies_in_this_room: int = randi_range(minEnemiesPerRoom, maxEnemiesPerRoom)
			for _i in range(enemies_in_this_room):
				var spawn_cell := _pick_room_spawn_cell(r)
				if randf() <= sentinel_spawn_chance:
					var sent = sentinal.instantiate()
					sent.global_position = sand_layer.to_global(sand_layer.map_to_local(spawn_cell))
					add_child(sent)
					if player_node:
						sent.player = player_node
				else:
					var mum = mummy.instantiate()
					mum.global_position = sand_layer.to_global(sand_layer.map_to_local(spawn_cell))
					add_child(mum)
					if player_node:
						mum.player = player_node
					mum.about_to_be_deleted.connect(_on_mummy_about_to_be_deleted)
			# print("Loading Room: ", r.center())
	else:
		push_warning("EnemyManager: dungeon_path is not set or node not found.")


func _pick_room_spawn_cell(room) -> Vector2i:
	if room == null or not room.has_method("center"):
		return Vector2i.ZERO
	if "rect" not in room or room.rect.size == Vector2i.ZERO:
		return room.center()

	var x_min: int = room.rect.position.x
	var x_max: int = room.rect.end.x - 1
	var y_min: int = room.rect.position.y
	var y_max: int = room.rect.end.y - 1
	if x_max < x_min or y_max < y_min:
		return room.center()

	return Vector2i(randi_range(x_min, x_max), randi_range(y_min, y_max))


func _on_mummy_about_to_be_deleted(dead_enemy: CharacterBody2D) -> void:
	# pos = dead_enemy.position
	print("Mummy Death")
	if not seen.has(Vector2i(dead_enemy.global_position) % 16):
		seen[Vector2i(dead_enemy.global_position) % 16] = true
	
		var mumDeath := mummyDeath.instantiate() as Node2D
		_place_ground_decal(mumDeath, dead_enemy.global_position)
	else:
		return
	pass # Replace with function body.


func _place_ground_decal(decal: Node2D, world_position: Vector2) -> void:
	if decal == null:
		return

	var scene := get_tree().current_scene
	if scene == null:
		return

	var parent: Node = scene.get_node_or_null("Dungeon")
	if parent == null:
		parent = self

	parent.add_child(decal)
	decal.global_position = world_position
	decal.z_index = 0

	if parent.name == "Dungeon":
		var sand_layer := parent.get_node_or_null("SandTileMapLayer")
		var chest_node := parent.get_node_or_null("Chest")
		var target_index: int = parent.get_child_count() - 1
		if sand_layer != null:
			target_index = sand_layer.get_index() + 1
		if chest_node != null:
			target_index = chest_node.get_index()
		parent.move_child(decal, target_index)
