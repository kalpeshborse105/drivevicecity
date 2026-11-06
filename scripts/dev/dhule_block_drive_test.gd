extends Node3D
## Isolated drive of the Sessions Court block. Does not replace the main scene.
## The GLB stays on its geographic transform. This script only adds test ground,
## one collision body, a spring-arm chase camera, and lighting for this scene.

const SPAWN := Vector3(-553.86, 0.42, 908.39)
const HEADING := Vector2(0.99894, 0.04611)
const LOG_PATH := "D:/drivevicecity_phase2_preview/qa/phase2a4/drive_log.txt"

# Same window the block generator used: x east, z south, 250 m.
const BLOCK_MIN_X := -760.0
const BLOCK_MAX_X := -510.0
const BLOCK_MIN_Z := 810.0
const BLOCK_MAX_Z := 1060.0
const CATCH_MARGIN := 350.0

var _aerial := false
var _log_wait := 0.0
var _arm: SpringArm3D
var _tip: Marker3D
var _chase: Camera3D


func _ready() -> void:
	_fix_block_visuals($Block)
	_build_ground()
	_build_collision($Block)
	_fill_junctions($Block)
	_setup_light()
	_log_mesh("R_887431548")
	_log_mesh("B_482794524")
	var car := $PlayerCar as Node3D
	if car.has_method("set_spawn"):
		car.set_spawn(SPAWN, HEADING)
	_setup_chase(car)
	$AerialCamera.far = 5000.0
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(80, 40))
	var log := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if log:
		log.store_line("DHULE_BLOCK_DRIVE spawn=(%.2f, %.2f, %.2f) heading=(%.5f, %.5f)" % [SPAWN.x, SPAWN.y, SPAWN.z, HEADING.x, HEADING.y])
		log.close()
	print("DHULE_BLOCK_DRIVE spawn=(%.2f, %.2f, %.2f) heading=(%.5f, %.5f)" % [SPAWN.x, SPAWN.y, SPAWN.z, HEADING.x, HEADING.y])


func _process(delta: float) -> void:
	var car := $PlayerCar as Node3D
	var pos := car.global_position
	var speed := 0.0
	if car is RigidBody3D:
		speed = (car as RigidBody3D).linear_velocity.length() * 3.6
	var fps := Engine.get_frames_per_second()
	$Overlay/Fps.text = "pos %.1f, %.2f, %.1f   %.0f km/h   %d FPS   F aerial" % [pos.x, pos.y, pos.z, speed, fps]
	_update_chase(car, delta)
	if _aerial:
		$AerialCamera.global_position = pos + Vector3(210.0, 280.0, 240.0)
		$AerialCamera.look_at(pos, Vector3.UP)
	_log_wait += delta
	if _log_wait >= 0.5:
		_log_wait = 0.0
		var log := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
		if log == null:
			log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		if log:
			log.seek_end()
			log.store_line("t=%.1f pos=(%.2f, %.2f, %.2f) cam=(%.1f, %.1f, %.1f) kmh=%.1f fps=%d aerial=%s" % [Time.get_ticks_msec() / 1000.0, pos.x, pos.y, pos.z, _chase.global_position.x if _chase else 0.0, _chase.global_position.y if _chase else 0.0, _chase.global_position.z if _chase else 0.0, speed, fps, str(_aerial)])
			log.close()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_aerial = not _aerial
		$AerialCamera.current = _aerial
		if _chase:
			_chase.current = not _aerial


func _setup_light() -> void:
	var env := ($WorldEnvironment as WorldEnvironment).environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	var sun := $Sun as DirectionalLight3D
	sun.rotation_degrees = Vector3(-58.0, 38.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 0.35
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_fade_start = 0.9
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.shadow_enabled = false
	fill.light_energy = 0.34
	fill.rotation_degrees = Vector3(-48.0, -150.0, 0.0)
	add_child(fill)


func _setup_chase(car: Node3D) -> void:
	var old := car.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if old:
		old.current = false
	_arm = SpringArm3D.new()
	_arm.name = "DriveSpringArm"
	# Cast starts above the cabin and goes out the rear (−Z). The car body is excluded
	# so the arm stops on the wall instead of starting inside it.
	_arm.position = Vector3(0.0, 1.7, -0.2)
	# Godot's spring arm casts along local +Z. Yaw 180 so that cast leaves the rear.
	_arm.rotation_degrees = Vector3(-12.0, 180.0, 0.0)
	_arm.spring_length = 8.0
	_arm.margin = 0.45
	_arm.collision_mask = 1
	var sphere := SphereShape3D.new()
	sphere.radius = 0.42
	_arm.shape = sphere
	if car is CollisionObject3D:
		_arm.add_excluded_object((car as CollisionObject3D).get_rid())
	car.add_child(_arm)
	_tip = Marker3D.new()
	_tip.name = "Tip"
	_arm.add_child(_tip)
	_chase = Camera3D.new()
	_chase.name = "DriveChaseCamera"
	_chase.fov = 65.0
	_chase.near = 0.15
	_chase.far = 900.0
	_chase.current = true
	add_child(_chase)
	_chase.global_position = car.global_position + Vector3(0.0, 3.2, 6.0)


func _update_chase(car: Node3D, delta: float) -> void:
	if _chase == null or _tip == null:
		return
	var old_cam := car.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if old_cam:
		old_cam.current = false
	if _aerial:
		return
	_chase.current = true
	var target := _tip.global_position
	var gap := _chase.global_position.distance_to(target)
	if gap > 12.0:
		_chase.global_position = target
	else:
		var from_car_now := _chase.global_position.distance_to(car.global_position)
		var from_car_tip := target.distance_to(car.global_position)
		var rate := 16.0 if from_car_tip + 0.2 < from_car_now else 5.0
		_chase.global_position = _chase.global_position.lerp(target, clampf(delta * rate, 0.0, 1.0))
	var look := car.global_position + car.global_transform.basis.z * 7.0 + Vector3.UP * 1.25
	if _chase.global_position.distance_squared_to(look) > 0.04:
		_chase.look_at(look, Vector3.UP)


func _build_ground() -> void:
	var width := BLOCK_MAX_X - BLOCK_MIN_X
	var depth := BLOCK_MAX_Z - BLOCK_MIN_Z
	var center := Vector3((BLOCK_MIN_X + BLOCK_MAX_X) * 0.5, 0.0, (BLOCK_MIN_Z + BLOCK_MAX_Z) * 0.5)
	var outer := _plane("Catchment", width + CATCH_MARGIN * 2.0, depth + CATCH_MARGIN * 2.0, Color(0.33, 0.40, 0.28), -0.04)
	outer.position = Vector3(center.x, -0.04, center.z)
	add_child(outer)
	var inner := _plane("NeighborhoodGround", width, depth, Color(0.62, 0.52, 0.38), 0.0)
	inner.position = center
	add_child(inner)
	var edge_mat := _flat_material(Color(0.78, 0.58, 0.32))
	_edge_strip(Vector3(center.x, 0.03, BLOCK_MIN_Z), Vector3(width, 0.02, 1.6), edge_mat)
	_edge_strip(Vector3(center.x, 0.03, BLOCK_MAX_Z), Vector3(width, 0.02, 1.6), edge_mat)
	_edge_strip(Vector3(BLOCK_MIN_X, 0.03, center.z), Vector3(1.6, 0.02, depth), edge_mat)
	_edge_strip(Vector3(BLOCK_MAX_X, 0.03, center.z), Vector3(1.6, 0.02, depth), edge_mat)


func _plane(node_name: String, width: float, depth: float, color: Color, _y: float) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(width, depth)
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = _flat_material(color)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


func _edge_strip(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = "BlockBoundary"
	inst.mesh = mesh
	inst.position = pos
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.96
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


func _build_collision(block: Node) -> void:
	var body := StaticBody3D.new()
	body.name = "DriveCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var width := BLOCK_MAX_X - BLOCK_MIN_X + CATCH_MARGIN * 2.0
	var depth := BLOCK_MAX_Z - BLOCK_MIN_Z + CATCH_MARGIN * 2.0
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(width, 2.0, depth)
	var ground_col := CollisionShape3D.new()
	ground_col.shape = ground_shape
	ground_col.position = Vector3((BLOCK_MIN_X + BLOCK_MAX_X) * 0.5, -1.0, (BLOCK_MIN_Z + BLOCK_MAX_Z) * 0.5)
	body.add_child(ground_col)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(block, meshes)
	var walls := 0
	for mesh in meshes:
		var mesh_name := str(mesh.name)
		if not mesh_name.begins_with("B_"):
			continue
		var faces := _wall_faces(mesh.mesh)
		if faces.is_empty():
			continue
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		col.global_transform = mesh.global_transform
		walls += 1
	print("DRIVE_COLLISION ground=1 building_shells=%d" % walls)


func _wall_faces(mesh: Mesh) -> PackedVector3Array:
	var faces := PackedVector3Array()
	if mesh == null:
		return faces
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays.is_empty():
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var indexed := not indices.is_empty()
		var count := indices.size() if indexed else verts.size()
		var i := 0
		while i + 2 < count:
			var a: Vector3 = verts[indices[i] if indexed else i]
			var b: Vector3 = verts[indices[i + 1] if indexed else i + 1]
			var c: Vector3 = verts[indices[i + 2] if indexed else i + 2]
			var n := (b - a).cross(c - a)
			# Drop roofs and floors so they do not sit on the ground collider.
			if n.length_squared() > 0.000001 and absf(n.normalized().y) < 0.82:
				faces.append(a)
				faces.append(b)
				faces.append(c)
			i += 3
	return faces


func _fill_junctions(block: Node) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(block, meshes)
	var mids: Array[Vector3] = []
	var widths: Array[float] = []
	var owners: Array[int] = []
	var owner := 0
	for mesh in meshes:
		if not str(mesh.name).begins_with("R_"):
			continue
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.size() < 4:
			owner += 1
			continue
		var paired := {}
		var width := 6.5
		for a in verts.size():
			if paired.has(a):
				continue
			var pa: Vector3 = mesh.global_transform * verts[a]
			var best_b := -1
			var best_d := 20.0
			for b in verts.size():
				if a == b or paired.has(b):
					continue
				var d := pa.distance_to(mesh.global_transform * verts[b])
				if d > 2.5 and d < best_d:
					best_d = d
					best_b = b
			if best_b < 0:
				continue
			paired[a] = true
			paired[best_b] = true
			width = best_d
			var pb: Vector3 = mesh.global_transform * verts[best_b]
			mids.append((pa + pb) * 0.5)
			widths.append(best_d)
			owners.append(owner)
		print("ROAD %s width=%.2f" % [str(mesh.name), width])
		owner += 1
	var mat := _flat_material(Color(0.18, 0.18, 0.19))
	var used: Array[Vector3] = []
	var placed := 0
	for i in mids.size():
		var radius := widths[i]
		var hit := false
		for j in mids.size():
			if owners[i] == owners[j]:
				continue
			if mids[i].distance_to(mids[j]) > 4.0:
				continue
			hit = true
			radius = maxf(radius, widths[j])
		if not hit:
			continue
		var crowded := false
		for previous in used:
			if previous.distance_to(mids[i]) < 3.5:
				crowded = true
				break
		if crowded:
			continue
		used.append(mids[i])
		var at := mids[i]
		at.y = 0.028
		var cap := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = radius * 0.5
		cyl.bottom_radius = radius * 0.5
		cyl.height = 0.01
		cap.mesh = cyl
		cap.material_override = mat
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cap.position = at
		add_child(cap)
		placed += 1
	print("JUNCTION_CAPS %d" % placed)


func _fix_block_visuals(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var mesh_name := str(mesh.name)
		if mesh_name == "Ground" or mesh_name.begins_with("R_"):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh_name == "Ground":
			mesh.visible = false
		if mesh.mesh:
			for surface in mesh.mesh.get_surface_count():
				var mat := mesh.get_active_material(surface)
				if mat is BaseMaterial3D:
					(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_BACK
	for child in node.get_children():
		_fix_block_visuals(child)


func _collect_meshes(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		into.append(node)
	for child in node.get_children():
		_collect_meshes(child, into)


func _log_mesh(mesh_name: String) -> void:
	var mesh := _find_named($Block, mesh_name)
	if mesh is MeshInstance3D:
		var aabb: AABB = (mesh as MeshInstance3D).get_aabb()
		var center: Vector3 = (mesh as MeshInstance3D).global_transform * aabb.get_center()
		print("MESH %s center=(%.2f, %.2f, %.2f) size=(%.2f, %.2f, %.2f)" % [mesh_name, center.x, center.y, center.z, aabb.size.x, aabb.size.y, aabb.size.z])
	else:
		print("MESH %s missing" % mesh_name)


func _find_named(node: Node, mesh_name: String) -> Node:
	if str(node.name) == mesh_name:
		return node
	for child in node.get_children():
		var found := _find_named(child, mesh_name)
		if found:
			return found
	return null
