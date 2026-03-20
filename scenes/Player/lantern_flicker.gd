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


func _ready() -> void:
	rng.randomize()
	start_new_cycle()


func _process(delta: float) -> void:
	phase_time += delta
	var t := 1.0
	if phase_duration > 0.0:
		t = clamp(phase_time / phase_duration, 0.0, 1.0)

	match phase:
		FlickerPhase.HOLD_LOW:
			energy = _apply_health_energy_scale(low_energy)
			texture_scale = _apply_health_radius_scale(low_radius)
		FlickerPhase.RISE:
			# Lantern snaps brighter quickly.
			energy = _apply_health_energy_scale(lerp(low_energy, peak_energy, _ease_out(t)))
			texture_scale = _apply_health_radius_scale(lerp(low_radius, peak_radius, _ease_out(t)))
		FlickerPhase.FALL:
			# Then decays right away and never lingers at the top.
			energy = _apply_health_energy_scale(lerp(peak_energy, low_energy, _ease_in(t)))
			texture_scale = _apply_health_radius_scale(lerp(peak_radius, low_radius, _ease_in(t)))

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


func _apply_health_radius_scale(value: float) -> float:
	var scale = lerp(min_health_radius_scale, 1.0, health_ratio)
	return value * scale


func _apply_health_energy_scale(value: float) -> float:
	var scale = lerp(min_health_energy_scale, 1.0, health_ratio)
	return value * scale
