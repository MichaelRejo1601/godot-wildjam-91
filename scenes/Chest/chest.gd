extends Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_area: Area2D = $InteractArea2D
@onready var prompt_label: Label = $PromptLabel

@export var is_mimic := false

var player_near := false
var waiting_for_reach_in := false
var looted := false


func _ready() -> void:
	animated_sprite.play("Closed")
	interact_area.body_entered.connect(_on_interact_area_body_entered)
	interact_area.body_exited.connect(_on_interact_area_body_exited)
	_update_prompt()


func _process(_delta: float) -> void:
	if not player_near:
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
			animated_sprite.play("Mimic")
		else:
			animated_sprite.play("Looted")
		waiting_for_reach_in = true
		_update_prompt()
		return

	if is_mimic:
		animated_sprite.play("Closed")
		waiting_for_reach_in = false
		_update_prompt()
		return

	animated_sprite.play("Open")
	looted = true
	_update_prompt()


func _on_interact_area_body_entered(body: Node) -> void:
	if _is_player_body(body):
		player_near = true
		_update_prompt()


func _on_interact_area_body_exited(body: Node) -> void:
	if _is_player_body(body):
		player_near = false
		_update_prompt()


func _is_player_body(body: Node) -> bool:
	if body.is_in_group("player"):
		return true
	var parent = body.get_parent()
	return parent != null and parent.is_in_group("player")


func _update_prompt() -> void:
	if not player_near or looted:
		prompt_label.visible = false
		return

	prompt_label.visible = true
	if waiting_for_reach_in:
		prompt_label.text = "Press E to reach in"
	else:
		prompt_label.text = "Press E to open"
