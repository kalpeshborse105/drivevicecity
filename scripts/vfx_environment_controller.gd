extends Node3D
## Optional atmosphere presets (from reviewed VFX patch). Mobile-safe defaults.
## Press T to cycle: Golden Hour / Noon / Night / Monsoon.
## Does NOT scrape or brand Google Maps.

@export var world_environment_path: NodePath = NodePath("../WorldEnvironment")
@export var sun_light_path: NodePath = NodePath("../Sun")
@export var player_car_path: NodePath = NodePath("../PlayerCar")

var _env_node: WorldEnvironment
var _sun: DirectionalLight3D
var _car: Node
var _preset_idx: int = 0

const PRESET_NAMES := ["Golden Hour Dhule", "Sunny Noon", "Night Drive", "Monsoon"]


func _ready() -> void:
	_env_node = get_node_or_null(world_environment_path) as WorldEnvironment
	_sun = get_node_or_null(sun_light_path) as DirectionalLight3D
	_car = get_node_or_null(player_car_path)
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
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.32
	env.glow_bloom = 0.08
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.08


func apply_preset(index: int) -> void:
	if _env_node == null or _env_node.environment == null:
		return
	var env := _env_node.environment
	var sky_mat: ProceduralSkyMaterial = null
	if env.sky:
		sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	match index:
		0: # Golden hour
			if sky_mat:
				sky_mat.sky_top_color = Color(0.22, 0.42, 0.72)
				sky_mat.sky_horizon_color = Color(0.94, 0.66, 0.38)
			if _sun:
				_sun.light_color = Color(1.0, 0.84, 0.62)
				_sun.light_energy = 1.28
			env.fog_light_color = Color(0.9, 0.72, 0.52)
			env.fog_density = 0.00032
			env.glow_intensity = 0.32
		1: # Noon
			if sky_mat:
				sky_mat.sky_top_color = Color(0.2, 0.5, 0.88)
				sky_mat.sky_horizon_color = Color(0.76, 0.88, 0.96)
			if _sun:
				_sun.light_color = Color(1.0, 0.97, 0.92)
				_sun.light_energy = 1.55
			env.fog_light_color = Color(0.8, 0.86, 0.94)
			env.fog_density = 0.00016
			env.glow_intensity = 0.28
		2: # Night — headlights via DrivingFX; keep shadows soft
			if sky_mat:
				sky_mat.sky_top_color = Color(0.03, 0.04, 0.09)
				sky_mat.sky_horizon_color = Color(0.1, 0.08, 0.18)
			if _sun:
				_sun.light_color = Color(0.35, 0.42, 0.7)
				_sun.light_energy = 0.22
				_sun.shadow_enabled = true
			env.ambient_light_energy = 0.18
			env.fog_light_color = Color(0.08, 0.07, 0.14)
			env.fog_density = 0.0004
			env.glow_intensity = 0.55
			_notify_car_night(true)
		3: # Monsoon
			if sky_mat:
				sky_mat.sky_top_color = Color(0.28, 0.32, 0.38)
				sky_mat.sky_horizon_color = Color(0.48, 0.52, 0.56)
			if _sun:
				_sun.light_color = Color(0.78, 0.84, 0.9)
				_sun.light_energy = 0.7
			env.ambient_light_energy = 0.32
			env.fog_light_color = Color(0.5, 0.55, 0.6)
			env.fog_density = 0.00055
			env.glow_intensity = 0.25
			_notify_car_night(false)
	if index != 2:
		if index == 0 or index == 1:
			env.ambient_light_energy = 0.38 if index == 0 else 0.42
			_notify_car_night(false)


func _notify_car_night(night: bool) -> void:
	if _car == null:
		_car = get_node_or_null(player_car_path)
	if _car == null:
		return
	var fx := _car.get_node_or_null("DrivingFX")
	if fx and fx.has_method("set_night_mode"):
		fx.call("set_night_mode", night)
