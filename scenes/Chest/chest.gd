extends Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_area: Area2D = $InteractArea2D
@onready var prompt_label: Label = $PromptLabel

@export var is_mimic := false
const INTERACT_ICON = "E"
var blood_scene = preload("res://scenes/Blood/Blood.tscn")
var rng = RandomNumberGenerator.new()

var player_near := false
var waiting_for_reach_in := false
var looted := false
var current_player: Node2D = null
var mimic_sequence_active := false

const MIMIC_BITE_DURATION = 2
const CAMERA_ZOOM_IN_TIME = 0.35
const CAMERA_ZOOM_OUT_TIME = 0.45
const CAMERA_ZOOM_IN_FACTOR = 1.45


func _ready() -> void:
	rng.randomize()
	animated_sprite.play("Closed")
	interact_area.body_entered.connect(_on_interact_area_body_entered)
	interact_area.body_exited.connect(_on_interact_area_body_exited)
	_update_prompt()


func _process(_delta: float) -> void:
	if not player_near or mimic_sequence_active:
		return
	if Input.is_action_just_pressed("interact"):
		_handle_interact()


func set_is_mimic(value: bool) -> void:
	is_mimic = value


func _handle_interact() -> void:
	if looted:
		return

	if not waiting_for_reach_in:
		if is_mimic:
			# "Looted" is the coin-open visual in this sprite sheet.
			animated_sprite.play("Looted")
		else:
			animated_sprite.play("Looted")
		waiting_for_reach_in = true
		_update_prompt()
		return

	if is_mimic:
		start_mimic_trap_sequence()
		return

	animated_sprite.play("Open")
	looted = true
	_update_prompt()


func _on_interact_area_body_entered(body: Node) -> void:
	var player = _resolve_player_node(body)
	if player != null:
		current_player = player
		player_near = true
		_update_prompt()


func _on_interact_area_body_exited(body: Node) -> void:
	var player = _resolve_player_node(body)
	if player != null:
		if current_player == player:
			current_player = null
		player_near = false
		_update_prompt()


func _is_player_body(body: Node) -> bool:
	return _resolve_player_node(body) != null


func _resolve_player_node(body: Node) -> Node2D:
	if body is Node2D and body.is_in_group("player"):
		return body as Node2D

	var parent = body.get_parent()
	if parent is Node2D and parent.is_in_group("player"):
		return parent as Node2D

	return null


func _update_prompt() -> void:
	if not player_near or looted or mimic_sequence_active:
		prompt_label.visible = false
		return

	prompt_label.visible = true
	if waiting_for_reach_in:
		prompt_label.text = "%s Reach in" % INTERACT_ICON
	else:
		prompt_label.text = "%s Open" % INTERACT_ICON


func start_mimic_trap_sequence() -> void:
	if mimic_sequence_active:
		return

	mimic_sequence_active = true
	prompt_label.visible = false

	var player_camera: Camera2D = null
	var original_zoom := Vector2.ONE
	if current_player != null and is_instance_valid(current_player):
		if current_player.has_method("set_controls_locked"):
			current_player.set_controls_locked(true)
		player_camera = current_player.get_node_or_null("Camera2D") as Camera2D
		if player_camera != null:
			original_zoom = player_camera.zoom
			var zoom_in_tween = create_tween()
			zoom_in_tween.tween_property(player_camera, "zoom", original_zoom * CAMERA_ZOOM_IN_FACTOR, CAMERA_ZOOM_IN_TIME)
	animated_sprite.play("Mimic")

	await get_tree().create_timer(MIMIC_BITE_DURATION).timeout

	animated_sprite.play("Closed")
	spawn_blood_on_ground()
	if current_player != null and is_instance_valid(current_player) and current_player.has_method("take_damage"):
		current_player.take_damage(1)
	waiting_for_reach_in = false

	if player_camera != null:
		var zoom_out_tween = create_tween()
		zoom_out_tween.tween_property(player_camera, "zoom", original_zoom, CAMERA_ZOOM_OUT_TIME)
		await zoom_out_tween.finished

	if current_player != null and is_instance_valid(current_player) and current_player.has_method("set_controls_locked"):
		current_player.set_controls_locked(false)

	mimic_sequence_active = false
	_update_prompt()


func spawn_blood_on_ground() -> void:
	var blood = blood_scene.instantiate()
	var blood_position = global_position + Vector2(0, 4)
	if current_player != null and is_instance_valid(current_player):
		blood_position = (current_player.global_position + global_position) * 0.5 + Vector2(0, 4)

	# Add slight jitter so repeated splats don't stack perfectly.
	blood_position += Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-2.0, 2.0))

	var parent = get_parent()
	if parent != null:
		parent.add_child(blood)
		if blood is Node2D:
			(blood as Node2D).global_position = blood_position
			(blood as Node2D).z_index = z_index
		# Keep blood above tile layers but behind chest.
		parent.move_child(blood, get_index())
	else:
		get_tree().current_scene.add_child(blood)
		if blood is Node2D:
			(blood as Node2D).global_position = blood_position
