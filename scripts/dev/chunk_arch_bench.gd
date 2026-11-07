extends SceneTree
## Phase 2H.4A — small isolated chunk architecture benchmark (NOT production).
## Compares: N individual MeshInstance3D shells vs M spatial MultiMesh/merged chunks.


const COUNT := 64
const CHUNK := 8  # buildings per chunk
const RES := Vector2i(1280, 720)


func _initialize() -> void:
	DisplayServer.window_set_size(RES)
	var root3 := Node3D.new()
	root3.name = "ChunkArchBench"
	root.add_child(root3)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.72, 0.88)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.75, 0.8)
	e.ambient_light_energy = 0.7
	env.environment = e
	root3.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	root3.add_child(sun)

	var cam := Camera3D.new()
	cam.current = true
	cam.position = Vector3(24, 28, 36)
	cam.look_at(Vector3(12, 0, 12))
	root3.add_child(cam)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.55, 0.38)
	ground.material_override = gm
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root3.add_child(ground)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.86, 0.82, 0.74)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.55, 0.22, 0.18)

	# --- A: one MeshInstance per building (2 surfaces each) ---
	var individual := Node3D.new()
	individual.name = "Individual"
	root3.add_child(individual)
	for i in COUNT:
		var xf := _slot(i)
		_add_shell(individual, xf, wall_mat, roof_mat, "b_%d" % i, str(1000000 + i))
	await _settle(20)
	await _sample("A_individual_64")

	individual.visible = false
	# --- B: spatial chunks — merge COUNT/CHUNK buildings into one ArrayMesh per chunk ---
	var chunks := Node3D.new()
	chunks.name = "Chunks"
	root3.add_child(chunks)
	var st_wall := SurfaceTool.new()
	var st_roof := SurfaceTool.new()
	var in_chunk := 0
	var chunk_i := 0
	var meta_ids: Array[String] = []
	st_wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in COUNT:
		var xf := _slot(i)
		_append_shell(st_wall, st_roof, xf)
		meta_ids.append(str(1000000 + i))
		in_chunk += 1
		if in_chunk >= CHUNK or i == COUNT - 1:
			var am := ArrayMesh.new()
			st_wall.generate_normals()
			st_roof.generate_normals()
			var wmesh := st_wall.commit()
			# commit wall then roof into one ArrayMesh with 2 surfaces
			var combined := ArrayMesh.new()
			_copy_surface(combined, wmesh, 0, wall_mat)
			var rmesh := st_roof.commit()
			_copy_surface(combined, rmesh, 0, roof_mat)
			var mi := MeshInstance3D.new()
			mi.name = "chunk_%d" % chunk_i
			mi.mesh = combined
			mi.set_meta("osm_way_ids", meta_ids.duplicate())
			chunks.add_child(mi)
			# Collision: one trimesh per chunk
			var body := StaticBody3D.new()
			body.name = "chunk_col_%d" % chunk_i
			var col := CollisionShape3D.new()
			col.shape = combined.create_trimesh_shape()
			body.add_child(col)
			chunks.add_child(body)
			chunk_i += 1
			in_chunk = 0
			meta_ids.clear()
			st_wall = SurfaceTool.new()
			st_roof = SurfaceTool.new()
			st_wall.begin(Mesh.PRIMITIVE_TRIANGLES)
			st_roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	await _settle(20)
	await _sample("B_chunks_8")

	# --- C: distance hide far chunks (simulate LOD visibility) ---
	for c in chunks.get_children():
		if c is MeshInstance3D:
			var mi2 := c as MeshInstance3D
			if mi2.global_position.distance_to(cam.global_position) > 40.0:
				mi2.visible = false
	await _settle(16)
	await _sample("C_chunks_distance_hide")

	print("CHUNK_ARCH_BENCH_DONE chunks=", chunk_i, " buildings=", COUNT)
	quit()


func _slot(i: int) -> Transform3D:
	var x := float(i % 8) * 4.5
	var z := float(i / 8) * 4.5
	var h := 3.5 + float(i % 4) * 1.2
	return Transform3D(Basis.IDENTITY.scaled(Vector3(3.2, h, 2.8)), Vector3(x, h * 0.5, z))


func _add_shell(parent: Node3D, xf: Transform3D, wall: Material, roof: Material, nm: String, osm_id: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.set_meta("osm_way_id", osm_id)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mi.mesh = box
	mi.transform = xf
	mi.set_surface_override_material(0, wall)
	parent.add_child(mi)
	var roof_mi := MeshInstance3D.new()
	roof_mi.name = nm + "_roof"
	var rbox := BoxMesh.new()
	rbox.size = Vector3(1.05, 0.12, 1.05)
	roof_mi.mesh = rbox
	roof_mi.position = xf.origin + Vector3(0, xf.basis.get_scale().y * 0.5 + 0.08, 0)
	roof_mi.scale = Vector3(xf.basis.get_scale().x, 1, xf.basis.get_scale().z)
	roof_mi.set_surface_override_material(0, roof)
	parent.add_child(roof_mi)


func _append_shell(st_wall: SurfaceTool, st_roof: SurfaceTool, xf: Transform3D) -> void:
	# Unit box via SurfaceTool box faces under xf
	var hx := 0.5
	var hy := 0.5
	var hz := 0.5
	var corners := [
		Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz),
		Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz),
	]
	var faces := [
		[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0],
	]
	for f in faces:
		var a: Vector3 = xf * corners[f[0]]
		var b: Vector3 = xf * corners[f[1]]
		var c: Vector3 = xf * corners[f[2]]
		var d: Vector3 = xf * corners[f[3]]
		st_wall.add_vertex(a)
		st_wall.add_vertex(b)
		st_wall.add_vertex(c)
		st_wall.add_vertex(a)
		st_wall.add_vertex(c)
		st_wall.add_vertex(d)
	# Thin roof slab
	var top := xf.origin + Vector3(0, xf.basis.get_scale().y * 0.5 + 0.08, 0)
	var sx := xf.basis.get_scale().x * 0.525
	var sz := xf.basis.get_scale().z * 0.525
	var ry := 0.06
	var rc := [
		top + Vector3(-sx, -ry, -sz), top + Vector3(sx, -ry, -sz), top + Vector3(sx, ry, -sz), top + Vector3(-sx, ry, -sz),
		top + Vector3(-sx, -ry, sz), top + Vector3(sx, -ry, sz), top + Vector3(sx, ry, sz), top + Vector3(-sx, ry, sz),
	]
	for f in faces:
		st_roof.add_vertex(rc[f[0]])
		st_roof.add_vertex(rc[f[1]])
		st_roof.add_vertex(rc[f[2]])
		st_roof.add_vertex(rc[f[0]])
		st_roof.add_vertex(rc[f[2]])
		st_roof.add_vertex(rc[f[3]])


func _copy_surface(dst: ArrayMesh, src: Mesh, surf: int, mat: Material) -> void:
	if src == null or src.get_surface_count() <= surf:
		return
	var arrs := src.surface_get_arrays(surf)
	dst.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	dst.surface_set_material(dst.get_surface_count() - 1, mat)


func _settle(n: int) -> void:
	for _i in n:
		await process_frame


func _sample(tag: String) -> void:
	var fps: Array[float] = []
	var draws: Array[float] = []
	var objs: Array[float] = []
	for i in 30:
		await process_frame
		if i < 8:
			continue
		fps.append(Performance.get_monitor(Performance.TIME_FPS))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objs.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	fps.sort()
	draws.sort()
	objs.sort()
	print(
		"BENCH ", tag,
		" fps_med=", snapped(fps[fps.size() / 2], 0.1),
		" draws_med=", snapped(draws[draws.size() / 2], 1.0),
		" objects_med=", snapped(objs[objs.size() / 2], 1.0)
	)
