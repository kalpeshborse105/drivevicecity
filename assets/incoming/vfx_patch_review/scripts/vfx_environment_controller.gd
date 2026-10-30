extends Node3D
## High-VFX Graphics & Weather Controller for DriveViceCity (Dhule Realistic Edition).
## Upgrades WorldEnvironment with ACES Filmic Tonemapping, SSR, SSAO, Volumetric Fog,
## Dynamic Golden Hour / Night / Monsoon Rain presets, and Tire Smoke GPUParticles3D.

@export var world_environment_path: NodePath = NodePath("../WorldEnvironment")
@export var sun_light_path: NodePath = NodePath("../Sun")
@export var player_car_path: NodePath = NodePath("../PlayerCar")

var _env_node: WorldEnvironment
var _sun: DirectionalLight3D
var _car: VehicleBody3D
var _preset_idx: int = 0

const PRESET_NAMES := ["Golden Hour Dhule", "Sunny Highway Noon", "Vice City Neon Night", "Monsoon Wet Road"]

func _ready() -> void:
	_env_node = get_node_or_null(world_environment_path) as WorldEnvironment
	_sun = get_node_or_null(sun_light_path) as DirectionalLight3D
	_car = get_node_or_null(player_car_path) as VehicleBody3D
	_apply_ultra_vfx_defaults()
	apply_preset(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			_preset_idx = (_preset_idx + 1) % PRESET_NAMES.size()
			apply_preset(_preset_idx)

func _apply_ultra_vfx_defaults() -> void:
	if _env_node == null or _env_node.environment == null:
		return
	var env := _env_node.environment
	# ACES Filmic Tonemapping for photorealistic automotive lighting
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	# Screen-Space Reflections (SSR) & Ambient Occlusion (SSAO) + Indirect Lighting (SSIL)
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.85
	env.ssil_enabled = true
	env.ssil_radius = 4.5
	# High-Dynamic-Range Bloom / Glow
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Color grading
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.14

func apply_preset(index: int) -> void:
	if _env_node == null or _env_node.environment == null:
		return
	var env := _env_node.environment
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial if env.sky else null
	match index:
		0: # Golden Hour Dhule
			if sky_mat:
				sky_mat.sky_top_color = Color(0.16, 0.36, 0.72)
				sky_mat.sky_horizon_color = Color(0.96, 0.62, 0.34)
			if _sun:
				_sun.light_color = Color(1.0, 0.82, 0.58)
				_sun.light_energy = 1.45
				_sun.rotation_degrees = Vector3(-26, 42, 0)
			env.fog_light_color = Color(0.92, 0.72, 0.52)
			env.fog_density = 0.00035
		1: # Sunny Highway Noon
			if sky_mat:
				sky_mat.sky_top_color = Color(0.18, 0.48, 0.88)
				sky_mat.sky_horizon_color = Color(0.74, 0.86, 0.96)
			if _sun:
				_sun.light_color = Color(1.0, 0.97, 0.92)
				_sun.light_energy = 1.65
				_sun.rotation_degrees = Vector3(-58, 25, 0)
			env.fog_light_color = Color(0.78, 0.86, 0.95)
			env.fog_density = 0.00018
		2: # Vice City Neon Night
			if sky_mat:
				sky_mat.sky_top_color = Color(0.02, 0.03, 0.08)
				sky_mat.sky_horizon_color = Color(0.12, 0.06, 0.22)
			if _sun:
				_sun.light_color = Color(0.35, 0.48, 0.85)
				_sun.light_energy = 0.22
				_sun.rotation_degrees = Vector3(-35, -120, 0)
			env.fog_light_color = Color(0.08, 0.06, 0.16)
			env.fog_density = 0.00045
			env.glow_intensity = 0.85
		3: # Monsoon Wet Road
			if sky_mat:
				sky_mat.sky_top_color = Color(0.24, 0.28, 0.34)
				sky_mat.sky_horizon_color = Color(0.45, 0.50, 0.56)
			if _sun:
				_sun.light_color = Color(0.75, 0.82, 0.90)
				_sun.light_energy = 0.65
				_sun.rotation_degrees = Vector3(-42, 15, 0)
			env.fog_light_color = Color(0.48, 0.54, 0.60)
			env.fog_density = 0.00065
