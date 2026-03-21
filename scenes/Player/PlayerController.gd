extends CharacterBody2D

signal health_changed(hp: int)
signal madness_changed(madness: int)
signal coins_changed(coins: int)

const SPEED = 70.0
const SPRINT_MULTIPLIER = 1.75
const SPRINT_ANIM_SPEED_SCALE = 1.35
const MAX_HP = 14
const MAX_MADNESS = 14
const MADNESS_FILL_DURATION = 60.0
const PlayerShotScene = preload("res://scenes/Player/player_bullet.tscn")
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var lantern: PointLight2D = $Lantern
@onready var moving_hands: Node2D = $MovingHands
@onready var left_hand: Sprite2D = $MovingHands/LeftHand
@onready var right_hand: Sprite2D = $MovingHands/RightHand
@onready var items: Node2D = $MovingHands/Items
@onready var lamp_item: AnimatedSprite2D = $MovingHands/Items/Lamp
@onready var gun_item: AnimatedSprite2D = $MovingHands/Items/Gun

@export var hand_orbit_radius: float = 4.0
@export var hand_spacing: float = 4.0
@export var gun_forward_offset: float = 3.0
@export var lamp_offset: Vector2 = Vector2(0, 2)
@export var back_hand_z_index: int = 1
@export var item_z_index: int = 2
@export var front_hand_z_index: int = 3

const HIT_SHAKE_ANGLE_DEG = 5.0
const HIT_SHAKE_STEP_TIME = 0.025

enum HeldItem {
	GUN,
	LAMP,
}

enum PlayerStates {
	WALK_LEFT,
	WALK_RIGHT,
	IDLE_LEFT,
	IDLE_RIGHT,
}

var current_state: PlayerStates = PlayerStates.IDLE_RIGHT
var facing_left := false
var current_health := MAX_HP
var current_madness := 0
var current_coins := 0
var madness_elapsed := 0.0
var hit_shake_tween: Tween
var gun_shake_tween: Tween
var controls_locked := false
var current_held_item: HeldItem = HeldItem.GUN
var lamp_is_on: bool = true

# Whip attack system
var is_attacking := false
var attack_cooldown := 0.0
const ATTACK_COOLDOWN_TIME = 1.0
@onready var whip_hitbox: Area2D = $WhipHitbox
@export var gun_fire_cooldown: float = 0.18
@export var gun_damage: int = 1
@export var gun_screen_shake_amount: float = 4.0
@export var gun_screen_shake_duration: float = 0.08


func _ready() -> void:
	add_to_group("player")
	if camera != null:
		# Camera2D ignores parent/node rotation by default.
		camera.ignore_rotation = false
	update_lantern_from_health()
	health_changed.emit(current_health)
	madness_changed.emit(current_madness)
	coins_changed.emit(current_coins)
	update_animation(Vector2.ZERO, false)
	
	# Connect whip hitbox signal
	if whip_hitbox != null:
		whip_hitbox.body_entered.connect(_on_whip_hitbox_body_entered)
	_initialize_held_items()


func _physics_process(_delta: float) -> void:
	_update_madness(_delta)
	_update_hand_positions()
	_update_held_item_visuals()

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
	
	# Handle attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= _delta
	
	# Handle attack input for equipped item
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0 and not is_attacking:
		if current_held_item == HeldItem.GUN:
			fire_gun()
		else:
			perform_whip_attack()


func _update_madness(delta: float) -> void:
	if current_madness >= MAX_MADNESS:
		return

	madness_elapsed = min(madness_elapsed + delta, MADNESS_FILL_DURATION)
	var ratio := madness_elapsed / MADNESS_FILL_DURATION
	var next_madness := int(round(ratio * MAX_MADNESS))
	if next_madness == current_madness:
		return

	current_madness = next_madness
	madness_changed.emit(current_madness)


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


func add_coins(amount: int = 1) -> void:
	if amount <= 0:
		return

	current_coins += amount
	coins_changed.emit(current_coins)


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


func perform_whip_attack() -> void:
	is_attacking = true
	attack_cooldown = ATTACK_COOLDOWN_TIME
	if whip_hitbox != null:
		whip_hitbox.monitoring = true
		whip_hitbox.position.x = 15.0 if not facing_left else -15.0
	await get_tree().create_timer(0.3).timeout
	if whip_hitbox != null:
		whip_hitbox.monitoring = false
	is_attacking = false


func fire_gun() -> void:
	attack_cooldown = gun_fire_cooldown
	_play_gun_screen_shake()

	if gun_item == null:
		return

	var to_mouse: Vector2 = get_global_mouse_position() - gun_item.global_position
	if to_mouse.length_squared() <= 0.0:
		return

	var bullet_direction: Vector2 = to_mouse.normalized()
	var shot := PlayerShotScene.instantiate()
	shot.direction = bullet_direction
	shot.source = self
	shot.damage = gun_damage
	shot.speed = 240.0
	shot.lifetime = 1.2
	shot.z_index = 5
	get_parent().add_child(shot)
	shot.global_position = gun_item.global_position + (bullet_direction * 4.0)


func _play_gun_screen_shake() -> void:
	if camera == null:
		return

	if gun_shake_tween != null and gun_shake_tween.is_valid():
		gun_shake_tween.kill()

	camera.offset = Vector2.ZERO
	gun_shake_tween = create_tween()
	var shake_vec: Vector2 = Vector2(gun_screen_shake_amount, gun_screen_shake_amount)
	gun_shake_tween.tween_property(camera, "offset", shake_vec, gun_screen_shake_duration * 0.25)
	gun_shake_tween.tween_property(camera, "offset", -shake_vec, gun_screen_shake_duration * 0.25)
	gun_shake_tween.tween_property(camera, "offset", Vector2.ZERO, gun_screen_shake_duration * 0.5)


func _on_whip_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(1)


func _update_hand_positions() -> void:
	if moving_hands == null or left_hand == null or right_hand == null:
		return

	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	var aim_direction: Vector2 = Vector2.RIGHT
	if to_mouse.length_squared() > 0.0:
		aim_direction = to_mouse.normalized()

	var perpendicular: Vector2 = Vector2(-aim_direction.y, aim_direction.x)
	moving_hands.position = aim_direction * hand_orbit_radius

	# Swap which hand is in front when aiming left.
	if aim_direction.x < 0.0:
		left_hand.z_index = front_hand_z_index
		right_hand.z_index = back_hand_z_index
	else:
		left_hand.z_index = back_hand_z_index
		right_hand.z_index = front_hand_z_index

	var half_spacing: float = hand_spacing * 0.5
	left_hand.position = -perpendicular * half_spacing
	right_hand.position = perpendicular * half_spacing


func _initialize_held_items() -> void:
	if left_hand != null:
		left_hand.z_index = back_hand_z_index
		left_hand.visible = true
	if items != null:
		items.z_index = item_z_index
	if right_hand != null:
		right_hand.z_index = front_hand_z_index
		right_hand.visible = true

	if items != null:
		# Force a clean centered origin for held-item placement.
		items.position = Vector2.ZERO
	if lamp_item != null:
		lamp_item.position = lamp_offset
	if gun_item != null:
		gun_item.position = Vector2.ZERO
		gun_item.rotation = 0.0
	current_held_item = HeldItem.GUN
	lamp_is_on = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			current_held_item = HeldItem.GUN
		elif event.keycode == KEY_2:
			if current_held_item == HeldItem.LAMP:
				lamp_is_on = not lamp_is_on
			current_held_item = HeldItem.LAMP


func _update_held_item_visuals() -> void:
	if items != null:
		items.position = Vector2.ZERO

	if gun_item == null or lamp_item == null:
		return

	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	var aim_direction: Vector2 = Vector2.RIGHT
	if to_mouse.length_squared() > 0.0:
		aim_direction = to_mouse.normalized()

	var mouse_left_of_player: bool = get_global_mouse_position().x < global_position.x
	gun_item.flip_h = mouse_left_of_player
	var aim_angle: float = aim_direction.angle()
	# When horizontally flipped, subtract PI so the muzzle still faces the mouse.
	gun_item.rotation = aim_angle - PI if mouse_left_of_player else aim_angle
	gun_item.position = aim_direction * gun_forward_offset
	lamp_item.position = lamp_offset

	if current_held_item == HeldItem.GUN:
		gun_item.visible = true
		lamp_item.visible = false
	elif current_held_item == HeldItem.LAMP:
		gun_item.visible = false
		lamp_item.visible = true
		if lamp_is_on:
			lamp_item.play("On")
		else:
			lamp_item.play("Off")
