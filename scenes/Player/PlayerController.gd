extends CharacterBody2D

signal health_changed(hp: int)

const SPEED = 70.0
const SPRINT_MULTIPLIER = 1.75
const SPRINT_ANIM_SPEED_SCALE = 1.35
const MAX_HP = 14
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var lantern: PointLight2D = $Lantern

const HIT_SHAKE_ANGLE_DEG = 5.0
const HIT_SHAKE_STEP_TIME = 0.025

enum PlayerStates {
	WALK_LEFT,
	WALK_RIGHT,
	IDLE_LEFT,
	IDLE_RIGHT,
}

var current_state: PlayerStates = PlayerStates.IDLE_RIGHT
var facing_left := false
var current_health := MAX_HP
var hit_shake_tween: Tween
var controls_locked := false


func _ready() -> void:
	add_to_group("player")
	if camera != null:
		# Camera2D ignores parent/node rotation by default.
		camera.ignore_rotation = false
	update_lantern_from_health()
	health_changed.emit(current_health)
	update_animation(Vector2.ZERO, false)


func _physics_process(_delta: float) -> void:
	if controls_locked:
		velocity = Vector2.ZERO
		update_animation(Vector2.ZERO, false)
		move_and_slide()
		return

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


func take_damage(amount: int = 1) -> void:
	if amount <= 0:
		return

	var previous_health := current_health
	current_health = max(current_health - amount, 0)
	if current_health < previous_health:
		play_hit_camera_shake()
	update_lantern_from_health()
	health_changed.emit(current_health)


func play_hit_camera_shake() -> void:
	if camera == null:
		return

	if hit_shake_tween != null and hit_shake_tween.is_valid():
		hit_shake_tween.kill()

	camera.rotation_degrees = 0.0
	hit_shake_tween = create_tween()
	hit_shake_tween.tween_property(camera, "rotation_degrees", HIT_SHAKE_ANGLE_DEG, HIT_SHAKE_STEP_TIME)
	hit_shake_tween.tween_property(camera, "rotation_degrees", -HIT_SHAKE_ANGLE_DEG, HIT_SHAKE_STEP_TIME)
	hit_shake_tween.tween_property(camera, "rotation_degrees", HIT_SHAKE_ANGLE_DEG * 0.6, HIT_SHAKE_STEP_TIME)
	hit_shake_tween.tween_property(camera, "rotation_degrees", 0.0, HIT_SHAKE_STEP_TIME)


func set_controls_locked(value: bool) -> void:
	controls_locked = value
	if controls_locked:
		velocity = Vector2.ZERO


func update_lantern_from_health() -> void:
	if lantern == null:
		return

	if lantern.has_method("set_health_ratio"):
		var ratio = float(current_health) / float(MAX_HP)
		lantern.set_health_ratio(ratio)
