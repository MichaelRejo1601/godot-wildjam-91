extends CharacterBody2D


const SPEED = 30.0
const DASH_SPEED = 700.0
const DASH_DURATION = 0.18
const JUMP_VELOCITY = -400.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var contact_hitbox: Area2D = $ContactHitbox
const LaserBeamScene = preload("res://scenes/Sentinel/LaserBeam.tscn")
@export var dungeon: Node2D

var obstacles: TileMapLayer
var floorMap: TileMapLayer

@export var playerParent: Node2D
var player: CharacterBody2D

signal health_changed(hp: int)
signal defeated

@export var max_health: int = 42
var current_health: int = 42

var locationToGo: Vector2i = Vector2i.MAX
var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0
var buildup_timer: float = 0.0
var range_attack_fired: bool = false
@export var dashBuild: float = 0.30
@export var laser_count: int = 3
@export var laser_spread_degrees: float = 20.0
@export var intensity_scalar: float = 1.0
@export var rapid_dash_count: int = 2
@export var rapid_dash_retarget_delay: float = 0.18
@export var dash_aim_hold_time: float = 1.0
@export var dash_backup_time: float = 0.28
@export var dash_backup_speed: float = 180.0
@export var dash_charge_duration: float = 0.24
@export var dash_charge_stop_distance: float = 14.0
@export var dash_head_turn_lerp_speed: float = 9.0
@export var dash_recovery_time: float = 2.0
@export var dash_reorient_lerp_speed: float = 10.0
@export var machine_gun_duration: float = 0.8
@export var machine_gun_fire_interval: float = 0.20
@export var machine_gun_bullets_per_burst: int = 1
@export var machine_gun_burst_spread_degrees: float = 16.0
@export var machine_gun_spin_speed_degrees: float = 28.0
@export var machine_gun_bullet_speed: float = 170.0
@export var machine_gun_bullet_lifetime: float = 4.5
@export var triple_spread_rounds: int = 3
@export var triple_spread_bullets_per_round: int = 3
@export var triple_spread_interval: float = 0.18
@export var triple_spread_spread_degrees: float = 18.0
@export var triple_spread_bullet_speed: float = 185.0
@export var triple_spread_bullet_lifetime: float = 3.8
@export var triple_spread_recovery: float = 0.45
@export var radial_burst_projectiles: int = 7
@export var radial_burst_bullet_speed: float = 155.0
@export var radial_burst_recovery: float = 0.7
@export var passive_fire_interval: float = 0.40
@export var passive_fire_count: int = 1
@export var passive_fire_spread_degrees: float = 20.0
@export var passive_fire_bullet_speed: float = 190.0
@export var passive_fire_bullet_lifetime: float = 3.2
@export var dash_hit_damage: int = 1
@export var dash_hit_radius: float = 34.0
@export var dash_hit_cooldown: float = 0.12
@export var body_hit_cooldown: float = 2
@export var touch_damage: int = 1
@export var touch_damage_cooldown: float = 2
@export var touch_damage_radius: float = 34.0

const DEBUG_ARROW_LENGTH := 150.0
var debug_dirs: Array[Vector2] = []
var debug_colors: Array[Color] = []

enum BossState{
	DASHBUILDUP,
	DASHATTACK,
	MACHINEGUN,
	TRIPLESPREAD,
	RANGEATTACK,
	ROAMAROUND
}

var currState: BossState
var _touch_damage_targets: Dictionary = {}
var _rapid_dash_remaining: int = 0
var _machine_gun_time_remaining: float = 0.0
var _machine_gun_fire_timer: float = 0.0
var _machine_gun_angle: float = 0.0
var _triple_spread_rounds_remaining: int = 0
var _triple_spread_fire_timer: float = 0.0
var _triple_spread_recovery_timer: float = 0.0
var _range_attack_recovery_timer: float = 0.0
var _passive_fire_timer: float = 0.0
var _body_hit_cooldown_remaining: float = 0.0
var _dash_locked_target_position: Vector2 = Vector2.ZERO
var _dash_charge_direction: Vector2 = Vector2.ZERO

enum DashTelegraphPhase {
	AIM,
	BACKUP
}

var _dash_telegraph_phase: DashTelegraphPhase = DashTelegraphPhase.AIM
var _dash_telegraph_timer: float = 0.0
var _dash_recovery_timer: float = 0.0
var _is_dash_recovering: bool = false


func _intensity_scalar_safe() -> float:
	return maxf(intensity_scalar, 0.01)


func _scaled_time(value: float, minimum: float = 0.001) -> float:
	return maxf(value * _intensity_scalar_safe(), minimum)


func _scaled_count(value: int, minimum: int = 1) -> int:
	return max(int(round(float(value) * _intensity_scalar_safe())), minimum)


func _scaled_damage(value: int) -> int:
	return max(int(round(float(value) * _intensity_scalar_safe())), 0)


func _scaled_distance(value: float) -> float:
	return maxf(value * _intensity_scalar_safe(), 0.0)

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	health_changed.emit(current_health)
	animated_sprite.play("default")
	currState = BossState.ROAMAROUND
	player = _find_player_body()
	if player == null:
		push_warning("Boss: Player is null.")
	if not _refresh_dungeon_layers():
		push_warning("Boss: Dungeon layers not available yet; will retry.")

	if contact_hitbox != null:
		# Use broad mask so contact damage reliably detects the player body.
		contact_hitbox.collision_layer = 1
		contact_hitbox.collision_mask = 0x7fffffff
		contact_hitbox.monitoring = true
		contact_hitbox.monitorable = true
		contact_hitbox.body_entered.connect(_on_contact_hitbox_body_entered)
		contact_hitbox.body_exited.connect(_on_contact_hitbox_body_exited)


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = _find_player_body()
		if player == null:
			velocity = Vector2.ZERO
			move_and_slide()
			return

	if not _refresh_dungeon_layers():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_body_hit_cooldown_remaining = maxf(_body_hit_cooldown_remaining - delta, 0.0)

	# _update_debug_dirs()
	checkChange(delta)
	_update_passive_fire(delta)
	_apply_touch_damage_overlaps(delta)
	_apply_touch_damage_proximity_fallback(delta)
	move_and_slide()
	queue_redraw()


func _update_debug_dirs() -> void:
	debug_dirs.clear()
	debug_colors.clear()
	match currState:
		BossState.DASHBUILDUP:
			if _dash_locked_target_position != Vector2.ZERO:
				debug_dirs.append((_dash_locked_target_position - global_position).normalized())
				debug_colors.append(Color.YELLOW)
			if _dash_telegraph_phase == DashTelegraphPhase.BACKUP and _dash_charge_direction != Vector2.ZERO:
				debug_dirs.append(-_dash_charge_direction)
				debug_colors.append(Color.PINK)
		BossState.DASHATTACK:
			if _dash_charge_direction != Vector2.ZERO:
				debug_dirs.append(_dash_charge_direction)
				debug_colors.append(Color.RED)
		BossState.RANGEATTACK:
			var debug_radial_count := _scaled_count(radial_burst_projectiles)
			for i in range(min(debug_radial_count, 24)):
				var angle := (TAU / float(max(debug_radial_count, 1))) * float(i)
				debug_dirs.append(Vector2.from_angle(angle))
				debug_colors.append(Color.CYAN)
		BossState.MACHINEGUN:
			var debug_machine_gun_count := _scaled_count(machine_gun_bullets_per_burst)
			for i in range(min(debug_machine_gun_count, 12)):
				var center_offset: float = (float(i) - (float(debug_machine_gun_count - 1) * 0.5))
				var angle := _machine_gun_angle + deg_to_rad(center_offset * (machine_gun_burst_spread_degrees * _intensity_scalar_safe()))
				debug_dirs.append(Vector2.from_angle(angle))
				debug_colors.append(Color.ORANGE)
		BossState.TRIPLESPREAD:
			var debug_triple_count: int = max(triple_spread_bullets_per_round, 1)
			var base_angle := global_position.direction_to(player.global_position).angle()
			for i in range(min(debug_triple_count, 12)):
				var center_offset: float = (float(i) - (float(debug_triple_count - 1) * 0.5))
				var angle := base_angle + deg_to_rad(center_offset * (triple_spread_spread_degrees * _intensity_scalar_safe()))
				debug_dirs.append(Vector2.from_angle(angle))
				debug_colors.append(Color.SKY_BLUE)
		BossState.ROAMAROUND:
			if locationToGo != Vector2i.MAX and floorMap:
				var target_pos := floorMap.to_global(floorMap.map_to_local(locationToGo))
				debug_dirs.append((target_pos - global_position).normalized())
				debug_colors.append(Color.GREEN)


func _draw() -> void:
	for i in range(debug_dirs.size()):
		_draw_debug_triangle(debug_dirs[i], debug_colors[i])


func _draw_debug_triangle(dir: Vector2, color: Color) -> void:
	if dir == Vector2.ZERO:
		return
	var tip := dir * DEBUG_ARROW_LENGTH
	var base_left := dir.rotated(deg_to_rad(135.0)) * DEBUG_ARROW_LENGTH * 0.35
	var base_right := dir.rotated(deg_to_rad(-135.0)) * DEBUG_ARROW_LENGTH * 0.35
	draw_colored_polygon(PackedVector2Array([tip, base_left, base_right]), color)
	draw_line(Vector2.ZERO, tip, color, 2.0)


func checkChange(delta: float):
	match currState:
		BossState.DASHBUILDUP:
			animated_sprite.pause()
			if _dash_telegraph_phase == DashTelegraphPhase.AIM:
				velocity = Vector2.ZERO
				_face_toward(_dash_locked_target_position, delta)
				_dash_telegraph_timer -= delta
				if _dash_telegraph_timer <= 0.0:
					_dash_telegraph_phase = DashTelegraphPhase.BACKUP
					_dash_telegraph_timer = _scaled_time(dash_backup_time, 0.01)
			elif _dash_telegraph_phase == DashTelegraphPhase.BACKUP:
				var backup_direction := (_dash_locked_target_position - global_position).normalized()
				if backup_direction == Vector2.ZERO:
					backup_direction = global_position.direction_to(player.global_position)
				if backup_direction == Vector2.ZERO:
					backup_direction = Vector2.RIGHT
				_dash_charge_direction = backup_direction
				velocity = -backup_direction * (dash_backup_speed * _intensity_scalar_safe())
				_face_toward(_dash_locked_target_position, delta)
				_dash_telegraph_timer -= delta
				if _dash_telegraph_timer <= 0.0:
					_dash_charge_direction = (_dash_locked_target_position - global_position).normalized()
					if _dash_charge_direction == Vector2.ZERO:
						_dash_charge_direction = backup_direction
					dash_timer = _scaled_time(dash_charge_duration, 0.01)
					currState = BossState.DASHATTACK
					animated_sprite.play("default")
		BossState.DASHATTACK:
			if _is_dash_recovering:
				velocity = Vector2.ZERO
				_correct_orientation(delta)
				_dash_recovery_timer -= delta
				if _dash_recovery_timer <= 0.0:
					_is_dash_recovering = false
					currState = chooseAttack()
			else:
				velocity = _dash_charge_direction * (DASH_SPEED * _intensity_scalar_safe())
				_face_toward_direction(_dash_charge_direction, delta)
				dash_timer -= delta
				_try_dash_overlap_damage(delta)

				if dash_timer <= 0.0 or global_position.distance_to(_dash_locked_target_position) <= _scaled_distance(dash_charge_stop_distance):
					velocity = Vector2.ZERO
					_rapid_dash_remaining -= 1
					if _rapid_dash_remaining > 0:
						currState = BossState.DASHBUILDUP
						_begin_dash_sequence()
						_dash_telegraph_timer = _scaled_time(rapid_dash_retarget_delay, 0.01)
					else:
						_is_dash_recovering = true
						_dash_recovery_timer = _scaled_time(dash_recovery_time, 0.1)
		BossState.MACHINEGUN:
			animated_sprite.pause()
			velocity = Vector2.ZERO
			_machine_gun_time_remaining -= delta
			_machine_gun_fire_timer -= delta
			if _machine_gun_fire_timer <= 0.0:
				_fire_machine_gun_burst()
				_machine_gun_angle += deg_to_rad(machine_gun_spin_speed_degrees * _intensity_scalar_safe())
				_machine_gun_fire_timer = _scaled_time(machine_gun_fire_interval, 0.01)
			if _machine_gun_time_remaining <= 0.0:
				animated_sprite.play("default")
				currState = chooseAttack()
		BossState.TRIPLESPREAD:
			animated_sprite.pause()
			velocity = Vector2.ZERO
			if _triple_spread_rounds_remaining > 0:
				_triple_spread_fire_timer -= delta
				if _triple_spread_fire_timer <= 0.0:
					_fire_triple_spread_round()
					_triple_spread_rounds_remaining -= 1
					_triple_spread_fire_timer = _scaled_time(triple_spread_interval, 0.03)
			else:
				_triple_spread_recovery_timer -= delta
				if _triple_spread_recovery_timer <= 0.0:
					animated_sprite.play("default")
					currState = chooseAttack()
		BossState.RANGEATTACK:
			animated_sprite.pause()
			velocity = Vector2.ZERO
			if not range_attack_fired:
				range_attack_fired = true
				_fire_radial_burst()
				_range_attack_recovery_timer = _scaled_time(radial_burst_recovery)
			_range_attack_recovery_timer -= delta
			if _range_attack_recovery_timer <= 0.0:
				animated_sprite.play("default")
				range_attack_fired = false
				currState = chooseAttack()
		BossState.ROAMAROUND:
			if not _refresh_dungeon_layers():
				velocity = Vector2.ZERO
				return
			velocity = Vector2.ZERO
			currState = chooseAttack()
func _fire_lasers_at_player() -> void:
	var base_dir := global_position.direction_to(player.global_position)
	var base_angle := base_dir.angle()
	var scaled_laser_count := _scaled_count(laser_count)
	var scaled_laser_spread := laser_spread_degrees * _intensity_scalar_safe()
	var step :float = deg_to_rad(scaled_laser_spread) / max(scaled_laser_count - 1, 1)
	var start_angle := base_angle - deg_to_rad(scaled_laser_spread) / 2.0
	for i in range(scaled_laser_count):
		var angle := start_angle + step * i if scaled_laser_count > 1 else base_angle
		_spawn_laser(angle)


func _fire_machine_gun_burst() -> void:
	var burst_count: int = _scaled_count(machine_gun_bullets_per_burst)
	var scaled_spread := machine_gun_burst_spread_degrees * _intensity_scalar_safe()
	for i in range(burst_count):
		var center_offset: float = float(i) - (float(burst_count - 1) * 0.5)
		var angle := _machine_gun_angle + deg_to_rad(center_offset * scaled_spread)
		_spawn_laser(
			angle,
			machine_gun_bullet_speed * _intensity_scalar_safe(),
			machine_gun_bullet_lifetime * _intensity_scalar_safe()
		)


func _fire_triple_spread_round() -> void:
	var spread_count: int = max(triple_spread_bullets_per_round, 1)
	_fire_aimed_spread(
		spread_count,
		triple_spread_spread_degrees * _intensity_scalar_safe(),
		triple_spread_bullet_speed * _intensity_scalar_safe(),
		triple_spread_bullet_lifetime * _intensity_scalar_safe()
	)


func _fire_radial_burst() -> void:
	var count: int = _scaled_count(radial_burst_projectiles)
	for i in range(count):
		var angle := (TAU / float(count)) * float(i)
		_spawn_laser(
			angle,
			radial_burst_bullet_speed * _intensity_scalar_safe(),
			machine_gun_bullet_lifetime * _intensity_scalar_safe()
		)


func _spawn_laser(angle: float, speed_override: float = -1.0, lifetime_override: float = -1.0) -> void:
	var laser := LaserBeamScene.instantiate()
	laser.direction = Vector2.from_angle(angle)
	laser.source = self
	laser.target = player
	if speed_override > 0.0:
		laser.speed = speed_override
	if lifetime_override > 0.0:
		laser.lifetime = lifetime_override
	get_parent().add_child(laser)
	laser.global_position = global_position


func _fire_aimed_spread(count: int, spread_degrees: float, speed_override: float, lifetime_override: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var burst_count: int = max(count, 1)
	var center_angle := global_position.direction_to(player.global_position).angle()
	for i in range(burst_count):
		var center_offset: float = float(i) - (float(burst_count - 1) * 0.5)
		var angle := center_angle + deg_to_rad(center_offset * spread_degrees)
		_spawn_laser(angle, speed_override, lifetime_override)

func chooseAttack() -> BossState:
	var roll := randf()
	if roll < 0.40:
		_rapid_dash_remaining = _scaled_count(rapid_dash_count)
		_begin_dash_sequence()
		return BossState.DASHBUILDUP
	if roll < 0.72:
		_machine_gun_time_remaining = _scaled_time(machine_gun_duration, 0.2)
		_machine_gun_fire_timer = 0.0
		_machine_gun_angle = global_position.direction_to(player.global_position).angle()
		return BossState.MACHINEGUN
	if roll < 0.90:
		_triple_spread_rounds_remaining = max(triple_spread_rounds, 1)
		_triple_spread_fire_timer = 0.0
		_triple_spread_recovery_timer = _scaled_time(triple_spread_recovery, 0.05)
		return BossState.TRIPLESPREAD
	range_attack_fired = false
	_range_attack_recovery_timer = 0.0
	return BossState.RANGEATTACK


func _begin_dash_sequence() -> void:
	if player != null and is_instance_valid(player):
		_dash_locked_target_position = player.global_position
	else:
		_dash_locked_target_position = global_position + Vector2.RIGHT * 64.0
	_dash_telegraph_phase = DashTelegraphPhase.AIM
	_dash_telegraph_timer = _scaled_time(dash_aim_hold_time, 0.05)
	_dash_charge_direction = (_dash_locked_target_position - global_position).normalized()
	if _dash_charge_direction == Vector2.ZERO:
		_dash_charge_direction = Vector2.RIGHT


func _face_toward(target_position: Vector2, delta: float) -> void:
	var to_target := target_position - global_position
	if to_target == Vector2.ZERO:
		return
	_face_toward_direction(to_target.normalized(), delta)


func _face_toward_direction(direction: Vector2, delta: float) -> void:
	if direction == Vector2.ZERO:
		return
	var target_rotation := direction.angle() + PI * 0.5
	rotation = lerp_angle(rotation, target_rotation, clampf(dash_head_turn_lerp_speed * delta, 0.0, 1.0))


func _correct_orientation(delta: float) -> void:
	rotation = lerp_angle(rotation, 0.0, clampf(dash_reorient_lerp_speed * delta, 0.0, 1.0))


func take_damage(amount: int = 1, _hit_direction: Vector2 = Vector2.ZERO, _hit_force: float = -1.0) -> void:
	if amount <= 0 or current_health <= 0:
		return

	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health)
	if current_health <= 0:
		defeated.emit()
		queue_free()


func _find_player_body() -> CharacterBody2D:
	if playerParent == null:
		return null

	if playerParent is CharacterBody2D:
		return playerParent as CharacterBody2D

	for child in playerParent.get_children():
		if child is CharacterBody2D:
			return child as CharacterBody2D

	return null


func _on_contact_hitbox_body_entered(body: Node) -> void:
	_try_deal_touch_damage(body)


func _on_contact_hitbox_body_exited(body: Node) -> void:
	if body == null:
		return
	_touch_damage_targets.erase(body.get_instance_id())


func _apply_touch_damage_overlaps(delta: float) -> void:
	if _scaled_damage(touch_damage) <= 0 or contact_hitbox == null:
		return

	for key in _touch_damage_targets.keys():
		_touch_damage_targets[key] = maxf(float(_touch_damage_targets[key]) - delta, 0.0)

	for body in contact_hitbox.get_overlapping_bodies():
		_try_deal_touch_damage(body)


func _try_deal_touch_damage(body: Node) -> void:
	if _scaled_damage(touch_damage) <= 0:
		return
	if body == null:
		return

	var target: Node = body
	if not target.has_method("take_damage") and target.get_parent() != null and target.get_parent().has_method("take_damage"):
		target = target.get_parent()
	if not target.has_method("take_damage"):
		return
	if not target.is_in_group("player") and target != player:
		return

	var instance_id := target.get_instance_id()
	var cooldown_remaining := float(_touch_damage_targets.get(instance_id, 0.0))
	if cooldown_remaining > 0.0:
		return

	if not _try_damage_player_with_body(
		target,
		_scaled_damage(touch_damage),
		maxf(_scaled_time(body_hit_cooldown), _scaled_time(touch_damage_cooldown))
	):
		return
	_touch_damage_targets[instance_id] = _scaled_time(touch_damage_cooldown, 0.05)


func _apply_touch_damage_proximity_fallback(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if _scaled_damage(touch_damage) <= 0:
		return

	if global_position.distance_to(player.global_position) <= _scaled_distance(touch_damage_radius):
		_try_damage_player_with_body(
			player,
			_scaled_damage(touch_damage),
			maxf(_scaled_time(body_hit_cooldown), _scaled_time(touch_damage_cooldown))
		)


func _update_passive_fire(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_passive_fire_timer -= delta
	if _passive_fire_timer > 0.0:
		return
	_fire_aimed_spread(
		_scaled_count(passive_fire_count),
		passive_fire_spread_degrees * _intensity_scalar_safe(),
		passive_fire_bullet_speed * _intensity_scalar_safe(),
		passive_fire_bullet_lifetime * _intensity_scalar_safe()
	)
	_passive_fire_timer = _scaled_time(passive_fire_interval, 0.02)


func _try_dash_overlap_damage(_delta: float) -> void:
	if _scaled_damage(dash_hit_damage) <= 0:
		return
	if player == null or not is_instance_valid(player):
		return

	if global_position.distance_to(player.global_position) <= _scaled_distance(dash_hit_radius):
		_try_damage_player_with_body(
			player,
			_scaled_damage(dash_hit_damage),
			maxf(_scaled_time(body_hit_cooldown), _scaled_time(dash_hit_cooldown))
		)


func _try_damage_player_with_body(target: Node, amount: int, cooldown: float) -> bool:
	if amount <= 0 or target == null:
		return false
	if _body_hit_cooldown_remaining > 0.0:
		return false
	if not target.has_method("take_damage"):
		return false

	target.take_damage(amount)
	_body_hit_cooldown_remaining = maxf(cooldown, 0.03)
	return true


func _refresh_dungeon_layers() -> bool:
	if dungeon == null or not is_instance_valid(dungeon):
		var parent_node := get_parent()
		if parent_node != null:
			dungeon = parent_node.get_node_or_null("Dungeon") as Node2D

	if dungeon == null or not is_instance_valid(dungeon):
		obstacles = null
		floorMap = null
		return false

	if floorMap == null or not is_instance_valid(floorMap):
		floorMap = dungeon.get_node_or_null("SandTileMapLayer") as TileMapLayer
		if floorMap == null:
			for child in dungeon.get_children():
				if child is TileMapLayer and child.name.contains("Sand"):
					floorMap = child as TileMapLayer
					break

	if obstacles == null or not is_instance_valid(obstacles):
		obstacles = dungeon.get_node_or_null("WallTileMapLayer") as TileMapLayer
		if obstacles == null:
			for child in dungeon.get_children():
				if child is TileMapLayer and child.name.contains("Wall"):
					obstacles = child as TileMapLayer
					break

	return floorMap != null and obstacles != null
