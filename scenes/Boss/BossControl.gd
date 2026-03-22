extends CharacterBody2D


const SPEED = 30.0
const DASH_SPEED = 400.0
const DASH_DURATION = 0.3
const JUMP_VELOCITY = -400.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
const LaserBeamScene = preload("res://scenes/Sentinel/LaserBeam.tscn")
@export var dungeon: Node2D

var obstacles: TileMapLayer
var floorMap: TileMapLayer

@export var playerParent: Node2D
var player: CharacterBody2D

var locationToGo: Vector2i = Vector2i.MAX
var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0
var buildup_timer: float = 0.0
var range_attack_fired: bool = false
@export var dashBuild: float = 2.0
@export var laser_count: int = 3
@export var laser_spread_degrees: float = 20.0

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

func _ready() -> void:
	animated_sprite.play("default")
	currState = BossState.ROAMAROUND
	if playerParent.get_children() == null:
		print("Player is null")
	else:
		player = playerParent.get_children()[0]
	for child in dungeon.get_children():
		print("Child", child)
		if child is TileMapLayer:
			if child.name.contains("Wall"):
				obstacles = child
			elif child.name.contains("Sand"):
				floorMap = child
	if not obstacles:
		push_error("Obstacle not defined", obstacles)
	if not floorMap:
		push_error("Floor not defined")


func _physics_process(delta: float) -> void:
	# _update_debug_dirs()
	checkChange(delta)
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
