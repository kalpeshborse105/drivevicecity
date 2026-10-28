extends VehicleBody3D
## Arcade drive feel + sedan/van customization (own meshes — no paid/ripped cars).

signal vehicle_changed(profile_name: String, paint_name: String)

const VehicleMeshBuilder = preload("res://scripts/vehicle_mesh_builder.gd")
const AssetKit = preload("res://scripts/asset_kit.gd")

@export var engine_force_value: float = 640.0
@export var brake_force_value: float = 35.0
@export var steer_limit: float = 0.55
@export var steer_speed: float = 5.5
@export var max_speed_kph: float = 145.0

const PAINTS: Array[Color] = [
	Color(0.85, 0.55, 0.12),
	Color(0.12, 0.35, 0.7),
	Color(0.82, 0.15, 0.12),
	Color(0.15, 0.55, 0.28),
	Color(0.92, 0.92, 0.9),
	Color(0.12, 0.12, 0.14),
	Color(0.55, 0.55, 0.58),
	Color(0.95, 0.75, 0.15),
	Color(0.55, 0.15, 0.55),
	Color(0.1, 0.55, 0.55),
]

const PAINT_NAMES: Array[String] = [
	"Saffron", "Blue", "Red", "Green", "White", "Black", "Silver",
	"Taxi Yellow", "Royal Purple", "Teal"
]

const KIT_NAMES: Array[String] = ["Stock", "Spoiler", "Roof Rack", "Sport"]
const RIM_NAMES: Array[String] = ["Steel", "Chrome", "Gold", "Black"]

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
var _kit_index: int = 0
var _rim_index: int = 0
var _body_mat: StandardMaterial3D
var _wheels: Array[VehicleWheel3D] = []
## Chase cam behind the rear; W = into the world (away from the player).
## +1 = Godot forward (−Z); kit meshes use NORMALIZE yaw PI so nose also faces −Z.
var _drive_sign: float = 1.0
var _look_yaw: float = 0.0
var _look_pitch: float = 0.12
var _look_dragging: bool = false
var _look_touch_id: int = -1
var _look_touch_last: Vector2 = Vector2.ZERO
var _orbit_return_t: float = 0.0


func _ready() -> void:
	_spawn = global_transform
	_wheels = [_fl, _fr, _rl, _rr]
	can_sleep = false
	sleeping = false
	freeze = false
	gravity_scale = 1.0
	linear_damp = 0.02
	angular_damp = 0.15
	collision_layer = 1
	collision_mask = 1
	_fix_wheel_meshes()
	_configure_wheels_base()
	_body_mat = VehicleMeshBuilder.mat(PAINTS[0], 0.42, 0.18)
	_apply_paint(0)
	_apply_profile(0)
	# Embedded editor Play often needs the game window focused for WASD
	call_deferred("_grab_play_focus")


func _grab_play_focus() -> void:
	var w := get_window()
	if w:
		w.grab_focus()
	get_viewport().gui_release_focus()


func _fix_wheel_meshes() -> void:
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
		w.wheel_radius = 0.38
		w.wheel_rest_length = 0.22
		w.suspension_stiffness = 45.0
		w.suspension_max_force = 15000.0
		w.damping_compression = 0.9
		w.damping_relaxation = 1.0
		w.wheel_friction_slip = 8.0
		w.use_as_traction = true
		w.use_as_steering = false
	_fl.use_as_steering = true
	_fr.use_as_steering = true
	_apply_rim_visuals()


func set_spawn(pos: Vector3, heading_xz: Vector2 = Vector2(0, -1)) -> void:
	var forward := Vector3(heading_xz.x, 0.0, heading_xz.y)
	if forward.length() < 0.01:
		forward = Vector3(0, 0, -1)
	forward = forward.normalized()
	var basis := Basis.looking_at(forward, Vector3.UP)
	# Sit low so wheels touch ground collision (y≈0) immediately
	var grounded := Vector3(pos.x, 0.42, pos.z)
	_spawn = Transform3D(basis, grounded)
	_reset_to_spawn()


func _drive_input() -> Dictionary:
	## Action map + raw keys (editor Play can miss InputMap until game view is focused).
	var throttle := Input.get_action_strength("accelerate")
	var brake_in := Input.get_action_strength("brake")
	var steer_input := Input.get_axis("steer_right", "steer_left")
	var handbrake := Input.is_action_pressed("handbrake")
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		throttle = maxf(throttle, 1.0)
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		brake_in = maxf(brake_in, 1.0)
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		steer_input = maxf(steer_input, 1.0)
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		steer_input = minf(steer_input, -1.0)
	if Input.is_physical_key_pressed(KEY_SPACE):
		handbrake = true
	return {"throttle": throttle, "brake": brake_in, "steer": steer_input, "handbrake": handbrake}


func _physics_process(delta: float) -> void:
	freeze = false
	sleeping = false
	if Input.is_action_just_pressed("reset_car"):
		_reset_to_spawn()
		return
	if Input.is_action_just_pressed("cycle_paint"):
		_apply_paint((_paint_index + 1) % PAINTS.size())
	if Input.is_action_just_pressed("cycle_vehicle"):
		_apply_profile((_profile_index + 1) % 7)

	var drive := _drive_input()
	var throttle: float = drive["throttle"]
	var brake_in: float = drive["brake"]
	var steer_input: float = drive["steer"]
	var handbrake: bool = drive["handbrake"]

	# Keep traction flags on every frame (scene overrides can clear them)
	for w in _wheels:
		if w:
			w.use_as_traction = true
	_fl.use_as_steering = true
	_fr.use_as_steering = true

	var speed := linear_velocity.length()
	var speed_kph := speed * 3.6
	var top := clampf(1.05 - (speed_kph / max_speed_kph), 0.4, 1.0)
	# Godot VehicleBody3D forward = -Z. Kit nose also -Z. W = away from chase cam.
	engine_force = throttle * engine_force_value * top * _drive_sign
	brake = 0.0

	var forward_dir := -global_transform.basis.z * _drive_sign
	if brake_in > 0.0:
		var going_forward := linear_velocity.dot(forward_dir) > 0.35
		if speed_kph < 22.0 and not going_forward:
			# Reverse: strong push so S backs toward the chase cam clearly
			engine_force = -brake_in * engine_force_value * 1.35 * _drive_sign
		else:
			brake = brake_in * brake_force_value

	if handbrake:
		brake = maxf(brake, brake_force_value * 1.35)
		_rl.wheel_friction_slip = 1.8
		_rr.wheel_friction_slip = 1.8
	else:
		for w in _wheels:
			w.wheel_friction_slip = 8.0

	_steer_target = steer_input * steer_limit
	var steer_scale := clampf(1.0 - speed_kph / 160.0, 0.4, 1.0)
	steering = move_toward(steering, _steer_target * steer_scale, steer_speed * delta)

	_update_chase_camera(delta, speed_kph)


func speed_kph() -> float:
	return linear_velocity.length() * 3.6


func paint_name() -> String:
	return PAINT_NAMES[_paint_index]


func profile_name() -> String:
	match _profile_index:
		1:
			return "Delivery Van"
		2:
			return "Carnival"
		3:
			return "Tata Safari"
		4:
			return "Autorickshaw"
		5:
			return "Bus"
		6:
			return "Cargo Truck"
		_:
			return "Sedan"


func kit_name() -> String:
	return KIT_NAMES[_kit_index]


func rim_name() -> String:
	return RIM_NAMES[_rim_index]


func paint_index() -> int:
	return _paint_index


func profile_index() -> int:
	return _profile_index


func kit_index() -> int:
	return _kit_index


func rim_index() -> int:
	return _rim_index


func apply_paint_index(index: int) -> void:
	_apply_paint(clampi(index, 0, PAINTS.size() - 1))


func apply_profile_index(index: int) -> void:
	_apply_profile(clampi(index, 0, 6))


func apply_kit_index(index: int) -> void:
	_kit_index = clampi(index, 0, KIT_NAMES.size() - 1)
	_rebuild_visuals()
	_emit_vehicle()


func apply_rim_index(index: int) -> void:
	_rim_index = clampi(index, 0, RIM_NAMES.size() - 1)
	_apply_rim_visuals()
	_emit_vehicle()


func _emit_vehicle() -> void:
	vehicle_changed.emit(profile_name(), "%s · %s · %s" % [paint_name(), kit_name(), rim_name()])


func _apply_paint(index: int) -> void:
	_paint_index = index
	_body_mat.albedo_color = PAINTS[_paint_index]
	_rebuild_visuals()
	_emit_vehicle()


func _apply_profile(index: int) -> void:
	_profile_index = index
	# Clear residual motion so V / garage swaps don't fling or clip
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	engine_force = 0.0
	brake = brake_force_value
	steering = 0.0
	match _profile_index:
		1:
			mass = 1250.0
			engine_force_value = 480.0
			max_speed_kph = 120.0
			steer_limit = 0.48
			_set_wheel_base(1.5, 0.92)
		2:
			mass = 1400.0
			engine_force_value = 500.0
			max_speed_kph = 130.0
			steer_limit = 0.5
			_set_wheel_base(1.55, 0.95)
		3:
			mass = 1600.0
			engine_force_value = 540.0
			max_speed_kph = 135.0
			steer_limit = 0.48
			_set_wheel_base(1.55, 0.95)
		4:
			mass = 700.0
			engine_force_value = 380.0
			max_speed_kph = 85.0
			steer_limit = 0.6
			_set_wheel_base(1.0, 0.7)
		5:
			mass = 4200.0
			engine_force_value = 420.0
			max_speed_kph = 95.0
			steer_limit = 0.4
			_set_wheel_base(2.2, 1.15)
		6:
			mass = 3800.0
			engine_force_value = 460.0
			max_speed_kph = 100.0
			steer_limit = 0.42
			_set_wheel_base(2.0, 1.1)
		_:
			mass = 950.0
			engine_force_value = 640.0
			max_speed_kph = 145.0
			steer_limit = 0.55
			_set_wheel_base(1.32, 0.82)
	_configure_wheels_base()
	_rebuild_visuals()
	_emit_vehicle()


func _set_wheel_meshes_visible(v: bool) -> void:
	for w in _wheels:
		if w == null:
			continue
		for child in w.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).visible = v


func _rebuild_visuals() -> void:
	if _visual_root == null or _body_mat == null:
		return
	var col_size := Vector3(1.9, 1.2, 4.4)
	var kit_key := ""
	match _profile_index:
		2:
			kit_key = "carnival"
		3:
			kit_key = "safari"
		4:
			kit_key = "autorickshaw"
		5:
			kit_key = "bus"
		6:
			kit_key = "truck"
	var path := AssetKit.vehicle_path(kit_key) if kit_key != "" else ""
	if path != "" and AssetKit.exists(path):
		VehicleMeshBuilder.clear_children(_visual_root)
		# Normalized: real-world length, longest axis on Z, nose toward -Z, bottom at 0
		var n := AssetKit.normalized(path)
		if n:
			_visual_root.add_child(n)
			_tint_kit_meshes(n, _body_mat.albedo_color)
			var aabb := AssetKit.mesh_aabb(n)
			# At suspension rest the chassis origin sits ~0.24 m above ground
			# (wheel y 0.36 − rest 0.22 − radius 0.38) → drop mesh so tyres touch road.
			n.position = Vector3(0, -0.22, 0)
			col_size = Vector3(aabb.size.x, aabb.size.y, aabb.size.z)
			_set_wheel_meshes_visible(false)
	elif _profile_index == 1:
		col_size = VehicleMeshBuilder.build_van(_visual_root, _body_mat, _kit_index)
		_set_wheel_meshes_visible(true)
	else:
		col_size = VehicleMeshBuilder.build_sedan(_visual_root, _body_mat, _kit_index)
		_set_wheel_meshes_visible(true)
	var shape := _body_shape.shape as BoxShape3D
	if shape == null:
		shape = BoxShape3D.new()
		_body_shape.shape = shape
	shape.size = Vector3(col_size.x * 0.88, maxf(col_size.y * 0.5, 0.7), col_size.z * 0.88)
	_body_shape.position = Vector3(0, 0.72, 0)


func _tint_kit_meshes(root: Node, paint: Color) -> void:
	## Paint tab actually changes kit GLB body colour (not fake UI).
	for child in root.get_children():
		_tint_kit_meshes(child, paint)
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		if mi.mesh == null:
			return
		for si in mi.mesh.get_surface_count():
			var base: Material = mi.get_active_material(si)
			var sm := StandardMaterial3D.new()
			if base is StandardMaterial3D:
				sm = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
			elif base != null:
				sm.albedo_color = paint
			else:
				sm.albedo_color = paint
				sm.roughness = 0.45
			# Keep dark glass / rubber; tint body-like surfaces
			var c := sm.albedo_color
			var lum := c.r * 0.3 + c.g * 0.5 + c.b * 0.2
			if lum > 0.12 and c.a > 0.9:
				sm.albedo_color = paint.lerp(c, 0.25)
			mi.set_surface_override_material(si, sm)


func _apply_rim_visuals() -> void:
	var colors: Array[Color] = [
		Color(0.7, 0.7, 0.72),
		Color(0.85, 0.85, 0.9),
		Color(0.85, 0.65, 0.15),
		Color(0.12, 0.12, 0.14),
	]
	var c: Color = colors[_rim_index]
	for w in _wheels:
		if w == null:
			continue
		var rim_n := w.get_node_or_null("Rim") as MeshInstance3D
		if rim_n == null:
			continue
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = 0.85 if _rim_index != 3 else 0.2
		m.roughness = 0.3 if _rim_index != 3 else 0.7
		rim_n.material_override = m


func _set_wheel_base(half_length: float, half_width: float) -> void:
	## Godot VehicleBody3D forward is -Z → front axle at negative Z.
	var y := 0.36
	_fl.position = Vector3(half_width, y, -half_length)
	_fr.position = Vector3(-half_width, y, -half_length)
	_rl.position = Vector3(half_width, y, half_length)
	_rr.position = Vector3(-half_width, y, half_length)


func _reset_to_spawn() -> void:
	sleeping = false
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = _spawn
	engine_force = 0.0
	brake = 0.0
	steering = 0.0
	_look_yaw = 0.0
	_look_pitch = 0.12
	_orbit_return_t = 0.0


func _unhandled_input(event: InputEvent) -> void:
	## Mouse / touch orbit — works on desktop and Android (drag empty game view).
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_look_dragging = mb.pressed
			if mb.pressed:
				_orbit_return_t = 0.0
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not _is_pointer_over_ui(mb.position):
			# Left-drag also orbits when not on HUD controls (mobile-friendly).
			_look_dragging = true
			_orbit_return_t = 0.0
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if _look_touch_id < 0:
				_look_dragging = false
	elif event is InputEventMouseMotion and _look_dragging:
		var mm := event as InputEventMouseMotion
		_apply_look_delta(mm.relative)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and not _is_pointer_over_ui(st.position):
			_look_touch_id = st.index
			_look_touch_last = st.position
			_look_dragging = true
			_orbit_return_t = 0.0
		elif not st.pressed and st.index == _look_touch_id:
			_look_touch_id = -1
			_look_dragging = false
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _look_touch_id or (_look_touch_id < 0 and not _is_pointer_over_ui(sd.position)):
			_apply_look_delta(sd.relative)
			_orbit_return_t = 0.0


func _is_pointer_over_ui(screen_pos: Vector2) -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	# Allow orbit on the root game canvas; block real buttons/panels.
	var n: Node = hovered
	while n:
		if n is BaseButton or n is LineEdit or n is TextEdit or n is Slider or n is TabBar:
			return true
		if n is PanelContainer and (n as Control).visible:
			return true
		n = n.get_parent()
	return false


func _apply_look_delta(relative: Vector2) -> void:
	var sens := 0.0055
	_look_yaw -= relative.x * sens
	_look_pitch = clampf(_look_pitch + relative.y * sens, -0.35, 0.55)
	_orbit_return_t = 0.0


func _update_chase_camera(delta: float, speed_kph: float) -> void:
	if _camera == null or _camera_pivot == null:
		return
	# Slowly recenter after the player stops orbiting
	if not _look_dragging:
		_orbit_return_t += delta
		if _orbit_return_t > 2.2:
			_look_yaw = lerp_angle(_look_yaw, 0.0, 2.5 * delta)
			_look_pitch = lerpf(_look_pitch, 0.12, 2.5 * delta)
	var pull := clampf(speed_kph / 120.0, 0.0, 1.0)
	var dist := 8.0 + pull * 2.8
	var height := 3.0 + pull * 0.45
	# Behind the car: local +Z = rear when drive_sign=+1 (W = −Z = away from cam).
	# RMB/drag orbits 360° so you can swing around and see the nose.
	var yaw := _look_yaw
	var pitch := _look_pitch
	var back := _drive_sign
	var offset := Vector3(
		sin(yaw) * dist * cos(pitch),
		height + sin(pitch) * dist * 0.85,
		cos(yaw) * dist * cos(pitch) * back
	)
	# Pull camera in if a building/wall sits between car and chase point (crash into home)
	var eye := global_position + Vector3(0, 1.35, 0)
	var desired := global_position + global_transform.basis * offset
	var space := get_world_3d().direct_space_state
	if space:
		var q := PhysicsRayQueryParameters3D.create(eye, desired)
		q.exclude = [get_rid()]
		q.collision_mask = 1
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit["position"]
			var dir := desired - eye
			var safe_len := maxf(eye.distance_to(hit_pos) - 0.55, 2.2)
			desired = eye + dir.normalized() * safe_len
	_camera_pivot.global_position = desired
	var look_ahead := global_position + (-global_transform.basis.z * _drive_sign * 10.0) + Vector3.UP * 1.1
	if absf(_look_yaw) > 0.55:
		look_ahead = global_position + Vector3.UP * 1.2
	_camera.look_at(look_ahead, Vector3.UP)
