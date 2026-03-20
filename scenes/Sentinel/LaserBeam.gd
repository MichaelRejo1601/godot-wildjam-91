extends Area2D

@export var speed: float = 20.0
@export var lifetime: float = 6000.0
@export var knockback: float = 200.0
@export var damage: int = 1

# Set before add_child
var direction: Vector2 = Vector2.ZERO
var target: Node2D = null
@export var source: Node   # The sentinel that fired this — excluded from collision

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
	if body == target and body is CharacterBody2D:
		if body.has_method("take_damage"):
			body.take_damage(damage)
		body.velocity += direction * knockback
	queue_free()
