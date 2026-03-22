class_name BulletBar
extends Node2D

const BULLET_TEXTURE: Texture2D = preload("res://assets/characters/Bullet.png")

@onready var icons: Node2D = $Icons
@export var max_bullets: int = 9
@export var icon_spacing: float = 10.0
@export var icon_scale: Vector2 = Vector2(1.15, 1.15)
@export var empty_alpha: float = 0.22

var _bullet_sprites: Array[Sprite2D] = []


func _ready() -> void:
	_rebuild_icons()
	update_bullets(max_bullets)


func set_max_bullets(value: int) -> void:
	max_bullets = max(value, 1)
	_rebuild_icons()
	update_bullets(max_bullets)


func update_bullets(value: int) -> void:
	var bullets: int = clamp(value, 0, max_bullets)
	for i in range(_bullet_sprites.size()):
		var bullet_sprite := _bullet_sprites[i]
		if i < bullets:
			bullet_sprite.modulate = Color(1, 1, 1, 1)
		else:
			bullet_sprite.modulate = Color(1, 1, 1, empty_alpha)


func _rebuild_icons() -> void:
	for child in icons.get_children():
		child.queue_free()
	_bullet_sprites.clear()

	var bullet_count: int = max(max_bullets, 1)
	for i in range(bullet_count):
		var sprite := Sprite2D.new()
		sprite.texture = BULLET_TEXTURE
		sprite.centered = false
		sprite.scale = icon_scale
		sprite.position = Vector2(float(i) * icon_spacing, 0.0)
		icons.add_child(sprite)
		_bullet_sprites.append(sprite)
