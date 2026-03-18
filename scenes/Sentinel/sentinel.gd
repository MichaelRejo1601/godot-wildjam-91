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

func _ready() -> void:
	rng.randomize()
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

func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= change_interval:
		_time = 0.0
		_pick_direction()
	velocity = _dir * speed
	if velocity.length() > 0:
		currState = SentinalStates.WALK
	else:
		currState = SentinalStates.IDLE

	_checkAnimation()

	move_and_slide()
	if is_on_wall():
		_pick_direction()

func _pick_direction() -> void:
	var angle = rng.randf_range(0.0, TAU)
	_dir = Vector2(cos(angle), sin(angle)).normalized()


func _checkAnimation():
	match currState:
		SentinalStates.IDLE:
			animated_sprite.play("Idle")
		SentinalStates.ATTACK:
			animated_sprite.play("Attack")
		SentinalStates.WALK:
			animated_sprite.play("Run")