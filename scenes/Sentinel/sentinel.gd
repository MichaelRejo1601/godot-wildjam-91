extends CharacterBody2D

@export var obstacles: TileMapLayer

@export var dungeon_root: NodePath
var dungeon_tilemaps: Array = []

@export var speed: float = 30.0
@export var change_interval: float = 2.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var attack_interval_min: float = 1.0
@export var attack_interval_max: float = 2.0

@export var attack_range: float = 24.0
@export var attack_knockback: float = 200.0
@export var active_range: float = 400.0
@export var player: Node2D
@export var burst_shot_count: int = 3
@export var burst_shot_delay: float = 0.20
@export var predictive_shot_lead_scale: float = 0.60

var _foundPlaye: bool = false

const LaserBeamScene = preload("res://scenes/Sentinel/LaserBeam.tscn")
const LASER_DEFAULT_SPEED = 20.0

var _dir: Vector2 = Vector2.RIGHT
var _time: float = 0.0
var _attackTime: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _attackInterval: float 
var _is_firing_burst: bool = false

enum SentinalStates {
	IDLE, 
	WALK,
	ATTACK
}

var currState: SentinalStates = SentinalStates.IDLE

# Health system for whip attacks
var health: int = 3

func _ready() -> void:
	add_to_group("enemies")
	rng.randomize()
	_attackInterval = rng.randf_range(attack_interval_min, attack_interval_max)
	# print("Curr Attack Interval: ", _attackInterval)
	_pick_direction()
	if dungeon_root:
		var root = get_node_or_null(dungeon_root)
		if root:
			dungeon_tilemaps.clear()
			for child in root.get_children():
				if child is TileMap:
					if child.name.contains("Wall"):
						obstacles = dungeon_tilemaps[0]
					dungeon_tilemaps.append(child)
	animated_sprite.play("Idle")

	# connect frame change so we can trigger hit on a specific frame
	if not animated_sprite.is_connected("frame_changed", Callable(self, "_on_AnimatedSprite2D_frame_changed")):
		print("connected")
		animated_sprite.connect("frame_changed", Callable(self, "_on_AnimatedSprite2D_frame_changed"))
	animated_sprite.connect("animation_finished", Callable(self, "_on_animation_finished"))

func _physics_process(delta: float) -> void:
	if player and is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist > active_range and not _foundPlaye:
			visible = false
			$CollisionShape2D.disabled = true
			return
		else:
			_foundPlaye = true
			visible = true
			$CollisionShape2D.disabled = false

	_attackTime += delta
	_time += delta
	if _time >= change_interval:
		_time = 0.0
		_pick_direction()
	if currState != SentinalStates.ATTACK:
		velocity = _dir * speed
	else:
		velocity = Vector2.ZERO
	if velocity.length() > 0:
		currState = SentinalStates.WALK
	else:
		currState = SentinalStates.IDLE

	if _attackTime >= _attackInterval and currState != SentinalStates.ATTACK:
		if _has_line_of_sight():
			currState = SentinalStates.ATTACK
	_checkAnimation()

	move_and_slide()
	if is_on_wall():
		_pick_direction()

func _pick_direction() -> void:
	var angle = rng.randf_range(0.0, TAU)
	_dir = Vector2(cos(angle), sin(angle)).normalized()


func _attack() -> void:
	currState = SentinalStates.ATTACK
	_attackTime = 0.0

func _checkAnimation():
	match currState:
		SentinalStates.IDLE:
			if animated_sprite.animation != "Idle":
				animated_sprite.play("Idle")
		SentinalStates.ATTACK:
			if animated_sprite.animation != "Attack":
				animated_sprite.play("Attack")
		SentinalStates.WALK:
			if animated_sprite.animation != "Run":
				animated_sprite.play("Run")


func _on_animation_finished() -> void:
	if currState == SentinalStates.ATTACK:
		currState = SentinalStates.IDLE
		_attackInterval = rng.randf_range(attack_interval_min, attack_interval_max)
		_attackTime = 0.0


func _on_AnimatedSprite2D_frame_changed() -> void:
	# Trigger attack when the 8th frame (index 7) of the "Attack" animation plays
	if currState == SentinalStates.ATTACK and animated_sprite.frame == 8:
		# print("Attacking")
		_attack_player()


func _has_line_of_sight() -> bool:
	if not player or not is_instance_valid(player):
		return false
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.exclude = [self]
	var result := space.intersect_ray(query)
	return result.is_empty() or result.get("collider") == player


func _attack_player() -> void:
	if _is_firing_burst:
		return
	if not _has_line_of_sight():
		return

	_is_firing_burst = true
	for shot_index in range(burst_shot_count):
		if not player or not is_instance_valid(player):
			break
		if not _has_line_of_sight():
			break
		_fire_laser_shot(shot_index)
		if shot_index < burst_shot_count - 1:
			await get_tree().create_timer(burst_shot_delay).timeout
	_is_firing_burst = false

	_attackTime = 0.0


func _fire_laser_shot(shot_index: int) -> void:
	var aim_target := player.global_position

	# The second beam tries to lead the target based on current velocity.
	if shot_index == 1 and player is CharacterBody2D:
		var player_body := player as CharacterBody2D
		var estimated_laser_speed := LASER_DEFAULT_SPEED
		if estimated_laser_speed <= 0.0:
			estimated_laser_speed = 20.0
		var distance_to_target := global_position.distance_to(player_body.global_position)
		var travel_time := distance_to_target / estimated_laser_speed
		var lead_time: float = clampf(travel_time * predictive_shot_lead_scale, 0.0, 0.75)
		aim_target += player_body.velocity * lead_time

	var dir := (aim_target - global_position).normalized()

	var laser: Node2D = LaserBeamScene.instantiate()
	laser.direction = dir
	laser.target = player
	laser.source = self
	laser.knockback = attack_knockback
	laser.shot_index = shot_index + 1
	laser.tracked_target_position = aim_target
	laser.predicted_shot = (shot_index == 1)
	get_parent().add_child(laser)
	laser.global_position = global_position


func _on_animated_sprite_2d_animation_finished() -> void:
	if currState == SentinalStates.ATTACK:
		currState = SentinalStates.IDLE
		_attackInterval = rng.randf_range(attack_interval_min, attack_interval_max)
		_attackTime = 0.0


func take_damage(amount: int = 1) -> void:
	health -= amount
	if health <= 0:
		queue_free()
