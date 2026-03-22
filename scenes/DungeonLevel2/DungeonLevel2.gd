extends Node2D

var rng = RandomNumberGenerator.new()
@export var rectangleW : int = 40
@export var rectangleH : int = 40
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
const OUTER_WALL_PADDING = 20
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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sand_layer.clear()
	wall_layer.clear()
	sandy_wall_layer.clear()
	rng.randomize()
	generateDungeon()
	pass # Replace with function body.

func generateDungeon() -> void:
	var startPoint = Vector3.ZERO
	for x in range(startPoint.x, startPoint.y + rectangleW):
		for y in range(startPoint.y, startPoint.y + rectangleH):
			set_random_sand_cell(Vector2i(x, y))

	var wall_candidates: Dictionary = {}

	for sand_cell in sand_layer.get_used_cells():
		for offset in NEIGHBOR_OFFSETS:
			var neighbor = sand_cell + offset
			if sand_layer.get_cell_source_id(neighbor) == -1:
				wall_candidates[neighbor] = true

	# Fill additional outer space with walls so camera edges do not expose empty tiles.
	for outer_cell in _get_outer_padding_wall_cells(OUTER_WALL_PADDING):
		wall_candidates[outer_cell] = true

	var wall_cells: Array[Vector2i] = []
	for cell in wall_candidates.keys():
		wall_cells.append(cell)

	if wall_cells.is_empty():
		return
	wall_layer.set_cells_terrain_connect(wall_cells, WALL_TERRAIN_SET, WALL_TERRAIN)


func _get_outer_padding_wall_cells(padding: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if padding <= 0:
		return result

	var used_rect := sand_layer.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return result

	var expanded_rect := used_rect.grow(padding)
	for x in range(expanded_rect.position.x, expanded_rect.end.x):
		for y in range(expanded_rect.position.y, expanded_rect.end.y):
			var cell := Vector2i(x, y)
			if sand_layer.get_cell_source_id(cell) == -1:
				result.append(cell)

	return result



func set_random_sand_cell(cell: Vector2i):
	var sand_tile = SAND_TILES[rng.randi_range(0, SAND_TILES.size() - 1)]
	sand_layer.set_cell(cell, SOURCE_ID, sand_tile)
