extends Node3D

const MAP := "res://assets/maps/dhule_roads_game.json"
const X0 := -980.0
const X1 := -380.0
const Z0 := 700.0
const Z1 := 1120.0

var _car: VehicleBody3D
var _cam: Camera3D
var _aerial := false


func _ready() -> void:
	_car = $PlayerCar
	_cam = $ChaseCam
	_ground()
	_roads()
	_colliders($Architecture)
	_spawn()
	_hud()


func _process(_delta: float) -> void:
	if _car == null or _cam == null:
		return
	var car_cam := _car.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if car_cam:
		car_cam.current = false
	_cam.current = true
	_place_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_aerial = not _aerial


func _place_camera() -> void:
	if _aerial:
		_cam.global_position = Vector3(-690.0, 90.0, 820.0)
		_cam.look_at(Vector3(-690.0, 0.0, 920.0), Vector3.UP)
		return
	var eye := _car.global_position + Vector3(0, 1.35, 0)
	var back := _car.global_transform.basis.z
	var desired := _car.global_position - back * 7.5 + Vector3(0, 2.8, 0)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(eye, desired)
	query.exclude = [_car.get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var dir := desired - eye
		var reach := eye.distance_to(hit.position) - 0.28
		if reach < 0.15:
			reach = 0.15
		if reach > eye.distance_to(desired):
			reach = eye.distance_to(desired)
		desired = eye + dir.normalized() * reach
	_cam.global_position = desired
	_cam.look_at(_car.global_position + Vector3(0, 1.05, 0) + back * 4.0, Vector3.UP)


func _spawn() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	var spawn: Dictionary = parsed["spawn"]
	_car.set_spawn(
		Vector3(float(spawn["x"]), 0.42, float(spawn["z"])),
		Vector2(float(spawn["hx"]), float(spawn["hz"]))
	)


func _ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1100, 0.4, 900)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = Vector3(-680, -0.2, 910)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.48, 0.28)
	mat.roughness = 0.95
	inst.material_override = mat
	body.add_child(inst)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
	shape.shape = box
	shape.position = inst.position
	body.add_child(shape)
	add_child(body)


func _roads() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	var root := Node3D.new()
	root.name = "RoadContext"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.22, 0.23)
	mat.roughness = 0.9
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for road_v in parsed["roads"]:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		var coords: Array[Vector2] = []
		var near := false
		for pt in pts:
			var x: float
			var z: float
			if pt is Dictionary:
				x = float(pt["x"])
				z = float(pt["z"])
			else:
				x = float(pt[0])
				z = float(pt[1])
			coords.append(Vector2(x, z))
			if x >= X0 and x <= X1 and z >= Z0 and z <= Z1:
				near = true
		if not near or coords.size() < 2:
			continue
		var half := float(road.get("width", 7.0)) * 0.5
		for i in coords.size() - 1:
			var a: Vector2 = coords[i]
			var b: Vector2 = coords[i + 1]
			var dir := b - a
			if dir.length() < 0.05:
				continue
			dir = dir.normalized()
			var side := Vector2(-dir.y, dir.x) * half
			var y := 0.04
			st.set_color(Color.WHITE)
			st.set_uv(Vector2(0, 0))
			st.add_vertex(Vector3(a.x + side.x, y, a.y + side.y))
			st.set_uv(Vector2(1, 0))
			st.add_vertex(Vector3(a.x - side.x, y, a.y - side.y))
			st.set_uv(Vector2(1, 1))
			st.add_vertex(Vector3(b.x - side.x, y, b.y - side.y))
			st.set_uv(Vector2(0, 0))
			st.add_vertex(Vector3(a.x + side.x, y, a.y + side.y))
			st.set_uv(Vector2(1, 1))
			st.add_vertex(Vector3(b.x - side.x, y, b.y - side.y))
			st.set_uv(Vector2(0, 1))
			st.add_vertex(Vector3(b.x + side.x, y, b.y + side.y))
		count += 1
	var mesh := st.commit()
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	root.add_child(inst)
	add_child(root)
	print("ARCH roads in view ", count)


func _colliders(root: Node) -> void:
	if root == null:
		push_error("Architecture root missing")
		return
	var made := 0
	for node in root.find_children("col_*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var body := StaticBody3D.new()
		body.name = "hit_" + mi.name
		body.transform = mi.global_transform
		var shape_node := CollisionShape3D.new()
		shape_node.shape = mi.mesh.create_trimesh_shape()
		body.add_child(shape_node)
		add_child(body)
		mi.visible = false
		var faces := (shape_node.shape as ConcavePolygonShape3D).get_faces().size()
		if made == 0:
			print("ARCH collider faces ", faces, " ", body.global_position)
		made += 1
	print("ARCH colliders ", made)
	_two_sided($Architecture)
	if has_node("Library"):
		_two_sided($Library)


func _two_sided(node: Node) -> void:
	var seen := {}
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if str(mi.name).begins_with("col_"):
			continue
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(s)
			if mat is BaseMaterial3D and not seen.has(mat):
				seen[mat] = true
				(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED


func _hud() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "Architecture prototype    C aerial    WASD drive    not the production city"
	label.position = Vector2(16, 12)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	layer.add_child(label)
	add_child(layer)
