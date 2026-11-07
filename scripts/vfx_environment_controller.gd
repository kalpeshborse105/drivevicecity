extends Node3D
## Sky / atmosphere. Default: live India Standard Time on Sky3D.
## T cycles temporary presets (Golden / Noon / Night / Monsoon), then returns to IST.

@export var world_environment_path: NodePath = NodePath("../Sky3D")
@export var sun_light_path: NodePath = NodePath("../Sky3D/SunLight")
@export var player_car_path: NodePath = NodePath("../PlayerCar")

var _env_node: WorldEnvironment
var _sky: Sky3D
var _sun: DirectionalLight3D
var _car: Node
var _preset_idx: int = -1
var _live_ist: bool = true
var _ist_wait: float = 0.0

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
		# Soft contact shadows — blur 0 made a hard fake stamp under the car.
		_sun.shadow_blur = 1.5
		_sun.shadow_bias = 0.06
		_sun.shadow_normal_bias = 2.0
		_sun.shadow_opacity = 0.72
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		_sun.directional_shadow_blend_splits = true
		_sun.directional_shadow_fade_start = 0.85
		_sun.directional_shadow_max_distance = 90.0
	_apply_mobile_caps()
	_apply_base_vfx()
	_enable_live_ist()


func _process(delta: float) -> void:
	if not _live_ist or _sky == null:
		return
	_ist_wait += delta
	if _ist_wait < 20.0:
		return
	_ist_wait = 0.0
	_sync_ist_sky()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		_live_ist = false
		if _sky:
			_sky.game_time_enabled = false
		_preset_idx = (_preset_idx + 1) % PRESET_NAMES.size()
		apply_preset(_preset_idx)


func _enable_live_ist() -> void:
	_live_ist = true
	_preset_idx = -1
	if _sky:
		_sky.game_time_enabled = false
		_sky.editor_time_enabled = false
		_sky.update_interval = 1.0
	_sync_ist_sky()


func india_hour() -> float:
	## Asia/Kolkata = UTC+5:30
	var unix := Time.get_unix_time_from_system()
	var ist := int(unix) + int(5.5 * 3600.0)
	var now := Time.get_datetime_dict_from_unix_time(ist)
	return float(now.hour) + float(now.minute) / 60.0 + float(now.second) / 3600.0


func _sync_ist_sky() -> void:
	if _sky == null or _env_node == null or _env_node.environment == null:
		return
	var hour := india_hour()
	var night := hour < 6.0 or hour >= 19.0
	var sun_e := 1.35
	var moon_e := 0.2
	if night:
		sun_e = 0.12
		moon_e = 0.45
	elif hour < 8.0 or hour > 17.0:
		sun_e = 1.15
		moon_e = 0.28
	_set_sky_time(hour, sun_e, moon_e)
	var env := _env_node.environment
	if night:
		env.ambient_light_energy = 0.18
		env.fog_light_color = Color(0.08, 0.07, 0.14)
		env.fog_density = 0.0004
		env.glow_intensity = 0.5
	elif hour >= 16.0 and hour < 19.0:
		env.ambient_light_energy = 0.38
		env.fog_light_color = Color(0.88, 0.7, 0.52)
		env.fog_density = 0.00026
		env.glow_intensity = 0.28
	else:
		env.ambient_light_energy = 0.42
		env.fog_light_color = Color(0.8, 0.86, 0.94)
		env.fog_density = 0.00016
		env.glow_intensity = 0.28
	_notify_car_night(night)


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


func _apply_base_vfx() -> void:
	if _env_node == null or _env_node.environment == null:
		return
	var env := _env_node.environment
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.02
	env.tonemap_white = 6.0
	env.ssr_enabled = true
	env.ssr_max_steps = 24
	env.ssao_enabled = true
	# Keep mild contact AO; high intensity looked like a fake under-car stamp on asphalt.
	env.ssao_radius = 1.0
	env.ssao_intensity = 0.95
	env.ssil_enabled = false
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
		0:
			_set_sky_time(17.2, 1.3, 0.25)
			env.fog_light_color = Color(0.88, 0.7, 0.52)
			env.fog_density = 0.00026
			env.ambient_light_energy = 0.38
			env.glow_intensity = 0.28
			_notify_car_night(false)
		1:
			_set_sky_time(12.1, 1.5, 0.2)
			env.fog_light_color = Color(0.8, 0.86, 0.94)
			env.fog_density = 0.00016
			env.ambient_light_energy = 0.42
			env.glow_intensity = 0.28
			_notify_car_night(false)
		2:
			_set_sky_time(21.4, 0.15, 0.42)
			env.ambient_light_energy = 0.18
			env.fog_light_color = Color(0.08, 0.07, 0.14)
			env.fog_density = 0.0004
			env.glow_intensity = 0.55
			_notify_car_night(true)
		3:
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
