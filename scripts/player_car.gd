extends VehicleBody3D
## Driveable car — fixed tire axis/grip + paint + sedan/van.

signal vehicle_changed(profile_name: String, paint_name: String)

const VehicleMeshBuilder = preload("res://scripts/vehicle_mesh_builder.gd")

@export var engine_force_value: float = 140.0
@export var brake_force_value: float = 18.0
@export var steer_limit: float = 0.42
@export var steer_speed: float = 3.2
@export var max_speed_kph: float = 105.0

const PAINTS: Array[Color] = [
	Color(0.85, 0.55, 0.12),
	Color(0.12, 0.35, 0.7),
	Color(0.82, 0.15, 0.12),
	Color(0.15, 0.55, 0.28),
	Color(0.92, 0.92, 0.9),
	Color(0.12, 0.12, 0.14),
	Color(0.55, 0.55, 0.58),
]

const PAINT_NAMES: Array[String] = [
	"Saffron", "Blue", "Red", "Green", "White", "Black", "Silver"
]

@onready var _fl: VehicleWheel3D = $WheelFL
@onready var _fr: VehicleWheel3D = $WheelFR
@onready var _rl: VehicleWheel3D = $WheelRL
@onready var _rr: VehicleWheel3D = $WheelRR
@onready var _visual_root: Node3D = $VisualRoot
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _body_shape: CollisionShape3D = $CollisionShape3D

var _spawn: Transform3D
var _steer_target: float = 0.0
var _paint_index: int = 0
var _profile_index: int = 0
var _body_mat: StandardMaterial3D
var _wheels: Array[VehicleWheel3D] = []


func _ready() -> void:
	_spawn = global_transform
	_wheels = [_fl, _fr, _rl, _rr]
	_fix_wheel_meshes()
	_configure_wheels_base()
	_body_mat = VehicleMeshBuilder.mat(PAINTS[0], 0.42, 0.18)
	_apply_paint(0)
	_apply_profile(0)


func _fix_wheel_meshes() -> void:
	# VehicleWheel3D rolls around local X — cylinder height must lie on X.
	var wheel_xf := Transform3D(Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5)), Vector3.ZERO)
	var rim_xf := Transform3D(Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5)).scaled(Vector3(0.55, 0.55, 0.55)), Vector3.ZERO)
	for w in _wheels:
		if w == null:
			continue
		var mesh_n := w.get_node_or_null("Mesh") as MeshInstance3D
		var rim_n := w.get_node_or_null("Rim") as MeshInstance3D
		if mesh_n:
			mesh_n.transform = wheel_xf
		if rim_n:
			rim_n.transform = rim_xf


func _configure_wheels_base() -> void:
	for w in _wheels:
		w.wheel_radius = 0.36
		w.wheel_rest_length = 0.08
		w.suspension_stiffness = 40.0
		w.suspension_max_force = 6000.0
		w.damping_compression = 0.85
		w.damping_relaxation = 0.95
		w.wheel_friction_slip = 10.5
		w.use_as_traction = false
		w.use_as_steering = false
	# RWD + front steer = less fake wheelspin than 4WD full force
	_rl.use_as_traction = true
	_rr.use_as_traction = true
	_fl.use_as_steering = true
	_fr.use_as_steering = true


func set_spawn(pos: Vector3, heading_xz: Vector2 = Vector2(0, -1)) -> void:
	var forward := Vector3(heading_xz.x, 0.0, heading_xz.y)
	if forward.length() < 0.01:
		forward = Vector3(0, 0, -1)
	forward = forward.normalized()
	var basis := Basis.looking_at(forward, Vector3.UP)
	# Sit so tires touch ground (radius ~0.36)
	var grounded := Vector3(pos.x, 0.42, pos.z)
	_spawn = Transform3D(basis, grounded)
	_reset_to_spawn()


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset_car"):
		_reset_to_spawn()
		return
	if Input.is_action_just_pressed("cycle_paint"):
		_apply_paint((_paint_index + 1) % PAINTS.size())
	if Input.is_action_just_pressed("cycle_vehicle"):
		_apply_profile(1 - _profile_index)

	var throttle := Input.get_action_strength("accelerate")
	var brake_in := Input.get_action_strength("brake")
	var steer_input := Input.get_axis("steer_right", "steer_left")
	var handbrake := Input.is_action_pressed("handbrake")

	var speed := linear_velocity.length()
	var speed_kph := speed * 3.6
	# Soft launch: low torque at 0 km/h stops tire burnout
	var launch := clampf(speed_kph / 18.0, 0.28, 1.0)
	var top := clampf(1.0 - (speed_kph / max_speed_kph), 0.2, 1.0)

	engine_force = throttle * engine_force_value * launch * top
	brake = 0.0

	if brake_in > 0.0:
		var going_forward := linear_velocity.dot(-global_transform.basis.z) > 0.4
		if speed_kph < 6.0 and not going_forward:
			engine_force = -brake_in * engine_force_value * 0.35
		else:
			brake = brake_in * brake_force_value

	if handbrake:
		brake = maxf(brake, brake_force_value * 1.2)
		_rl.wheel_friction_slip = 2.2
		_rr.wheel_friction_slip = 2.2
	else:
		_rl.wheel_friction_slip = 10.5
		_rr.wheel_friction_slip = 10.5
		_fl.wheel_friction_slip = 9.5
		_fr.wheel_friction_slip = 9.5

	_steer_target = steer_input * steer_limit
	# Less steering at speed
	var steer_scale := clampf(1.0 - speed_kph / 140.0, 0.35, 1.0)
	steering = move_toward(steering, _steer_target * steer_scale, steer_speed * delta)

	if _camera and _camera_pivot:
		var pull := clampf(speed_kph / 110.0, 0.0, 1.0)
		_camera_pivot.position = Vector3(0.0, 3.0 + pull * 0.5, 8.2 + pull * 3.0)
		var look := global_position + (-global_transform.basis.z * 14.0) + Vector3.UP * 1.1
		_camera.look_at(look)


func speed_kph() -> float:
	return linear_velocity.length() * 3.6


func paint_name() -> String:
	return PAINT_NAMES[_paint_index]


func profile_name() -> String:
	return "Sedan" if _profile_index == 0 else "Delivery Van"


func paint_index() -> int:
	return _paint_index


func profile_index() -> int:
	return _profile_index


func apply_paint_index(index: int) -> void:
	_apply_paint(clampi(index, 0, PAINTS.size() - 1))


func apply_profile_index(index: int) -> void:
	_apply_profile(clampi(index, 0, 1))


func _apply_paint(index: int) -> void:
	_paint_index = index
	_body_mat.albedo_color = PAINTS[_paint_index]
	_rebuild_visuals()
	vehicle_changed.emit(profile_name(), paint_name())


func _apply_profile(index: int) -> void:
	_profile_index = index
	if _profile_index == 0:
		mass = 1100.0
		engine_force_value = 140.0
		max_speed_kph = 105.0
		steer_limit = 0.42
		_set_wheel_base(1.32, 0.82)
	else:
		mass = 1450.0
		engine_force_value = 160.0
		max_speed_kph = 90.0
		steer_limit = 0.36
		_set_wheel_base(1.5, 0.92)
	_configure_wheels_base()
	_rebuild_visuals()
	vehicle_changed.emit(profile_name(), paint_name())


func _rebuild_visuals() -> void:
	if _visual_root == null or _body_mat == null:
		return
	var col_size: Vector3
	if _profile_index == 0:
		col_size = VehicleMeshBuilder.build_sedan(_visual_root, _body_mat)
	else:
		col_size = VehicleMeshBuilder.build_van(_visual_root, _body_mat)
	var shape := _body_shape.shape as BoxShape3D
	if shape == null:
		shape = BoxShape3D.new()
		_body_shape.shape = shape
	# Keep chassis collider above tire contact patch
	shape.size = Vector3(col_size.x * 0.92, col_size.y * 0.7, col_size.z * 0.92)
	_body_shape.position = Vector3(0, 0.55 + col_size.y * 0.15, 0)


func _set_wheel_base(half_length: float, half_width: float) -> void:
	var y := 0.36
	_fl.position = Vector3(half_width, y, half_length)
	_fr.position = Vector3(-half_width, y, half_length)
	_rl.position = Vector3(half_width, y, -half_length)
	_rr.position = Vector3(-half_width, y, -half_length)


func _reset_to_spawn() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = _spawn
	engine_force = 0.0
	brake = 0.0
	steering = 0.0
