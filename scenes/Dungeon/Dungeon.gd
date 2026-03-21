class_name Dungeon
extends Node2D

@onready var sand_layer: TileMapLayer = $SandTileMapLayer
@onready var wall_layer: TileMapLayer = $WallTileMapLayer
@onready var sandy_wall_layer: TileMapLayer = $SandyWallTileMapLayer 

const SOURCE_ID = 0
const SAND_TILES: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(2, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(2, 1),
	Vector2i(0, 2),
	Vector2i(1, 2),
	Vector2i(2, 2),
]
const WALL_TERRAIN_SET = 0
const WALL_TERRAIN = 0

const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
]

const MAP_SIZE = 80

const ROOM_MIN_SIZE = 4
const ROOM_MAX_SIZE = 10
const ROOM_COUNT = 12
const CHEST_ROOM_CHANCE = 0.35
const CORRIDOR_NARROW_CHANCE = 0.2
var rooms: Array = []
var spawned_chests: Array[Node] = []

var rng = RandomNumberGenerator.new()
var chest_scene = preload("res://scenes/Chest/Chest.tscn")

class Room:
	var rect: Rect2i
	
	func _init(r):
		rect = r
	
	func center() -> Vector2i:
		return rect.position + rect.size / 2


func _ready():
	rng.randomize()
	generate_dungeon()


func generate_dungeon():
	sand_layer.clear()
	wall_layer.clear()
	sandy_wall_layer.clear()
	rooms.clear()
	clear_spawned_chests()

	for i in range(ROOM_COUNT):
		var w = rng.randi_range(ROOM_MIN_SIZE, ROOM_MAX_SIZE)
		var h = rng.randi_range(ROOM_MIN_SIZE, ROOM_MAX_SIZE)

		var x = rng.randi_range(-MAP_SIZE/2, MAP_SIZE/2 - w)
		var y = rng.randi_range(-MAP_SIZE/2, MAP_SIZE/2 - h)

		var new_room = Room.new(Rect2i(x, y, w, h))

		var overlaps = false
		for r in rooms:
			if r.rect.intersects(new_room.rect.grow(1)):
				overlaps = true
				break

		if overlaps:
			continue

		carve_room(new_room)

		if rooms.size() > 0:
			connect_rooms(rooms[-1], new_room)

		rooms.append(new_room)

	build_walls_around_sand()
	spawn_chests_in_rooms()


func build_walls_around_sand():
	var wall_candidates: Dictionary = {}

	for sand_cell in sand_layer.get_used_cells():
		for offset in NEIGHBOR_OFFSETS:
			var neighbor = sand_cell + offset
			if sand_layer.get_cell_source_id(neighbor) == -1:
				wall_candidates[neighbor] = true

	var wall_cells: Array[Vector2i] = []
	for cell in wall_candidates.keys():
		wall_cells.append(cell)

	if wall_cells.is_empty():
		return

	# Use terrain connect so the wall atlas picks correct edge/corner variants.
	wall_layer.set_cells_terrain_connect(wall_cells, WALL_TERRAIN_SET, WALL_TERRAIN)


func carve_room(room: Room):
	for x in range(room.rect.position.x, room.rect.end.x):
		for y in range(room.rect.position.y, room.rect.end.y):
			set_random_sand_cell(Vector2i(x, y))


func connect_rooms(a: Room, b: Room):
	var start = a.center()
	var end = b.center()
	var corridor_width = 1 if rng.randf() < CORRIDOR_NARROW_CHANCE else 2

	if rng.randf() < 0.5:
		carve_h_corridor(start.x, end.x, start.y, corridor_width)
		carve_v_corridor(start.y, end.y, end.x, corridor_width)
	else:
		carve_v_corridor(start.y, end.y, start.x, corridor_width)
		carve_h_corridor(start.x, end.x, end.y, corridor_width)



func carve_h_corridor(x1: int, x2: int, y: int, width: int):
	var y_offsets = get_corridor_offsets(width)
	for x in range(min(x1, x2), max(x1, x2) + 1):
		for y_offset in y_offsets:
			set_random_sand_cell(Vector2i(x, y + y_offset))



func carve_v_corridor(y1: int, y2: int, x: int, width: int):
	var x_offsets = get_corridor_offsets(width)
	for y in range(min(y1, y2), max(y1, y2) + 1):
		for x_offset in x_offsets:
			set_random_sand_cell(Vector2i(x + x_offset, y))


func get_corridor_offsets(width: int) -> Array[int]:
	if width <= 1:
		return [0]

	if width == 2:
		if rng.randf() < 0.5:
			return [0, 1]
		return [-1, 0]

	var offsets: Array[int] = []
	var half := int(floor(width / 2.0))
	for i in range(-half, half + 1):
		offsets.append(i)
	return offsets


func set_random_sand_cell(cell: Vector2i):
	var sand_tile = SAND_TILES[rng.randi_range(0, SAND_TILES.size() - 1)]
	sand_layer.set_cell(cell, SOURCE_ID, sand_tile)


func clear_spawned_chests():
	for chest in spawned_chests:
		if is_instance_valid(chest):
			chest.queue_free()
	spawned_chests.clear()


func spawn_chests_in_rooms():
	for room in rooms:
		if rng.randf() > CHEST_ROOM_CHANCE:
			continue

		var chest = chest_scene.instantiate()

		var chest_cell = room.center()
		chest.global_position = sand_layer.to_global(sand_layer.map_to_local(chest_cell))
		add_child(chest)
		spawned_chests.append(chest)
