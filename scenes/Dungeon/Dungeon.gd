extends Node2D

@onready var sand_layer: TileMapLayer = $SandTileMapLayer

const SOURCE_ID = 0
const SAND_TILE = Vector2i(0, 0)

const MAP_SIZE = 80

const ROOM_MIN_SIZE = 4
const ROOM_MAX_SIZE = 10
const ROOM_COUNT = 12

var rng = RandomNumberGenerator.new()

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

	var rooms: Array = []

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


func carve_room(room: Room):
	for x in range(room.rect.position.x, room.rect.end.x):
		for y in range(room.rect.position.y, room.rect.end.y):
			sand_layer.set_cell(Vector2i(x, y), SOURCE_ID, SAND_TILE)


func connect_rooms(a: Room, b: Room):
	var start = a.center()
	var end = b.center()

	if rng.randf() < 0.5:
		carve_h_corridor(start.x, end.x, start.y)
		carve_v_corridor(start.y, end.y, end.x)
	else:
		carve_v_corridor(start.y, end.y, start.x)
		carve_h_corridor(start.x, end.x, end.y)


func carve_h_corridor(x1: int, x2: int, y: int):
	for x in range(min(x1, x2), max(x1, x2) + 1):
		sand_layer.set_cell(Vector2i(x, y), SOURCE_ID, SAND_TILE)


func carve_v_corridor(y1: int, y2: int, x: int):
	for y in range(min(y1, y2), max(y1, y2) + 1):
		sand_layer.set_cell(Vector2i(x, y), SOURCE_ID, SAND_TILE)
