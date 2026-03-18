extends CharacterBody2D


const SPEED = 300.0

var is_attacking = false
var attack_cooldown = 0.0


func _ready():
	$AnimatedSprite2D.animation_finished.connect(_on_attack_finished)
	$Area2D.body_entered.connect(_on_whip_hit)
	add_to_group("player")


func _physics_process(delta: float) -> void:
	# Add the gravity.
	
	# Get the input directionX and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var directionX := Input.get_axis("move_left", "move_right")
	var directionY := Input.get_axis("move_up", "move_down")

	if directionX:
		velocity.x = directionX * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	
	# Get the input directionX and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var directionX := Input.get_axis("move_left", "move_right")
	var directionY := Input.get_axis("move_up", "move_down")

	if directionX:
		velocity.x = directionX * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if directionY:
		velocity.y = directionY * SPEED
	else:
		velocity.y = move_toward(velocity.y, 0, SPEED)

	# Handle attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta

	# Handle attack input
	if Input.is_action_just_pressed("attack") and not is_attacking and attack_cooldown <= 0:
		start_attack()

	move_and_slide()


func start_attack():
	is_attacking = true
	attack_cooldown = 1.0
	$AnimatedSprite2D.play("attack")
	$Area2D.monitoring = true


func _on_attack_finished():
	if $AnimatedSprite2D.animation == "attack":
		is_attacking = false
		$Area2D.monitoring = false
		$AnimatedSprite2D.play("idle")


func _on_whip_hit(body):
	if body.is_in_group("enemies"):
		body.take_damage(1)
