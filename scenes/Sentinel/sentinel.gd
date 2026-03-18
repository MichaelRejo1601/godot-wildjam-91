extends CharacterBody2D

@export var obstacles: TileMapLayer

@export var dungeon_root: NodePath
var dungeon_tilemaps: Array = []

@export var speed: float = 60.0
@export var change_interval: float = 2.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _dir: Vector2 = Vector2.RIGHT
var _time: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

enum SentinalStates {
	IDLE, 
	WALK,
	ATTACK
}

var currState: SentinalStates = SentinalStates.IDLE

var health = 3
var player
var chasing = false

func _ready() -> void:
	rng.randomize()
	_pick_direction()
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	$AnimatedSprite2D.play("Idle")
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

func _physics_process(delta: float) -> void:
	var dist = global_position.distance_to(player.global_position) if player else 1000
	if dist < 200:
		chasing = true
		_dir = (player.global_position - global_position).normalized()
		$AnimatedSprite2D.play("Run")
		currState = SentinalStates.WALK
	else:
		chasing = false
		$AnimatedSprite2D.play("Idle")
		currState = SentinalStates.IDLE
		_time += delta
		if _time >= change_interval:
			_time = 0.0
			_pick_direction()
	velocity = _dir * speed
	move_and_slide()
	if is_on_wall() and not chasing:
		_pick_direction()

func _pick_direction() -> void:
	var angle = rng.randf_range(0.0, TAU)
	_dir = Vector2(cos(angle), sin(angle)).normalized()

<<<<<<< HEAD

func take_damage(amount):
	health -= amount
	if health <= 0:
		queue_free()
