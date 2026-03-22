extends Node2D

signal player_entered

const INTERACT_ICON: String = "E"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var interact_area: Area2D
var prompt_label: Label
var _player_near: bool = false


func _ready() -> void:
	_ensure_interact_area()
	_ensure_prompt_label()
	if animated_sprite != null and animated_sprite.sprite_frames != null:
		animated_sprite.play("default")
	_update_prompt()


func _process(_delta: float) -> void:
	if not _player_near:
		return
	if Input.is_action_just_pressed("interact"):
		player_entered.emit()


func _ensure_interact_area() -> void:
	interact_area = get_node_or_null("InteractArea2D") as Area2D
	if interact_area == null:
		interact_area = Area2D.new()
		interact_area.name = "InteractArea2D"
		add_child(interact_area)

	var shape_node := interact_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		interact_area.add_child(shape_node)

	if shape_node.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(42.0, 36.0)
		shape_node.shape = rect

	if not interact_area.body_entered.is_connected(_on_interact_area_body_entered):
		interact_area.body_entered.connect(_on_interact_area_body_entered)
	if not interact_area.body_exited.is_connected(_on_interact_area_body_exited):
		interact_area.body_exited.connect(_on_interact_area_body_exited)


func _ensure_prompt_label() -> void:
	prompt_label = get_node_or_null("PromptLabel") as Label
	if prompt_label == null:
		prompt_label = Label.new()
		prompt_label.name = "PromptLabel"
		add_child(prompt_label)

	prompt_label.text = "%s Descend" % INTERACT_ICON
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.set("theme_override_font_sizes/font_size", 8)
	prompt_label.position = Vector2(-24.0, -22.0)
	prompt_label.size = Vector2(48.0, 14.0)


func _on_interact_area_body_entered(body: Node) -> void:
	if _resolve_player_node(body) != null:
		_player_near = true
		_update_prompt()


func _on_interact_area_body_exited(body: Node) -> void:
	if _resolve_player_node(body) != null:
		_player_near = false
		_update_prompt()


func _resolve_player_node(body: Node) -> Node2D:
	if body is Node2D and body.is_in_group("player"):
		return body as Node2D

	var parent := body.get_parent()
	if parent is Node2D and parent.is_in_group("player"):
		return parent as Node2D

	return null


func _update_prompt() -> void:
	if prompt_label == null:
		return
	prompt_label.visible = _player_near
	prompt_label.text = "%s Descend" % INTERACT_ICON
