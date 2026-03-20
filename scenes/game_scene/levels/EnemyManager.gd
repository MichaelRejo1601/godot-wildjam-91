
extends Node2D

const sentinal = preload("res://scenes/Sentinel/Sentinel.tscn")
const mummy = preload("res://scenes/Mummy/Mummy.tscn")
const mummyDeath = preload("res://scenes/Mummy/MummyDeath.tscn")
@export var dungeon_path: NodePath


@export var minSentinalsPerRoom: int = 1
@export var maxSentinalsPerRoom: int = 1
@export var minMummysPerRoom: int = 1
@export var maxMummysPerRoom: int = 1

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
			var sentinalsInThisRoom = randi_range(minSentinalsPerRoom, maxSentinalsPerRoom)
			var mummyInThisRoom = randi_range(minMummysPerRoom, maxMummysPerRoom)
			# print("ThisMansentinal", sentinalsInThisRoom)
			for s in range(sentinalsInThisRoom):
				var sent = sentinal.instantiate()
				sent.global_position = sand_layer.to_global(sand_layer.map_to_local(r.center()))
				add_child(sent)
				if player_node:
					sent.player = player_node

			for m in range(mummyInThisRoom):
				var mum = mummy.instantiate()
				mum.global_position = sand_layer.to_global(sand_layer.map_to_local(r.center()))
				add_child(mum)
				if player_node:
					mum.player = player_node
				mum.about_to_be_deleted.connect(_on_mummy_about_to_be_deleted)
			# print("Loading Room: ", r.center())
	else:
		push_warning("EnemyManager: dungeon_path is not set or node not found.")


func _on_mummy_about_to_be_deleted(dead_enemy: CharacterBody2D) -> void:
	# pos = dead_enemy.position
	print("Mummy Death")
	if not seen.has(Vector2i(dead_enemy.global_position) % 16):
		seen[Vector2i(dead_enemy.global_position) % 16] = true
	
		var mumDeath = mummyDeath.instantiate()
		mumDeath.global_position = dead_enemy.global_position
		
		add_child(mumDeath)
	else:
		return
	pass # Replace with function body.
