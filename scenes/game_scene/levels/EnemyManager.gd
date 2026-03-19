
extends Node2D

const sentinal = preload("res://scenes/Sentinel/Sentinel.tscn")
@export var dungeon_path: NodePath


@export var minSentinalsPerRoom: int = 2
@export var maxSentinalsPerRoom: int = 4

var rooms: Array = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Defer so Dungeon._ready() (and generate_dungeon) runs first
	call_deferred("_load_rooms")


func _load_rooms() -> void:
	var dungeon = get_node_or_null(dungeon_path)
	if dungeon:
		rooms = dungeon.rooms
		for r in rooms:
			var sentinalsInThisRoom = randi_range(minSentinalsPerRoom, maxSentinalsPerRoom)
			print("ThisMansentinal", sentinalsInThisRoom)
			for s in range(sentinalsInThisRoom):
				var sent = sentinal.instantiate()
				var sand_layer = dungeon.get_node("SandTileMapLayer") as TileMapLayer
				sent.global_position = sand_layer.to_global(sand_layer.map_to_local(r.center()))
				add_child(sent)
			print("Loading Room: ", r.center())
	else:
		push_warning("EnemyManager: dungeon_path is not set or node not found.")
