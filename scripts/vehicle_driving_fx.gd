extends Node3D
## Performance-conscious driving VFX — tire smoke, skid marks, lights, collision flash.
## Does not change VehicleBody3D physics. Parent must be the player VehicleBody3D.
## Formula inspired by open racing kits (Kenney CC0 patterns); original implementation.

@export var enabled: bool = true
@export var tire_smoke: bool = true
@export var skid_marks: bool = true
@export var vehicle_lights: bool = true
@export var collision_fx: bool = true

var _car: VehicleBody3D
var _smoke_l: GPUParticles3D
var _smoke_r: GPUParticles3D
var _head_l: SpotLight3D
var _head_r: SpotLight3D
var _brake_l: OmniLight3D
var _brake_r: OmniLight3D
var _skid_cooldown: float = 0.0
var _impact_cd: float = 0.0
var _last_vel: Vector3 = Vector3.ZERO
var _night: bool = false


func _ready() -> void:
	_car = get_parent() as VehicleBody3D
	_apply_quality_from_settings()
	_build_smoke()
	_build_lights()
	var gs := get_node_or_null("/root/GameSettings")
	if gs and gs.has_signal("settings_changed"):
		gs.settings_changed.connect(_apply_quality_from_settings)
	if _car:
		_car.body_entered.connect(_on_body_entered)
		# Also catch StaticBody hits via contact monitor
		_car.contact_monitor = true
		_car.max_contacts_reported = 4


func _apply_quality_from_settings() -> void:
	var gs := get_node_or_null("/root/GameSettings")
	if gs == null:
		return
	if gs.get("fx_quality") != null:
		var q: int = int(gs.fx_quality)
		# 0=off/low Android, 1=medium, 2=high
		enabled = q > 0
		tire_smoke = q >= 1
		skid_marks = q >= 2
		vehicle_lights = q >= 1
		collision_fx = q >= 1
		if _smoke_l:
			_smoke_l.amount = 24 if q >= 2 else 12
			_smoke_r.amount = 24 if q >= 2 else 12
			_smoke_l.emitting = false
			_smoke_r.emitting = false
		if _head_l:
			_head_l.visible = vehicle_lights
			_head_r.visible = vehicle_lights


func set_night_mode(night: bool) -> void:
	_night = night
	_update_headlights(0.0, false)


func _build_smoke() -> void:
	_smoke_l = _make_smoke("TireSmokeL", Vector3(0.75, 0.2, -1.3))
	_smoke_r = _make_smoke("TireSmokeR", Vector3(-0.75, 0.2, -1.3))


func _make_smoke(node_name: String, pos: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = node_name
	p.position = pos
	p.emitting = false
	p.amount = 18
	p.lifetime = 0.55
	p.explosiveness = 0.05
	p.randomness = 0.4
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 3, 4))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, -0.2)
	mat.spread = 18.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.4
	mat.gravity = Vector3(0, 0.6, 0)
	mat.scale_min = 0.25
	mat.scale_max = 0.7
	mat.color = Color(0.55, 0.55, 0.55, 0.45)
	p.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.5, 0.5, 0.5, 0.35)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = sm
	p.draw_pass_1 = mesh
	add_child(p)
	return p


func _build_lights() -> void:
	_head_l = _spot("HeadL", Vector3(0.55, 0.55, 2.15), Color(1.0, 0.95, 0.85), 0.0)
	_head_r = _spot("HeadR", Vector3(-0.55, 0.55, 2.15), Color(1.0, 0.95, 0.85), 0.0)
	_brake_l = _omni("BrakeL", Vector3(0.55, 0.55, -2.15), Color(1.0, 0.12, 0.08), 0.0)
	_brake_r = _omni("BrakeR", Vector3(-0.55, 0.55, -2.15), Color(1.0, 0.12, 0.08), 0.0)


func _spot(n: String, pos: Vector3, col: Color, energy: float) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.name = n
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.spot_range = 28.0
	l.spot_angle = 35.0
	l.shadow_enabled = false
	# Aim along MODEL_FRONT (+Z)
	l.rotation_degrees = Vector3(0, 180, 0)
	add_child(l)
	return l


func _omni(n: String, pos: Vector3, col: Color, energy: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = n
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = 3.5
	l.shadow_enabled = false
	add_child(l)
	return l


func _physics_process(delta: float) -> void:
	if not enabled or _car == null:
		return
	_skid_cooldown = maxf(_skid_cooldown - delta, 0.0)
	_impact_cd = maxf(_impact_cd - delta, 0.0)
	var speed := _car.linear_velocity.length()
	var speed_kph := speed * 3.6
	var forward := _car.global_transform.basis.z
	var lat := _car.linear_velocity.dot(_car.global_transform.basis.x)
	var slip := absf(lat)
	var braking := _car.brake > 0.4 or Input.is_action_pressed("brake") or Input.is_physical_key_pressed(KEY_S)
	var handbrake := Input.is_action_pressed("handbrake") or Input.is_physical_key_pressed(KEY_SPACE)
	var skidding := (slip > 3.2 and speed_kph > 18.0) or (handbrake and speed_kph > 12.0)

	if tire_smoke:
		var emit := skidding or (braking and speed_kph > 35.0 and absf(_car.engine_force) < 50.0)
		_smoke_l.emitting = emit
		_smoke_r.emitting = emit

	if skid_marks and skidding and _skid_cooldown <= 0.0 and speed_kph > 15.0:
		_spawn_skid_decal()
		_skid_cooldown = 0.12

	_update_headlights(speed_kph, braking)

	# Soft collision from sudden velocity change (complements body_entered)
	var dv := (_car.linear_velocity - _last_vel).length()
	if collision_fx and dv > 8.0 and _impact_cd <= 0.0 and speed_kph > 5.0:
		_flash_collision()
		_impact_cd = 0.45
	_last_vel = _car.linear_velocity
	# silence unused
	var _f := forward


func _update_headlights(speed_kph: float, braking: bool) -> void:
	if not vehicle_lights:
		return
	var head_e := 2.4 if _night else (0.35 if speed_kph > 1.0 else 0.0)
	_head_l.light_energy = head_e
	_head_r.light_energy = head_e
	var brake_e := 2.8 if braking else (0.35 if _night else 0.0)
	_brake_l.light_energy = brake_e
	_brake_r.light_energy = brake_e


func _spawn_skid_decal() -> void:
	## Short-lived dark strip under rear axle (no Decal dependency on mobile GLES).
	var mark := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.02, 0.85)
	mark.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.09, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark.material_override = m
	var gp := _car.global_position + Vector3(0, 0.04, 0) - _car.global_transform.basis.z * 1.2
	mark.global_position = gp
	mark.global_rotation.y = _car.global_rotation.y
	get_tree().current_scene.add_child(mark)
	var tw := create_tween()
	tw.tween_interval(2.8)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.2)
	tw.tween_callback(mark.queue_free)


func _on_body_entered(_body: Node) -> void:
	if not collision_fx or _impact_cd > 0.0:
		return
	_flash_collision()
	_impact_cd = 0.4


func _flash_collision() -> void:
	## Brief camera-local omni flash + optional audio cue via car.
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.85, 0.55)
	flash.light_energy = 4.0
	flash.omni_range = 6.0
	flash.position = Vector3(0, 1.0, 0)
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.18)
	tw.tween_callback(flash.queue_free)
	if _car and _car.has_method("play_collision_sound"):
		_car.play_collision_sound()
