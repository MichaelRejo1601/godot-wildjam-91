extends Area2D

@export var speed: float = 220.0
@export var lifetime: float = 1.5
@export var damage: int = 1
@export var knockback_force: float = 80.0

var direction: Vector2 = Vector2.RIGHT
var source: Node = null

func _ready() -> void:
	if direction.length_squared() > 0.0:
		rotation = direction.angle()
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == source:
		return
	if source != null and body == source.get_parent():
		return

	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage, direction, knockback_force)
		queue_free()
		return

	if body is TileMapLayer:
		if body.name.contains("Wall"):
			queue_free()
		return

	if body is StaticBody2D:
		queue_free()
