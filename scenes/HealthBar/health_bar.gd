class_name HealthBar
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@export var max_hp: int = 14
signal death

var textures = [
	preload("res://assets/bars_and_menus/health_bars/health_bar_00.png"),
	preload("res://assets/bars_and_menus/health_bars/health_bar_01.png"),
	preload("res://assets/bars_and_menus/health_bars/health_bar_02.png"),
	preload("res://assets/bars_and_menus/health_bars/health_bar_03.png"),
	preload("res://assets/bars_and_menus/health_bars/health_bar_04.png"),
	preload("res://assets/bars_and_menus/health_bars/health_bar_05.png"),
	preload("res://assets/bars_and_menus/health_bars/health_bar_06.png"),
	preload("res://assets/bars_and_menus/health_bars/health_bar_07.png"),
	preload("res://assets/bars_and_menus/health_bars/health_bar_08.png"),
	preload("res://assets/bars_and_menus/health_bars/health_bar_09.png"),
	preload("res://assets/bars_and_menus/health_bars/health_bar_10.png"),
	preload("res://assets/bars_and_menus/health_bars/health_bar_11.png"),
	preload("res://assets/bars_and_menus/health_bars/health_bar_12.png"),
	preload("res://assets/bars_and_menus/health_bars/health_bar_13.png"),
	preload("res://assets/bars_and_menus/health_bars/health_bar_14.png"),
]


func _ready() -> void:
	update_health(max_hp)


func update_health(hp):
	hp = clamp(hp, 0, max_hp)
	var hp_ratio := 0.0 if max_hp <= 0 else float(hp) / float(max_hp)
	# Map to nearest depletion frame based on percentage left.
	var depletion_ratio := 1.0 - hp_ratio
	var texture_index := int(round(depletion_ratio * float(textures.size() - 1)))
	texture_index = clamp(texture_index, 0, textures.size() - 1)
	sprite.texture = textures[texture_index]
	if hp == 0:
		death.emit()


func set_max_health(value: int) -> void:
	max_hp = max(value, 1)
