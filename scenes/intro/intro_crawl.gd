extends Control

signal crawl_finished

@export var scroll_speed: float = 40.0
@export var fade_in_duration: float = 2.0
@export var descent_duration: float = 2.5

var _current_scroll_position: float = 0.0
var _crawl_active: bool = false
var _finished: bool = false
var _descending: bool = false

@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var header_space: Control = %HeaderSpace
@onready var footer_space: Control = %FooterSpace
@onready var crawl_label: RichTextLabel = %CrawlLabel

var _sand_particles: CPUParticles2D
var _blood_particles: CPUParticles2D
var _speed_lines: CPUParticles2D


func _ready() -> void:
	# Start loading the game scene in the background while intro plays
	SceneLoader.load_scene(AppConfig.game_scene_path, true)

	# Size header/footer so text starts off-screen below and can scroll fully off top
	header_space.custom_minimum_size.y = size.y
	footer_space.custom_minimum_size.y = size.y

	_setup_particles()

	# Start with everything transparent, then fade in
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_in_duration)
	tween.tween_callback(_start_crawl)


func _setup_particles() -> void:
	# Sand/dust particles - ambient floating motes
	_sand_particles = CPUParticles2D.new()
	_sand_particles.emitting = true
	_sand_particles.amount = 45
	_sand_particles.lifetime = 5.0
	_sand_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sand_particles.emission_rect_extents = Vector2(size.x / 2.0, size.y / 2.0)
	_sand_particles.position = Vector2(size.x / 2.0, size.y / 2.0)
	_sand_particles.direction = Vector2(0, 1)
	_sand_particles.spread = 45.0
	_sand_particles.gravity = Vector2(0, 0)
	_sand_particles.initial_velocity_min = 3.0
	_sand_particles.initial_velocity_max = 12.0
	_sand_particles.scale_amount_min = 1.0
	_sand_particles.scale_amount_max = 7.0
	var sand_gradient = Gradient.new()
	sand_gradient.set_color(0, Color(0.85, 0.75, 0.5, 0.0))
	sand_gradient.add_point(0.15, Color(0.85, 0.75, 0.5, 0.35))
	sand_gradient.add_point(0.85, Color(0.85, 0.75, 0.5, 0.25))
	sand_gradient.set_color(1, Color(0.85, 0.75, 0.5, 0.0))
	_sand_particles.color_ramp = sand_gradient
	add_child(_sand_particles)
	move_child(_sand_particles, 1)  # After Background, before ScrollContainer

	# Blood/red accent particles - fewer, larger, slower
	_blood_particles = CPUParticles2D.new()
	_blood_particles.emitting = true
	_blood_particles.amount = 12
	_blood_particles.lifetime = 7.0
	_blood_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_blood_particles.emission_rect_extents = Vector2(size.x / 2.0, size.y / 2.0)
	_blood_particles.position = Vector2(size.x / 2.0, size.y / 2.0)
	_blood_particles.direction = Vector2(0, 1)
	_blood_particles.spread = 60.0
	_blood_particles.gravity = Vector2(0, 0)
	_blood_particles.initial_velocity_min = 2.0
	_blood_particles.initial_velocity_max = 6.0
	_blood_particles.scale_amount_min = 2.0
	_blood_particles.scale_amount_max = 9.0
	var blood_gradient = Gradient.new()
	blood_gradient.set_color(0, Color(0.55, 0.12, 0.12, 0.0))
	blood_gradient.add_point(0.2, Color(0.55, 0.12, 0.12, 0.25))
	blood_gradient.add_point(0.8, Color(0.55, 0.12, 0.12, 0.15))
	blood_gradient.set_color(1, Color(0.55, 0.12, 0.12, 0.0))
	_blood_particles.color_ramp = blood_gradient
	add_child(_blood_particles)
	move_child(_blood_particles, 2)  # After sand particles

	# Speed lines - only activated during descent to sell the falling motion
	_speed_lines = CPUParticles2D.new()
	_speed_lines.emitting = false  # starts hidden, activated on descent
	_speed_lines.amount = 35
	_speed_lines.lifetime = 0.6
	_speed_lines.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	# Emit from wide horizontal band so lines come from across the screen
	_speed_lines.emission_rect_extents = Vector2(size.x / 2.0, size.y / 2.0)
	_speed_lines.position = Vector2(size.x / 2.0, size.y / 2.0)
	_speed_lines.direction = Vector2(0, -1)  # rush upward
	_speed_lines.spread = 5.0  # very tight = vertical streaks
	_speed_lines.gravity = Vector2(0, 0)
	_speed_lines.initial_velocity_min = 600.0
	_speed_lines.initial_velocity_max = 1200.0
	_speed_lines.scale_amount_min = 2.0
	_speed_lines.scale_amount_max = 7.0
	var speed_gradient = Gradient.new()
	speed_gradient.set_color(0, Color(0.75, 0.65, 0.45, 0.0))
	speed_gradient.add_point(0.05, Color(0.8, 0.7, 0.5, 0.6))
	speed_gradient.add_point(0.5, Color(0.7, 0.6, 0.4, 0.4))
	speed_gradient.set_color(1, Color(0.6, 0.5, 0.35, 0.0))
	_speed_lines.color_ramp = speed_gradient
	add_child(_speed_lines)
	move_child(_speed_lines, 3)


func _start_crawl() -> void:
	_crawl_active = true
	scroll_container.scroll_vertical = 0
	_current_scroll_position = 0.0


func _process(delta: float) -> void:
	if not _crawl_active or _finished:
		return
	_current_scroll_position += scroll_speed * delta
	scroll_container.scroll_vertical = round(_current_scroll_position)

	# Check if all text has scrolled past the top of the viewport
	var max_scroll = scroll_container.get_v_scroll_bar().max_value - scroll_container.size.y
	if _current_scroll_position >= max_scroll:
		_on_crawl_finished()


func _on_crawl_finished() -> void:
	if _finished:
		return
	_finished = true
	_crawl_active = false
	crawl_finished.emit()
	_begin_descent()


func _begin_descent() -> void:
	_descending = true

	# Accelerate particles upward to simulate falling down
	# (we're descending, so particles rush past us upward)
	var tween = create_tween()
	tween.set_parallel(true)

	# Fade out the text and top gradient
	tween.tween_property(scroll_container, "modulate:a", 0.0, 0.4)
	var top_gradient = get_node_or_null("TopGradient")
	if top_gradient:
		tween.tween_property(top_gradient, "modulate:a", 0.0, 0.4)
	var skip_label = get_node_or_null("SkipLabel")
	if skip_label:
		tween.tween_property(skip_label, "modulate:a", 0.0, 0.3)

	# After text fades, start the descent particle rush
	tween.chain()

	# Activate speed lines for falling streaks
	_speed_lines.emitting = true

	# Boost sand particles - rush upward
	_sand_particles.direction = Vector2(0, -1)
	_sand_particles.initial_velocity_min = 150.0
	_sand_particles.initial_velocity_max = 400.0
	_sand_particles.amount = 80
	_sand_particles.lifetime = 2.0
	_sand_particles.spread = 15.0
	_sand_particles.scale_amount_min = 1.5
	_sand_particles.scale_amount_max = 6.0
	# Brighter sand during descent
	var descent_sand = Gradient.new()
	descent_sand.set_color(0, Color(0.85, 0.75, 0.5, 0.0))
	descent_sand.add_point(0.1, Color(0.9, 0.8, 0.55, 0.5))
	descent_sand.add_point(0.9, Color(0.85, 0.75, 0.5, 0.4))
	descent_sand.set_color(1, Color(0.85, 0.75, 0.5, 0.0))
	_sand_particles.color_ramp = descent_sand

	# Boost blood particles - rush upward
	_blood_particles.direction = Vector2(0, -1)
	_blood_particles.initial_velocity_min = 100.0
	_blood_particles.initial_velocity_max = 300.0
	_blood_particles.amount = 20
	_blood_particles.lifetime = 2.5
	_blood_particles.spread = 20.0
	# Brighter blood during descent
	var descent_blood = Gradient.new()
	descent_blood.set_color(0, Color(0.6, 0.1, 0.1, 0.0))
	descent_blood.add_point(0.1, Color(0.6, 0.1, 0.1, 0.4))
	descent_blood.add_point(0.9, Color(0.55, 0.12, 0.12, 0.3))
	descent_blood.set_color(1, Color(0.55, 0.12, 0.12, 0.0))
	_blood_particles.color_ramp = descent_blood

	# After the descent effect plays, fade particles out and transition
	var fade_tween = create_tween()
	fade_tween.tween_interval(descent_duration - 0.8)
	# Gradually reduce particles to darkness
	fade_tween.tween_callback(func():
		_sand_particles.amount = 30
		_sand_particles.initial_velocity_min = 60.0
		_sand_particles.initial_velocity_max = 150.0
		var fading_sand = Gradient.new()
		fading_sand.set_color(0, Color(0.85, 0.75, 0.5, 0.0))
		fading_sand.add_point(0.1, Color(0.85, 0.75, 0.5, 0.2))
		fading_sand.add_point(0.9, Color(0.85, 0.75, 0.5, 0.1))
		fading_sand.set_color(1, Color(0.85, 0.75, 0.5, 0.0))
		_sand_particles.color_ramp = fading_sand
		_blood_particles.amount = 8
		_blood_particles.initial_velocity_min = 40.0
		_blood_particles.initial_velocity_max = 100.0
		# Slow down speed lines
		_speed_lines.initial_velocity_min = 200.0
		_speed_lines.initial_velocity_max = 400.0
		_speed_lines.amount = 15
	)
	fade_tween.tween_interval(0.8)
	fade_tween.tween_callback(func():
		_sand_particles.emitting = false
		_blood_particles.emitting = false
		_speed_lines.emitting = false
	)
	# Brief hold on black, then load game
	fade_tween.tween_interval(0.3)
	fade_tween.tween_callback(_load_game)


func _load_game() -> void:
	if SceneLoader.get_status() == ResourceLoader.THREAD_LOAD_LOADED:
		SceneLoader.change_scene_to_resource()
	else:
		SceneLoader.scene_loaded.connect(
			func(): SceneLoader.change_scene_to_resource(),
			CONNECT_ONE_SHOT
		)


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_released("ui_cancel") or \
	   event.is_action_released("ui_accept") or \
	   (event is InputEventMouseButton and not event.is_pressed()):
		_finished = true
		_crawl_active = false
		crawl_finished.emit()
		# Quick descent when skipping
		_begin_descent_quick()


func _begin_descent_quick() -> void:
	# Abbreviated descent for skip - still looks cool but faster
	_descending = true

	# Immediately hide text
	scroll_container.modulate.a = 0.0
	var top_gradient = get_node_or_null("TopGradient")
	if top_gradient:
		top_gradient.modulate.a = 0.0
	var skip_label = get_node_or_null("SkipLabel")
	if skip_label:
		skip_label.modulate.a = 0.0

	# Brief particle rush
	_sand_particles.direction = Vector2(0, -1)
	_sand_particles.initial_velocity_min = 200.0
	_sand_particles.initial_velocity_max = 500.0
	_sand_particles.amount = 60
	_sand_particles.lifetime = 1.0
	_sand_particles.spread = 15.0

	_blood_particles.direction = Vector2(0, -1)
	_blood_particles.initial_velocity_min = 150.0
	_blood_particles.initial_velocity_max = 400.0
	_blood_particles.amount = 15
	_blood_particles.lifetime = 1.2
	_blood_particles.spread = 20.0

	# Activate speed lines
	_speed_lines.emitting = true

	var tween = create_tween()
	tween.tween_interval(0.6)
	tween.tween_callback(func():
		_sand_particles.emitting = false
		_blood_particles.emitting = false
		_speed_lines.emitting = false
	)
	tween.tween_interval(0.2)
	tween.tween_callback(_load_game)


func _on_resized() -> void:
	header_space.custom_minimum_size.y = size.y
	footer_space.custom_minimum_size.y = size.y
	_current_scroll_position = scroll_container.scroll_vertical
	# Update particle emission area on resize
	if _sand_particles and not _descending:
		_sand_particles.emission_rect_extents = Vector2(size.x / 2.0, size.y / 2.0)
		_sand_particles.position = Vector2(size.x / 2.0, size.y / 2.0)
	if _blood_particles and not _descending:
		_blood_particles.emission_rect_extents = Vector2(size.x / 2.0, size.y / 2.0)
		_blood_particles.position = Vector2(size.x / 2.0, size.y / 2.0)
