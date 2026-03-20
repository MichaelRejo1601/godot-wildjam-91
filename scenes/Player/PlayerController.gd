extends CharacterBody2D


const SPEED = 70.0
const SPRINT_MULTIPLIER = 1.75
const SPRINT_ANIM_SPEED_SCALE = 1.35
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
	update_animation(Vector2.ZERO, false)


func _physics_process(_delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var sprint_pressed := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT) or Input.is_action_pressed("ui_accept")
	var is_sprinting := sprint_pressed and input_direction.length_squared() > 0.0
	var current_speed := SPEED * SPRINT_MULTIPLIER if is_sprinting else SPEED
	velocity = input_direction * current_speed

	update_animation(input_direction, is_sprinting)
	move_and_slide()


func update_animation(input_direction: Vector2, is_sprinting: bool) -> void:
	if input_direction.x < 0.0:
		facing_left = true
	elif input_direction.x > 0.0:
		facing_left = false

	var is_moving := input_direction.length_squared() > 0.0
	if is_moving:
		current_state = PlayerStates.WALK_LEFT if facing_left else PlayerStates.WALK_RIGHT
	else:
		current_state = PlayerStates.IDLE_LEFT if facing_left else PlayerStates.IDLE_RIGHT

	animated_sprite.speed_scale = SPRINT_ANIM_SPEED_SCALE if is_moving and is_sprinting else 1.0

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
