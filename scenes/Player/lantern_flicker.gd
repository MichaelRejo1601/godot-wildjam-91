extends PointLight2D

@export var base_energy: float = 1.55
@export var energy_jitter: float = 0.04
@export var peak_energy_boost_min: float = 0.04
@export var peak_energy_boost_max: float = 0.08

@export var base_radius: float = 4.9
@export var radius_jitter: float = 0.25
@export var peak_radius_boost_min: float = 0.18
@export var peak_radius_boost_max: float = 0.45

@export var min_health_radius_scale: float = 0.45
@export var min_health_energy_scale: float = 0.7
@export var lamp_off_energy: float = 0.5
@export var lamp_off_radius: float = 0.40
@export var held_energy_multiplier: float = 1.05
@export var held_radius_multiplier: float = 1.25

@export var horror_interval_low_madness: float = 3.0
@export var horror_interval_high_madness: float = 0.30
@export var horror_off_duration_low_madness: float = 0.03
@export var horror_off_duration_high_madness: float = 0.35
@export var horror_start_madness_ratio: float = 0.50
@export var horror_blackout_fade_time: float = 0.10

@export var low_hold_min_time: float = 0.10
@export var low_hold_max_time: float = 0.35
@export var rise_min_time: float = 1.05 / 2
@export var rise_max_time: float = 1.10 / 2
@export var fall_min_time: float = 1.06 / 2
@export var fall_max_time: float = 1.14 / 2

enum FlickerPhase {
	HOLD_LOW,
	RISE,
	FALL,
}

var rng := RandomNumberGenerator.new()
var phase: FlickerPhase = FlickerPhase.HOLD_LOW
var phase_time := 0.0
var phase_duration := 0.0

var low_energy := 0.0
var peak_energy := 0.0
var low_radius := 0.0
var peak_radius := 0.0
var health_ratio := 1.0
var madness_ratio := 0.0
var lamp_enabled := true
var lamp_held := false
var _horror_next_flicker_time := 0.0
var _horror_off_time_remaining := 0.0
var _horror_blackout_blend := 0.0


func _ready() -> void:
	rng.randomize()
	start_new_cycle()
	_schedule_next_horror_flicker()


func _process(delta: float) -> void:
	if not lamp_enabled:
		energy = lamp_off_energy
		texture_scale = lamp_off_radius
		return

	_update_horror_flicker(delta)
	var blackout_target: float = 1.0 if _horror_off_time_remaining > 0.0 else 0.0
	var fade_speed: float = 1.0 / max(horror_blackout_fade_time, 0.001)
	_horror_blackout_blend = move_toward(_horror_blackout_blend, blackout_target, delta * fade_speed)

	phase_time += delta
	var t := 1.0
	if phase_duration > 0.0:
		t = clamp(phase_time / phase_duration, 0.0, 1.0)

	var phase_energy := _apply_health_energy_scale(low_energy)
	var phase_radius := _apply_health_radius_scale(low_radius)

	match phase:
		FlickerPhase.HOLD_LOW:
			phase_energy = _apply_health_energy_scale(low_energy)
			phase_radius = _apply_health_radius_scale(low_radius)
		FlickerPhase.RISE:
			# Lantern snaps brighter quickly.
			phase_energy = _apply_health_energy_scale(lerp(low_energy, peak_energy, _ease_out(t)))
			phase_radius = _apply_health_radius_scale(lerp(low_radius, peak_radius, _ease_out(t)))
		FlickerPhase.FALL:
			# Then decays right away and never lingers at the top.
			phase_energy = _apply_health_energy_scale(lerp(peak_energy, low_energy, _ease_in(t)))
			phase_radius = _apply_health_radius_scale(lerp(peak_radius, low_radius, _ease_in(t)))

	energy = lerp(phase_energy, lamp_off_energy, _horror_blackout_blend)
	texture_scale = lerp(phase_radius, lamp_off_radius, _horror_blackout_blend)

	if phase_time >= phase_duration:
		advance_phase()


func start_new_cycle() -> void:
	low_energy = max(0.0, base_energy + rng.randf_range(-energy_jitter, energy_jitter))
	peak_energy = low_energy + rng.randf_range(peak_energy_boost_min, peak_energy_boost_max)

	low_radius = max(0.1, base_radius + rng.randf_range(-radius_jitter, radius_jitter))
	peak_radius = low_radius + rng.randf_range(peak_radius_boost_min, peak_radius_boost_max)

	phase = FlickerPhase.HOLD_LOW
	phase_time = 0.0
	phase_duration = rng.randf_range(low_hold_min_time, low_hold_max_time)


func advance_phase() -> void:
	phase_time = 0.0
	match phase:
		FlickerPhase.HOLD_LOW:
			phase = FlickerPhase.RISE
			phase_duration = rng.randf_range(rise_min_time, rise_max_time)
		FlickerPhase.RISE:
			phase = FlickerPhase.FALL
			phase_duration = rng.randf_range(fall_min_time, fall_max_time)
		FlickerPhase.FALL:
			start_new_cycle()


func _ease_in(t: float) -> float:
	return t * t


func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


func set_health_ratio(value: float) -> void:
	health_ratio = clamp(value, 0.0, 1.0)


func set_madness_ratio(value: float) -> void:
	madness_ratio = clamp(value, 0.0, 1.0)
	_schedule_next_horror_flicker()


func set_lamp_enabled(value: bool) -> void:
	lamp_enabled = value


func set_lamp_held(value: bool) -> void:
	lamp_held = value


func is_horror_blackout_active() -> bool:
	return lamp_enabled and _horror_blackout_blend > 0.35


func _apply_health_radius_scale(value: float) -> float:
	var scale: float = lerpf(min_health_radius_scale, 1.0, health_ratio)
	var held_scale: float = held_radius_multiplier if lamp_held else 1.0
	return value * scale * held_scale


func _apply_health_energy_scale(value: float) -> float:
	var scale: float = lerpf(min_health_energy_scale, 1.0, health_ratio)
	var held_scale: float = held_energy_multiplier if lamp_held else 1.0
	return value * scale * held_scale


func _update_horror_flicker(delta: float) -> void:
	var effective_madness: float = clampf(
		(madness_ratio - horror_start_madness_ratio) / maxf(1.0 - horror_start_madness_ratio, 0.001),
		0.0,
		1.0
	)

	if effective_madness <= 0.0:
		_horror_off_time_remaining = 0.0
		_horror_next_flicker_time = max(_horror_next_flicker_time - delta, 0.0)
		return

	if _horror_off_time_remaining > 0.0:
		_horror_off_time_remaining = max(_horror_off_time_remaining - delta, 0.0)
		if _horror_off_time_remaining <= 0.0:
			_schedule_next_horror_flicker()
		return

	_horror_next_flicker_time -= delta
	if _horror_next_flicker_time > 0.0:
		return

	_horror_off_time_remaining = rng.randf_range(
		lerpf(horror_off_duration_low_madness, horror_off_duration_high_madness, effective_madness),
		lerpf(horror_off_duration_low_madness, horror_off_duration_high_madness, effective_madness) * 1.35
	)


func _schedule_next_horror_flicker() -> void:
	var effective_madness: float = clampf(
		(madness_ratio - horror_start_madness_ratio) / maxf(1.0 - horror_start_madness_ratio, 0.001),
		0.0,
		1.0
	)

	if effective_madness <= 0.0:
		_horror_next_flicker_time = horror_interval_low_madness
		return

	var base_interval: float = lerpf(horror_interval_low_madness, horror_interval_high_madness, effective_madness)
	_horror_next_flicker_time = rng.randf_range(base_interval * 0.7, base_interval * 1.3)
