extends SubViewportContainer
## Center-stage car preview for Home (G).
## Visuals only — never touches VehicleBody3D physics.

const VehicleMeshBuilder = preload("res://scripts/vehicle_mesh_builder.gd")
const AssetKit = preload("res://scripts/asset_kit.gd")

var _viewport: SubViewport
var _stage: Node3D
var _car_root: Node3D
var _cam_pivot: Node3D
var _camera: Camera3D
var _body_mat: StandardMaterial3D
var _yaw: float = 0.55
var _yaw_speed: float = 0.45
var _profile: int = 0
var _paint: int = 0
var _kit: int = 0
var _rim: int = 0
var _focus: String = "full"
var _cam_pos := Vector3(0, 1.45, 6.4)
var _cam_look := Vector3(0, 0.75, 0)
var _cam_pos_target := Vector3(0, 1.45, 6.4)
var _cam_look_target := Vector3(0, 0.75, 0)


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(520, 320)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport = SubViewport.new()
	_viewport.name = "PreviewViewport"
	_viewport.size = Vector2i(720, 420)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.own_world_3d = true
	add_child(_viewport)
	_stage = Node3D.new()
	_stage.name = "Stage"
	_viewport.add_child(_stage)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.14, 0.16, 0.18)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.82)
	e.ambient_light_energy = 0.9
	env.environment = e
	_stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 28, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	_stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -120, 0)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	_stage.add_child(fill)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 14)
	floor_mi.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.2, 0.21, 0.22)
	floor_mat.roughness = 0.92
	floor_mi.material_override = floor_mat
	floor_mi.position.y = -0.02
	_stage.add_child(floor_mi)
	_cam_pivot = Node3D.new()
	_cam_pivot.name = "CamPivot"
	_stage.add_child(_cam_pivot)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 34.0
	_camera.position = _cam_pos
	_cam_pivot.add_child(_camera)
	_car_root = Node3D.new()
	_car_root.name = "PreviewCar"
	_stage.add_child(_car_root)
	_body_mat = VehicleMeshBuilder.mat(Color(0.92, 0.92, 0.9), 0.42, 0.18)
	rebuild(8, 0, 0, 0)
	focus_part("full")


func _process(delta: float) -> void:
	if not visible or not is_visible_in_tree():
		return
	if _focus == "full":
		_yaw += delta * _yaw_speed
	_cam_pivot.rotation.y = _yaw
	_cam_pos = _cam_pos.lerp(_cam_pos_target, clampf(delta * 5.0, 0.0, 1.0))
	_cam_look = _cam_look.lerp(_cam_look_target, clampf(delta * 5.0, 0.0, 1.0))
	_camera.position = _cam_pos
	_camera.look_at(_cam_pivot.to_global(_cam_look), Vector3.UP)


func rebuild(profile: int, paint: int, kit: int, rim: int) -> void:
	_profile = profile
	_paint = paint
	_kit = kit
	_rim = rim
	if _car_root == null or _body_mat == null:
		return
	var paints: Array = [
		Color(0.92, 0.92, 0.9), Color(0.12, 0.12, 0.14), Color(0.72, 0.73, 0.75),
		Color(0.42, 0.44, 0.46), Color(0.72, 0.12, 0.1), Color(0.12, 0.28, 0.62),
		Color(0.08, 0.14, 0.32), Color(0.12, 0.38, 0.22), Color(0.38, 0.24, 0.14),
		Color(0.86, 0.72, 0.12),
	]
	_body_mat.albedo_color = paints[clampi(paint, 0, paints.size() - 1)]
	VehicleMeshBuilder.clear_children(_car_root)
	var kit_key := ""
	match profile:
		2: kit_key = "carnival"
		3: kit_key = "safari"
		4: kit_key = "autorickshaw"
		5: kit_key = "bus"
		6: kit_key = "truck"
		7: kit_key = "camry"
		8: kit_key = "premium_sedan"
	var path := AssetKit.vehicle_path(kit_key) if kit_key != "" else ""
	if path != "" and AssetKit.exists(path):
		var n := AssetKit.normalized(path)
		if n:
			_car_root.add_child(n)
			_tint(n, _body_mat.albedo_color)
			n.position = Vector3(0, 0.02, 0)
	elif profile == 1:
		VehicleMeshBuilder.build_van(_car_root, _body_mat, kit)
		_car_root.rotation.y = PI
	else:
		VehicleMeshBuilder.build_sedan(_car_root, _body_mat, kit)
		_car_root.rotation.y = PI
	_add_preview_rims(rim)
	# Keep current focus so kit/rim clicks re-zoom after rebuild.
	focus_part(_focus)


func focus_part(part: String) -> void:
	_focus = part
	match part:
		"spoiler":
			_yaw_speed = 0.12
			_cam_pos_target = Vector3(0.35, 1.35, 3.2)
			_cam_look_target = Vector3(0, 1.15, -1.6)
		"roof":
			_yaw_speed = 0.12
			_cam_pos_target = Vector3(0.2, 2.6, 3.6)
			_cam_look_target = Vector3(0, 1.55, -0.1)
		"sport":
			_yaw_speed = 0.1
			_cam_pos_target = Vector3(2.6, 0.7, 1.2)
			_cam_look_target = Vector3(0, 0.45, 0)
		"rim":
			_yaw_speed = 0.08
			_cam_pos_target = Vector3(2.1, 0.55, 1.5)
			_cam_look_target = Vector3(0.7, 0.38, 1.2)
		"paint":
			_yaw_speed = 0.35
			_cam_pos_target = Vector3(0, 1.35, 5.4)
			_cam_look_target = Vector3(0, 0.8, 0)
		_:
			_focus = "full"
			_yaw_speed = 0.45
			_cam_pos_target = Vector3(0, 1.45, 6.4)
			_cam_look_target = Vector3(0, 0.75, 0)


func sync_from_car(car: Node) -> void:
	if car == null:
		return
	var profile := int(car.call("profile_index")) if car.has_method("profile_index") else 0
	var paint := int(car.call("paint_index")) if car.has_method("paint_index") else 0
	var kit := int(car.call("kit_index")) if car.has_method("kit_index") else 0
	var rim := int(car.call("rim_index")) if car.has_method("rim_index") else 0
	rebuild(profile, paint, kit, rim)


func _tint(root: Node, paint: Color) -> void:
	for child in root.get_children():
		_tint(child, paint)
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		if mi.mesh == null:
			return
		for si in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(si)
			if mat is StandardMaterial3D:
				var copy := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				var c := copy.albedo_color
				if c.r > 0.35 and c.g > 0.35 and c.b > 0.35:
					copy.albedo_color = paint
				mi.set_surface_override_material(si, copy)


func _add_preview_rims(rim: int) -> void:
	var colors: Array[Color] = [
		Color(0.55, 0.55, 0.58), Color(0.85, 0.85, 0.9),
		Color(0.82, 0.68, 0.2), Color(0.08, 0.08, 0.1),
	]
	var c: Color = colors[clampi(rim, 0, colors.size() - 1)]
	var positions := [
		Vector3(0.82, 0.38, 1.35), Vector3(-0.82, 0.38, 1.35),
		Vector3(0.82, 0.38, -1.35), Vector3(-0.82, 0.38, -1.35),
	]
	for p in positions:
		var tire := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.38
		cyl.bottom_radius = 0.38
		cyl.height = 0.22
		tire.mesh = cyl
		tire.rotation.z = PI * 0.5
		tire.position = p
		var rubber := StandardMaterial3D.new()
		rubber.albedo_color = Color(0.08, 0.08, 0.09)
		rubber.roughness = 0.95
		tire.material_override = rubber
		_car_root.add_child(tire)
		var hub := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.18
		disc.bottom_radius = 0.18
		disc.height = 0.24
		hub.mesh = disc
		hub.rotation.z = PI * 0.5
		hub.position = p
		var hub_mat := StandardMaterial3D.new()
		hub_mat.albedo_color = c
		hub_mat.metallic = 0.8
		hub_mat.roughness = 0.35
		hub.material_override = hub_mat
		_car_root.add_child(hub)
