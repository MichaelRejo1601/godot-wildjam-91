class_name MadnessBar
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
const MAX_MADNESS = 14

var textures = [
	preload("res://assets/bars_and_menus/madness_bars/madness_bar_00.png"),
	preload("res://assets/bars_and_menus/madness_bars/madness_bar_01.png"),
	preload("res://assets/bars_and_menus/madness_bars/madness_bar_02.png"),
	preload("res://assets/bars_and_menus/madness_bars/madness_bar_03.png"),
	preload("res://assets/bars_and_menus/madness_bars/madness_bar_04.png"),
	preload("res://assets/bars_and_menus/madness_bars/madness_bar_05.png"),
	preload("res://assets/bars_and_menus/madness_bars/madness_bar_06.png"),
	preload("res://assets/bars_and_menus/madness_bars/madness_bar_07.png"),
	preload("res://assets/bars_and_menus/madness_bars/madness_bar_08.png"),
	preload("res://assets/bars_and_menus/madness_bars/madness_bar_09.png"),
	preload("res://assets/bars_and_menus/madness_bars/madness_bar_10.png"),
	preload("res://assets/bars_and_menus/madness_bars/madness_bar_11.png"),
	preload("res://assets/bars_and_menus/madness_bars/madness_bar_12.png"),
	preload("res://assets/bars_and_menus/madness_bars/madness_bar_13.png"),
	preload("res://assets/bars_and_menus/madness_bars/madness_bar_14.png"),
]


func _ready() -> void:
	update_madness(0)


func update_madness(madness):
	madness = clamp(madness, 0, MAX_MADNESS)
	var texture_index = clamp(MAX_MADNESS - madness, 0, textures.size() - 1)
	sprite.texture = textures[texture_index]
