extends CharacterBody2D


const SPEED = 70.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

enum PlayerStates {
	WALK_LEFT,
	WALK_RIGHT,
	IDLE_LEFT,
	IDLE_RIGHT,
}

var current_state: PlayerStates = PlayerStates.IDLE_RIGHT
var facing_left := false


func _ready() -> void:
	add_to_group("player")
	update_animation(Vector2.ZERO)


func _physics_process(_delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * SPEED

	update_animation(input_direction)
	move_and_slide()


func update_animation(input_direction: Vector2) -> void:
	if input_direction.x < 0.0:
		facing_left = true
	elif input_direction.x > 0.0:
		facing_left = false

	var is_moving := input_direction.length_squared() > 0.0
	if is_moving:
		current_state = PlayerStates.WALK_LEFT if facing_left else PlayerStates.WALK_RIGHT
	else:
		current_state = PlayerStates.IDLE_LEFT if facing_left else PlayerStates.IDLE_RIGHT

	var animation_name := ""
	match current_state:
		PlayerStates.WALK_LEFT:
			animation_name = "WalkLeft"
		PlayerStates.WALK_RIGHT:
			animation_name = "WalkRight"
		PlayerStates.IDLE_LEFT:
			animation_name = "IdleLeft"
		PlayerStates.IDLE_RIGHT:
			animation_name = "IdleRight"

	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)
