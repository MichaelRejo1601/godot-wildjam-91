extends Node2D

@onready var sand_layer: TileMapLayer = $SandTileMapLayer
@onready var wall_layer: TileMapLayer = $WallTileMapLayer

const SOURCE_ID = 0
const SAND_TILE = Vector2i(0, 0)

const MAP_SIZE = 80
const ROOM_MIN_SIZE = 4
const ROOM_MAX_SIZE = 10
const ROOM_COUNT = 12

var rng = RandomNumberGenerator.new()

# --- AUTOTILE MAP (YOU FILL THIS) ---
var WALL_TILES = {
	# bitmask : atlas coord
	# examples (fill based on your tileset)
	0: Vector2i(1,1), # default / fallback

	# straight
	2: Vector2i(1,0),   # top
	64: Vector2i(1,2),  # bottom
	8: Vector2i(0,1),   # left
	16: Vector2i(2,1),  # right

	# corners (example mapping)
	2 + 8: Vector2i(0,0),	# top-left
	2 + 16: Vector2i(2,0),   # top-right
	64 + 8: Vector2i(0,2),   # bottom-left
	64 + 16: Vector2i(2,2),  # bottom-right

	# Note: Outer corners (convex) usually use the default wall tile (0) unless your tileset provides a special tile for them.
}


class Room:
	var rect: Rect2i
	func _init(r): rect = r
	func center(): return rect.position + rect.size / 2


func _ready():
	if sand_layer == null or wall_layer == null:
		push_error("Assign layers in inspector")
		return

	rng.randomize()
	generate_dungeon()


# ---------------- DUNGEON ----------------

func generate_dungeon():
	sand_layer.clear()
	wall_layer.clear()

	var rooms = []

	for i in range(ROOM_COUNT):
		var w = rng.randi_range(ROOM_MIN_SIZE, ROOM_MAX_SIZE)
		var h = rng.randi_range(ROOM_MIN_SIZE, ROOM_MAX_SIZE)

		var x = rng.randi_range(-MAP_SIZE/2, MAP_SIZE/2 - w)
		var y = rng.randi_range(-MAP_SIZE/2, MAP_SIZE/2 - h)

		var room = Room.new(Rect2i(x,y,w,h))

		var overlaps = false
		for r in rooms:
			if r.rect.intersects(room.rect.grow(1)):
				overlaps = true
				break

		if overlaps:
			continue

		carve_room(room)

		if rooms.size() > 0:
			connect_rooms(rooms[-1], room)

		rooms.append(room)

	generate_walls_autotile()


func carve_room(room):
	for x in range(room.rect.position.x, room.rect.end.x):
		for y in range(room.rect.position.y, room.rect.end.y):
			sand_layer.set_cell(Vector2i(x,y), SOURCE_ID, SAND_TILE)


func connect_rooms(a, b):
	var start = a.center()
	var end = b.center()

	if rng.randf() < 0.5:
		carve_h(start.x, end.x, start.y)
		carve_v(start.y, end.y, end.x)
	else:
		carve_v(start.y, end.y, start.x)
		carve_h(start.x, end.x, end.y)


func carve_h(x1, x2, y):
	for x in range(min(x1,x2), max(x1,x2)+1):
		sand_layer.set_cell(Vector2i(x,y), SOURCE_ID, SAND_TILE)


func carve_v(y1, y2, x):
	for y in range(min(y1,y2), max(y1,y2)+1):
		sand_layer.set_cell(Vector2i(x,y), SOURCE_ID, SAND_TILE)


# ---------------- AUTOTILE WALLS ----------------

func generate_walls_autotile():
	var used = sand_layer.get_used_cells()
	if used.is_empty():
		return

	# Get bounds
	var min_x = used[0].x
	var max_x = used[0].x
	var min_y = used[0].y
	var max_y = used[0].y

	for c in used:
		min_x = min(min_x, c.x)
		max_x = max(max_x, c.x)
		min_y = min(min_y, c.y)
		max_y = max(max_y, c.y)

	# Expand bounds by 1
	min_x -= 1
	max_x += 1
	min_y -= 1
	max_y += 1

	# First pass: normal autotiling
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var pos = Vector2i(x, y)
			if is_sand(pos):
				continue
			var mask = get_bitmask(pos)
			if mask != 0:
				var tile = pick_tile(mask)
				wall_layer.set_cell(pos, SOURCE_ID, tile)

	# Second pass: fill outer corners missed by autotiling
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var pos = Vector2i(x, y)
			if is_sand(pos):
				continue
			if wall_layer.get_cell_source_id(pos) != -1:
				continue
			# Check for diagonal sand with no cardinal sand
			var found_outer_corner = false
			if is_sand(pos + Vector2i(-1, -1)) and not is_sand(pos + Vector2i(-1, 0)) and not is_sand(pos + Vector2i(0, -1)):
				found_outer_corner = true
			elif is_sand(pos + Vector2i(1, -1)) and not is_sand(pos + Vector2i(1, 0)) and not is_sand(pos + Vector2i(0, -1)):
				found_outer_corner = true
			elif is_sand(pos + Vector2i(-1, 1)) and not is_sand(pos + Vector2i(-1, 0)) and not is_sand(pos + Vector2i(0, 1)):
				found_outer_corner = true
			elif is_sand(pos + Vector2i(1, 1)) and not is_sand(pos + Vector2i(1, 0)) and not is_sand(pos + Vector2i(0, 1)):
				found_outer_corner = true
			if found_outer_corner:
				wall_layer.set_cell(pos, SOURCE_ID, WALL_TILES[0])


func get_bitmask(pos: Vector2i) -> int:
	var mask = 0

	var up = is_sand(pos + Vector2i.UP)
	var down = is_sand(pos + Vector2i.DOWN)
	var left = is_sand(pos + Vector2i.LEFT)
	var right = is_sand(pos + Vector2i.RIGHT)

	# Cardinals
	if up: mask |= 2
	if down: mask |= 64
	if left: mask |= 8
	if right: mask |= 16

	# Diagonals ONLY if both adjacent cardinals exist
	if up and left and is_sand(pos + Vector2i(-1,-1)): mask |= 1
	if up and right and is_sand(pos + Vector2i(1,-1)): mask |= 4
	if down and left and is_sand(pos + Vector2i(-1,1)): mask |= 32
	if down and right and is_sand(pos + Vector2i(1,1)): mask |= 128

	return mask


func is_sand(pos: Vector2i) -> bool:
	return sand_layer.get_cell_source_id(pos) != -1


func pick_tile(mask: int) -> Vector2i:
	# Exact match
	if WALL_TILES.has(mask):
		return WALL_TILES[mask]

	# Strip diagonals → keep only cardinal
	var reduced = mask & (2 | 8 | 16 | 64)

	if WALL_TILES.has(reduced):
		return WALL_TILES[reduced]

	# Final fallback based on priority
	if reduced & 2: return WALL_TILES[2]
	if reduced & 64: return WALL_TILES[64]
	if reduced & 8: return WALL_TILES[8]
	if reduced & 16: return WALL_TILES[16]

	return WALL_TILES[0]
