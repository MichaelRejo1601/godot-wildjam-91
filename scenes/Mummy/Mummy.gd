extends CharacterBody2D

@export var obstacles: TileMapLayer

@export var dungeon_root: NodePath
var dungeon_tilemaps: Array = []

@export var speed: float = 30.0
@export var change_interval: float = 2.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var attack_interval_min: float = 5.0
@export var attack_interval_max: float = 6.0

@export var attack_range: float = 24.0
@export var attack_knockback: float = 200.0
@export var active_range: float = 200.0
@export var attackSpeed: float = 40
@export var player: Node2D
@export var knockback: float = 90

var _foundPlaye: bool = false


var _dir: Vector2 = Vector2.RIGHT
var _time: float = 0.0
var _attackTime: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _attackInterval: float 

enum SentinalStates {
	IDLE, 
	ATTACK,
	KNOCKBACK
}

var currState: SentinalStates = SentinalStates.IDLE

func _ready() -> void:
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
	if _has_line_of_sight() and currState != SentinalStates.KNOCKBACK:
		currState = SentinalStates.ATTACK
	elif currState != SentinalStates.KNOCKBACK: 
		currState = SentinalStates.IDLE
	# print(currState)
	_checkAnimation(delta)

	move_and_slide()
	if is_on_wall():
		_pick_direction()

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		# print("Collided with: ", collision.get_collider().name)
		if collision.get_collider().name == "Player" and _has_line_of_sight():
			# currState = SentinalStates.IDLE
			var to_player := player.global_position - global_position
			var dir := to_player.normalized()
			currState = SentinalStates.KNOCKBACK
			queue_free()
			# velocity = -dir * 40

func _pick_direction() -> void:
	if player and is_instance_valid(player):
		_dir = (player.global_position - global_position).normalized()


func _attack() -> void:
	currState = SentinalStates.ATTACK
	_attackTime = 0.0

func _checkAnimation(delta: float):
	match currState:
		SentinalStates.IDLE:
			velocity = Vector2.ZERO
			if animated_sprite.animation != "Idle":
				animated_sprite.play("Idle")
		SentinalStates.ATTACK:
			_attack_player()
			if animated_sprite.animation != "Roll":
				animated_sprite.play("Roll")
		SentinalStates.KNOCKBACK:
			if _has_line_of_sight():
				print("adding Knockback")
				var to_player := player.global_position - global_position
				var dir := to_player.normalized()
				currState = SentinalStates.KNOCKBACK
				velocity = -dir * knockback
				_attackTime += delta
				if _attackTime > attack_interval_min:
					_attackTime = 0
					currState = SentinalStates.IDLE
					print("Finished ")


func _has_line_of_sight() -> bool:
	if not player or not is_instance_valid(player):
		return false
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.exclude = [self]
	var result := space.intersect_ray(query)
	return result.is_empty() or result.get("collider") == player


func _attack_player() -> void:
	if not _has_line_of_sight():
		return
	var to_player := player.global_position - global_position
	var dir := to_player.normalized()
	velocity = dir * attackSpeed

	

	_attackTime = 0.0
