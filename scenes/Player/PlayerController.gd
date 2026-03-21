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
const BloodScene = preload("res://scenes/Blood/Blood.tscn")
const DAMAGE_VIGNETTE_SHADER_CODE := """
shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(0.30, 0.06, 0.06, 1.0);
uniform float edge_thickness = 0.36;
uniform float edge_softness = 0.20;
uniform float roundness = 3.5;
uniform float intensity = 0.0;

void fragment() {
	vec2 uv = UV * 2.0 - vec2(1.0);
	float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.000001);
	uv.x *= aspect;

	float p = max(roundness, 1.0);
	vec2 a = abs(uv);
	float dist = pow(pow(a.x, p) + pow(a.y, p), 1.0 / p);

	float start = max(1.0 - edge_thickness, 0.0);
	float soft = max(edge_softness, 0.0001);
	float mask = smoothstep(start, start + soft, dist);
	float alpha = clamp(mask * intensity, 0.0, 1.0);

	COLOR = vec4(tint_color.rgb, tint_color.a * alpha);
}
"""
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var lantern: PointLight2D = $Lantern
@onready var moving_hands: Node2D = $MovingHands
@onready var left_hand: Sprite2D = $MovingHands/LeftHand
@onready var right_hand: Sprite2D = $MovingHands/RightHand
@onready var items: Node2D = $MovingHands/Items
@onready var lamp_item: AnimatedSprite2D = $MovingHands/Items/Lamp
@onready var gun_item: AnimatedSprite2D = $MovingHands/Items/Gun
@onready var shovel_item: AnimatedSprite2D = $MovingHands/Items/Shovel
@onready var shovel_handle: Node2D = $MovingHands/Items/Shovel/Handle
@onready var shovel_head: Node2D = $MovingHands/Items/Shovel/Head

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
	SHOVEL,
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
@export var gun_screen_shake_amount: float = 3.0
@export var gun_screen_shake_duration: float = 0.08
@export var shovel_forward_offset: float = 3.0
@export var shovel_handle_world_offset: Vector2 = Vector2.ZERO
@export var shovel_hand_down_offset: float = 2.0
@export var shovel_aim_up_offset_degrees: float = 45.0
@export var shovel_attack_cooldown: float = 0.30
@export var shovel_damage: int = 1
@export var shovel_knockback_force: float = 160.0
@export var shovel_sweep_degrees: float = 50.0
@export var shovel_sweep_duration: float = 0.20
@export var shovel_visual_sweep_multiplier: float = 4.5
@export var shovel_hitbox_distance: float = 13.0
@export var shovel_overlay_z_index: int = 120
@export var damage_vignette_color: Color = Color(0.30, 0.08, 0.08, 1.0)
@export var damage_vignette_edge_thickness: float = 0.42
@export var damage_vignette_edge_softness: float = 0.22
@export var damage_vignette_roundness: float = 3.6
@export var damage_vignette_flash_peak_alpha: float = 0.32
@export var damage_vignette_flash_in_time: float = 0.05
@export var damage_vignette_flash_out_time: float = 0.22

var damage_vignette_layer: CanvasLayer
var damage_vignette_rect: ColorRect
var damage_vignette_material: ShaderMaterial
var damage_vignette_tween: Tween
var damage_vignette_flash_alpha: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _current_attack_direction: Vector2 = Vector2.RIGHT
var _shovel_hit_targets: Array[Node2D] = []
var _shovel_visual_sweep_offset: float = 0.0
var _shovel_attack_tween: Tween


func _ready() -> void:
	add_to_group("player")
	rng.randomize()
	_setup_damage_vignette()
	if camera != null:
		# Camera2D ignores parent/node rotation by default.
		camera.ignore_rotation = false
	update_lantern_from_health()
	update_lantern_from_madness()
	update_lantern_enabled_state()
	update_lantern_held_state()
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
	update_lantern_enabled_state()
	update_lantern_held_state()
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
	
	# Attack action mirrors left-click primary action for currently held item.
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0 and not is_attacking:
		_use_primary_item_action()


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
	update_lantern_from_madness()


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
		_play_damage_vignette_flash()
		_spawn_blood_on_damage()
	_update_damage_vignette_intensity()
	update_lantern_from_health()
	health_changed.emit(current_health)


func _spawn_blood_on_damage() -> void:
	var blood := BloodScene.instantiate()
	var blood_position: Vector2 = global_position + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(2.0, 7.0))
	_place_ground_decal(blood, blood_position)


func _place_ground_decal(decal: Node2D, world_position: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var parent: Node = scene.get_node_or_null("Dungeon")
	if parent == null:
		parent = get_parent() if get_parent() != null else scene

	parent.add_child(decal)
	decal.global_position = world_position
	decal.z_index = 0

	if parent.name == "Dungeon":
		var sand_layer := parent.get_node_or_null("SandTileMapLayer")
		var chest_node := parent.get_node_or_null("Chest")
		var target_index: int = parent.get_child_count() - 1
		if sand_layer != null:
			target_index = sand_layer.get_index() + 1
		if chest_node != null:
			target_index = chest_node.get_index()
		parent.move_child(decal, target_index)


func _setup_damage_vignette() -> void:
	damage_vignette_layer = CanvasLayer.new()
	damage_vignette_layer.layer = 90
	add_child(damage_vignette_layer)

	damage_vignette_rect = ColorRect.new()
	damage_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_vignette_rect.color = Color.WHITE

	var shader := Shader.new()
	shader.code = DAMAGE_VIGNETTE_SHADER_CODE
	damage_vignette_material = ShaderMaterial.new()
	damage_vignette_material.shader = shader
	damage_vignette_material.set_shader_parameter("tint_color", damage_vignette_color)
	damage_vignette_material.set_shader_parameter("edge_thickness", damage_vignette_edge_thickness)
	damage_vignette_material.set_shader_parameter("edge_softness", damage_vignette_edge_softness)
	damage_vignette_material.set_shader_parameter("roundness", damage_vignette_roundness)
	damage_vignette_material.set_shader_parameter("intensity", 0.0)
	damage_vignette_rect.material = damage_vignette_material

	damage_vignette_layer.add_child(damage_vignette_rect)
	_update_damage_vignette_intensity()


func _play_damage_vignette_flash() -> void:
	if damage_vignette_rect == null:
		return

	if damage_vignette_tween != null and damage_vignette_tween.is_valid():
		damage_vignette_tween.kill()

	var peak_alpha: float = clampf(damage_vignette_flash_peak_alpha, 0.0, 1.0)
	_set_damage_vignette_flash_alpha(0.0)
	damage_vignette_tween = create_tween()
	damage_vignette_tween.tween_method(_set_damage_vignette_flash_alpha, 0.0, peak_alpha, maxf(damage_vignette_flash_in_time, 0.001))
	damage_vignette_tween.tween_method(_set_damage_vignette_flash_alpha, peak_alpha, 0.0, maxf(damage_vignette_flash_out_time, 0.001))


func _set_damage_vignette_flash_alpha(value: float) -> void:
	damage_vignette_flash_alpha = clampf(value, 0.0, 1.0)
	_update_damage_vignette_intensity()


func _update_damage_vignette_intensity() -> void:
	if damage_vignette_material == null:
		return

	damage_vignette_material.set_shader_parameter("intensity", damage_vignette_flash_alpha)


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


func update_lantern_from_madness() -> void:
	if lantern == null:
		return

	if lantern.has_method("set_madness_ratio"):
		lantern.set_madness_ratio(get_madness_ratio())


func update_lantern_enabled_state() -> void:
	if lantern == null:
		return

	if lantern.has_method("set_lamp_enabled"):
		lantern.set_lamp_enabled(lamp_is_on)


func update_lantern_held_state() -> void:
	if lantern == null:
		return

	if lantern.has_method("set_lamp_held"):
		lantern.set_lamp_held(current_held_item == HeldItem.LAMP)


func perform_whip_attack() -> void:
	# Legacy call path retained; now mapped to shovel sweep behavior.
	perform_shovel_sweep_attack()


func perform_shovel_sweep_attack() -> void:
	if whip_hitbox == null:
		return

	is_attacking = true
	attack_cooldown = shovel_attack_cooldown
	_shovel_hit_targets.clear()

	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	var attack_direction: Vector2 = Vector2.LEFT if facing_left else Vector2.RIGHT
	if to_mouse.length_squared() > 0.0:
		attack_direction = to_mouse.normalized()
	_current_attack_direction = attack_direction

	var base_angle: float = attack_direction.angle()
	var side_sign: float = -1.0 if attack_direction.x < 0.0 else 1.0
	var start_offset: float = deg_to_rad(-45.0) * side_sign
	var end_offset: float = deg_to_rad(45.0) * side_sign
	var start_angle: float = base_angle + start_offset
	var end_angle: float = base_angle + end_offset

	whip_hitbox.position = attack_direction * shovel_hitbox_distance
	whip_hitbox.rotation = start_angle
	whip_hitbox.monitoring = true

	if _shovel_attack_tween != null and _shovel_attack_tween.is_valid():
		_shovel_attack_tween.kill()
	_shovel_attack_tween = create_tween()
	_shovel_attack_tween.tween_method(
		Callable(self, "_set_shovel_visual_sweep_offset"),
		start_offset,
		end_offset,
		shovel_sweep_duration
	)
	_shovel_attack_tween.tween_method(
		Callable(self, "_set_shovel_visual_sweep_offset"),
		end_offset,
		0.0,
		shovel_sweep_duration * 0.6
	)

	var sweep_tween: Tween = create_tween()
	sweep_tween.tween_property(whip_hitbox, "rotation", end_angle, shovel_sweep_duration)
	await sweep_tween.finished

	whip_hitbox.monitoring = false
	is_attacking = false
	_set_shovel_visual_sweep_offset(0.0)


func _set_shovel_visual_sweep_offset(value: float) -> void:
	_shovel_visual_sweep_offset = value


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
	shot.speed = 440.0
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
	if not is_attacking:
		return

	if body.is_in_group("enemies") and body.has_method("take_damage"):
		if _shovel_hit_targets.has(body):
			return
		_shovel_hit_targets.append(body)

		var knockback_direction: Vector2 = body.global_position - global_position
		if knockback_direction.length_squared() <= 0.0:
			knockback_direction = _current_attack_direction

		body.take_damage(shovel_damage, knockback_direction.normalized(), shovel_knockback_force)


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
	if current_held_item == HeldItem.SHOVEL:
		var shovel_hand_offset: Vector2 = Vector2(0.0, shovel_hand_down_offset)
		left_hand.position += shovel_hand_offset
		right_hand.position += shovel_hand_offset


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
	if shovel_item != null:
		shovel_item.position = Vector2.ZERO
		shovel_item.rotation = 0.0
		shovel_item.z_as_relative = false
		shovel_item.z_index = shovel_overlay_z_index
	current_held_item = HeldItem.GUN
	lamp_is_on = true
	update_lantern_held_state()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if attack_cooldown <= 0.0 and not is_attacking:
				_use_primary_item_action()
				return
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_cycle_held_item()
			return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			if current_held_item == HeldItem.GUN and attack_cooldown <= 0.0 and not is_attacking:
				fire_gun()
				return
		if event.keycode == KEY_1:
			current_held_item = HeldItem.GUN
			update_lantern_enabled_state()
			update_lantern_held_state()
		elif event.keycode == KEY_2:
			if current_held_item == HeldItem.LAMP:
				_toggle_lamp_power()
				return
			current_held_item = HeldItem.LAMP
			update_lantern_enabled_state()
			update_lantern_held_state()
		elif event.keycode == KEY_3:
			current_held_item = HeldItem.SHOVEL
			update_lantern_enabled_state()
			update_lantern_held_state()


func _use_primary_item_action() -> void:
	match current_held_item:
		HeldItem.GUN:
			fire_gun()
		HeldItem.LAMP:
			_toggle_lamp_power()
		HeldItem.SHOVEL:
			perform_shovel_sweep_attack()


func _toggle_lamp_power() -> void:
	lamp_is_on = not lamp_is_on
	update_lantern_enabled_state()


func _cycle_held_item() -> void:
	match current_held_item:
		HeldItem.GUN:
			current_held_item = HeldItem.LAMP
		HeldItem.LAMP:
			current_held_item = HeldItem.SHOVEL
		HeldItem.SHOVEL:
			current_held_item = HeldItem.GUN

	update_lantern_enabled_state()
	update_lantern_held_state()


func get_madness_ratio() -> float:
	return clamp(float(current_madness) / float(MAX_MADNESS), 0.0, 1.0)


func _update_held_item_visuals() -> void:
	if items != null:
		items.position = Vector2.ZERO

	if gun_item == null or lamp_item == null or shovel_item == null:
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
	if shovel_item != null and shovel_handle != null and shovel_head != null and moving_hands != null:
		var desired_handle_global: Vector2 = moving_hands.global_position + (aim_direction * shovel_forward_offset) + shovel_handle_world_offset
		var desired_head_direction: Vector2 = get_global_mouse_position() - desired_handle_global
		if desired_head_direction.length_squared() <= 0.0:
			desired_head_direction = aim_direction
		var shovel_up_offset_radians: float = deg_to_rad(shovel_aim_up_offset_degrees)
		var side_sign: float = -1.0 if desired_head_direction.x >= 0.0 else 1.0
		desired_head_direction = desired_head_direction.rotated(shovel_up_offset_radians * side_sign)

		var local_handle_to_head: Vector2 = shovel_head.position - shovel_handle.position
		if local_handle_to_head.length_squared() <= 0.0:
			local_handle_to_head = Vector2.UP

		var target_rotation: float = desired_head_direction.angle() - local_handle_to_head.angle() + _shovel_visual_sweep_offset
		shovel_item.global_rotation = target_rotation
		var current_handle_global: Vector2 = shovel_item.to_global(shovel_handle.position)
		shovel_item.global_position += desired_handle_global - current_handle_global
	lamp_item.position = lamp_offset

	if current_held_item == HeldItem.GUN:
		gun_item.visible = true
		lamp_item.visible = false
		shovel_item.visible = false
	elif current_held_item == HeldItem.LAMP:
		gun_item.visible = false
		lamp_item.visible = true
		shovel_item.visible = false
		var horror_blackout_active: bool = false
		if lantern != null and lantern.has_method("is_horror_blackout_active"):
			horror_blackout_active = lantern.is_horror_blackout_active()

		if lamp_is_on and not horror_blackout_active:
			lamp_item.play("On")
		else:
			lamp_item.play("Off")
	elif current_held_item == HeldItem.SHOVEL:
		gun_item.visible = false
		lamp_item.visible = false
		shovel_item.visible = true
		shovel_item.z_as_relative = false
		shovel_item.z_index = shovel_overlay_z_index
		if shovel_item.animation != "Shovel":
			shovel_item.play("Shovel")
