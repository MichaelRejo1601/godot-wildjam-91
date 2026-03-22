extends Area2D

const DEFAULT_SPEED: float = 20.0

@export var speed: float = 20.0
@export var lifetime: float = 6000.0
@export var knockback: float = 200.0
@export var damage: int = 1

# Set before add_child
var direction: Vector2 = Vector2.ZERO
var target: Node2D = null
@export var source: Node   # The sentinel that fired this — excluded from collision
var shot_index: int = 1
var tracked_target_position: Vector2 = Vector2.ZERO
var predicted_shot: bool = false

func _ready() -> void:
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == source:
		return
	if _is_valid_damage_target(body):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		elif body.get_parent() != null and body.get_parent().has_method("take_damage"):
			body.get_parent().take_damage(damage)
		# body.velocity += direction * knockback
		queue_free()


func _is_valid_damage_target(body: Node) -> bool:
	if body == null:
		return false
	if body == target:
		return true
	if target != null and body.get_parent() == target:
		return true
	if body.is_in_group("player"):
		return true
	if body.get_parent() != null and body.get_parent().is_in_group("player"):
		return true
	return false
