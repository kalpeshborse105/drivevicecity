extends Node3D
## Optional atmosphere presets (from reviewed VFX patch). Mobile-safe defaults.
## Press T to cycle: Golden Hour / Noon / Night / Monsoon.
## Does NOT scrape or brand Google Maps.

@export var world_environment_path: NodePath = NodePath("../Sky3D")
@export var sun_light_path: NodePath = NodePath("../Sky3D/SunLight")
@export var player_car_path: NodePath = NodePath("../PlayerCar")

var _env_node: WorldEnvironment
var _sky: Sky3D
var _sun: DirectionalLight3D
var _car: Node
var _preset_idx: int = 0

const PRESET_NAMES := ["Golden Hour Dhule", "Sunny Noon", "Night Drive", "Monsoon"]


func _ready() -> void:
	_env_node = get_node_or_null(world_environment_path) as WorldEnvironment
	_sky = _env_node as Sky3D
	_sun = get_node_or_null(sun_light_path) as DirectionalLight3D
	if _sun == null and _sky:
		_sun = _sky.get_node_or_null("SunLight") as DirectionalLight3D
	_car = get_node_or_null(player_car_path)
	if _sun:
		_sun.shadow_enabled = true
		_sun.shadow_blur = 0.0
		_sun.shadow_bias = 0.06
		_sun.shadow_normal_bias = 2.0
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		_sun.directional_shadow_blend_splits = true
		_sun.directional_shadow_fade_start = 0.9
		_sun.directional_shadow_max_distance = 140.0
	_apply_mobile_caps()
	_apply_base_vfx()
	apply_preset(0)


func _apply_mobile_caps() -> void:
	var gs := get_node_or_null("/root/GameSettings")
	var low := OS.has_feature("android") or OS.has_feature("mobile")
	if gs and int(gs.get("fx_quality")) == 0:
		low = true
	if low and _env_node and _env_node.environment:
		var env := _env_node.environment
		env.ssr_enabled = false
		env.ssao_enabled = false
		env.glow_intensity = 0.12


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		_preset_idx = (_preset_idx + 1) % PRESET_NAMES.size()
		apply_preset(_preset_idx)


func _apply_base_vfx() -> void:
	if _env_node == null or _env_node.environment == null:
		return
	var env := _env_node.environment
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.02
	env.tonemap_white = 6.0
	# Keep SSR/SSAO light — SSIL off (heavy on mid phones)
	env.ssr_enabled = true
	env.ssr_max_steps = 24
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.35
	env.ssil_enabled = false
	# Aerial haze gives distant Dhule depth without volumetric (mobile-safe).
	env.fog_aerial_perspective = 0.3
	env.fog_sky_affect = 0.4
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.32
	env.glow_bloom = 0.08
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.1


func apply_preset(index: int) -> void:
	if _env_node == null or _env_node.environment == null:
		return
	var env := _env_node.environment
	match index:
		0: # Golden hour — Sky3D sun sits late afternoon
			_set_sky_time(17.2, 1.3, 0.25)
			env.fog_light_color = Color(0.88, 0.7, 0.52)
			env.fog_density = 0.00026
			env.ambient_light_energy = 0.38
			env.glow_intensity = 0.28
			_notify_car_night(false)
		1: # Noon
			_set_sky_time(12.1, 1.5, 0.2)
			env.fog_light_color = Color(0.8, 0.86, 0.94)
			env.fog_density = 0.00016
			env.ambient_light_energy = 0.42
			env.glow_intensity = 0.28
			_notify_car_night(false)
		2: # Night — headlights via DrivingFX
			_set_sky_time(21.4, 0.15, 0.42)
			env.ambient_light_energy = 0.18
			env.fog_light_color = Color(0.08, 0.07, 0.14)
			env.fog_density = 0.0004
			env.glow_intensity = 0.55
			_notify_car_night(true)
		3: # Monsoon
			_set_sky_time(15.6, 0.55, 0.2)
			env.ambient_light_energy = 0.32
			env.fog_light_color = Color(0.5, 0.55, 0.6)
			env.fog_density = 0.00055
			env.glow_intensity = 0.25
			_notify_car_night(false)


func _set_sky_time(hour: float, sun_energy: float, moon_energy: float) -> void:
	if _sky == null:
		return
	_sky.current_time = hour
	_sky.sun_energy = sun_energy
	_sky.moon_energy = moon_energy


func _notify_car_night(night: bool) -> void:
	if _car == null:
		_car = get_node_or_null(player_car_path)
	if _car == null:
		return
	var fx := _car.get_node_or_null("DrivingFX")
	if fx and fx.has_method("set_night_mode"):
		fx.call("set_night_mode", night)
