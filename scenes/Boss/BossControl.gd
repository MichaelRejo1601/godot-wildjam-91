extends CharacterBody2D


const SPEED = 30.0
const DASH_SPEED = 400.0
const DASH_DURATION = 0.3
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

@export var max_health: int = 14
var current_health: int = 14

var locationToGo: Vector2i = Vector2i.MAX
var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0
var buildup_timer: float = 0.0
var range_attack_fired: bool = false
@export var dashBuild: float = 2.0
@export var laser_count: int = 3
@export var laser_spread_degrees: float = 20.0
@export var touch_damage: int = 1
@export var touch_damage_cooldown: float = 0.5
@export var touch_damage_radius: float = 34.0

const DEBUG_ARROW_LENGTH := 150.0
var debug_dirs: Array[Vector2] = []
var debug_colors: Array[Color] = []

enum BossState{
	DASHBUILDUP,
	DASHATTACK,
	RANGEATTACK,
	ROAMAROUND
}

var currState: BossState
var _touch_damage_targets: Dictionary = {}
var _touch_player_cooldown_remaining: float = 0.0

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

	# _update_debug_dirs()
	checkChange(delta)
	_apply_touch_damage_overlaps(delta)
	_apply_touch_damage_proximity_fallback(delta)
	move_and_slide()
	queue_redraw()


func _update_debug_dirs() -> void:
	debug_dirs.clear()
	debug_colors.clear()
	match currState:
		BossState.DASHBUILDUP:
			if player:
				debug_dirs.append((player.global_position - global_position).normalized())
				debug_colors.append(Color.YELLOW)
		BossState.DASHATTACK:
			if dash_direction != Vector2.ZERO:
				debug_dirs.append(dash_direction)
				debug_colors.append(Color.RED)
		BossState.RANGEATTACK:
			if player:
				var base_angle := (player.global_position - global_position).angle()
				var step: float = deg_to_rad(laser_spread_degrees) / max(laser_count - 1, 1)
				var start_angle := base_angle - deg_to_rad(laser_spread_degrees) / 2.0
				for i in range(laser_count):
					var angle := start_angle + step * i if laser_count > 1 else base_angle
					debug_dirs.append(Vector2.from_angle(angle))
					debug_colors.append(Color.CYAN)
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
			velocity = Vector2.ZERO
			buildup_timer -= delta
			if buildup_timer <= 0.0:
				# Lock direction at the moment buildup ends
				dash_direction = global_position.direction_to(player.global_position)
				dash_timer = DASH_DURATION
				currState = BossState.DASHATTACK
				animated_sprite.play("default")
		BossState.DASHATTACK:
			velocity = dash_direction * DASH_SPEED
			dash_timer -= delta

			if dash_timer <= 0.0:
				velocity = Vector2.ZERO
				currState = BossState.ROAMAROUND
		BossState.RANGEATTACK:
			animated_sprite.pause()
			# print("rangeAttack")
			velocity = Vector2.ZERO
			if not range_attack_fired:
				range_attack_fired = true
				_fire_lasers_at_player()
				await get_tree().create_timer(0.5).timeout
				animated_sprite.play("default")
				range_attack_fired = false
				currState = BossState.ROAMAROUND
		BossState.ROAMAROUND:
			if not _refresh_dungeon_layers():
				velocity = Vector2.ZERO
				return
			if locationToGo == Vector2i.MAX:
				var sand_cells = floorMap.get_used_cells()
				var wall_cells = obstacles.get_used_cells()
				var valid_cells: Array[Vector2i] = []
				for cell in sand_cells:
					var too_close := false
					for wall in wall_cells:
						if abs(cell.x - wall.x) <= 3 and abs(cell.y - wall.y) <= 3:
							too_close = true
							break
					if not too_close:
						valid_cells.append(cell)
				if valid_cells.is_empty():
					locationToGo = sand_cells.pick_random()
				else:
					locationToGo = valid_cells.pick_random()

			var target_pos = floorMap.to_global(floorMap.map_to_local(locationToGo))
			var dir = (target_pos - global_position).normalized()
			velocity = dir * SPEED

			if global_position.distance_to(target_pos) < 8.0:
				locationToGo = Vector2i.MAX
				currState = chooseAttack()
func _fire_lasers_at_player() -> void:
	var base_dir := global_position.direction_to(player.global_position)
	var base_angle := base_dir.angle()
	var step :float = deg_to_rad(laser_spread_degrees) / max(laser_count - 1, 1)
	var start_angle := base_angle - deg_to_rad(laser_spread_degrees) / 2.0
	for i in range(laser_count):
		var angle := start_angle + step * i if laser_count > 1 else base_angle
		var laser := LaserBeamScene.instantiate()
		laser.direction = Vector2.from_angle(angle)
		laser.source = self
		laser.target = player
		get_parent().add_child(laser)
		laser.global_position = global_position

func chooseAttack() -> BossState:
	# print(global_position.distance_to(player.global_position))
	if global_position.distance_to(player.global_position) > 120:
		buildup_timer = dashBuild
		return BossState.DASHBUILDUP
	else:
		return BossState.RANGEATTACK


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
	if touch_damage <= 0 or contact_hitbox == null:
		return

	for key in _touch_damage_targets.keys():
		_touch_damage_targets[key] = maxf(float(_touch_damage_targets[key]) - delta, 0.0)

	for body in contact_hitbox.get_overlapping_bodies():
		_try_deal_touch_damage(body)


func _try_deal_touch_damage(body: Node) -> void:
	if touch_damage <= 0:
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

	target.take_damage(touch_damage)
	_touch_damage_targets[instance_id] = maxf(touch_damage_cooldown, 0.05)


func _apply_touch_damage_proximity_fallback(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if touch_damage <= 0:
		return

	_touch_player_cooldown_remaining = maxf(_touch_player_cooldown_remaining - delta, 0.0)
	if _touch_player_cooldown_remaining > 0.0:
		return

	if global_position.distance_to(player.global_position) <= touch_damage_radius:
		if player.has_method("take_damage"):
			player.take_damage(touch_damage)
			_touch_player_cooldown_remaining = maxf(touch_damage_cooldown, 0.05)


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
