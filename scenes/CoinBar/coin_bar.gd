class_name CoinBarUI
extends Node2D

@onready var label: Label = $Label


func _ready() -> void:
	update_coins(0)


func update_coins(value: int) -> void:
	if label == null:
		return
	label.text = str(max(value, 0))
