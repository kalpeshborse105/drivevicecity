extends SceneTree
## Phase 2H.4A — reproducible production performance baseline on main.tscn.
## Discovers DhuleBlosmCity by name walk. Does not use the synthetic QA scene.


const RES := Vector2i(1280, 720)
const WARMUP := 10
const SAMPLES := 36


func _initialize() -> void:
	DisplayServer.window_set_size(RES)
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("MAIN_MISSING")
		quit(1)
		return
	var world := packed.instantiate()
	root.add_child(world)

	var t0 := Time.get_ticks_msec()
	for _i in 220:
		await process_frame
	print("BOOT_MS ", Time.get_ticks_msec() - t0)
	print("RES ", RES.x, "x", RES.y)

	var car := world.find_child("PlayerCar", true, false) as VehicleBody3D
	if car == null:
		push_error("NO_CAR")
		quit(2)
		return
	var cam := _find_chase_cam(car)
	var garage := world.find_child("GaragePanel", true, false) as Control
	var blosm := _find_blosm(world)
	print(
		"SPAWN ", car.global_position,
		" CAM ", cam != null,
		" GARAGE ", garage != null,
		" BLOSM ", blosm != null,
		" BLOSM_PATH ", str(blosm.get_path()) if blosm else "-"
	)

	var inv := _inventory(world)
	_print_inventory(inv)
	if blosm:
		_print_blosm_detail(blosm)

	# Freeze car for camera-locked samples.
	car.engine_force = 0.0
	car.brake = 35.0
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	if car.has_method("set_physics_process"):
		car.set_physics_process(false)

	var spawn := car.global_position
	var heading := -car.global_transform.basis.z
	heading.y = 0.0
	if heading.length() < 0.1:
		heading = Vector3(0, 0, -1)
	heading = heading.normalized()
	var right := Vector3(-heading.z, 0, heading.x)

	var blosm_look := spawn + heading * 40.0
	if blosm is Node3D:
		var bpos := _blosm_focus(blosm as Node3D)
		if bpos != Vector3.ZERO:
			blosm_look = bpos

	# 1 Spawn
	await _view(cam, spawn + Vector3(0, 3.2, 0) - heading * 8.5 + Vector3(0, 1.2, 0), spawn + heading * 12.0 + Vector3(0, 1.0, 0))
	await _measure("01_spawn")

	# 2 Long road
	await _view(cam, spawn + Vector3(0, 4.5, 0) - heading * 4.0, spawn + heading * 120.0 + Vector3(0, 1.0, 0))
	await _measure("02_long_road")

	# 3 Toward Blosm city
	await _view(cam, spawn + Vector3(0, 8.0, 0) + right * 6.0, blosm_look + Vector3(0, 4.0, 0))
	await _measure("03_toward_blosm")

	# 4 Dense area (near Blosm AABB center / focus)
	var dense_pos := spawn + heading * 80.0
	if blosm is Node3D:
		var focus := _blosm_focus(blosm as Node3D)
		if focus != Vector3.ZERO:
			dense_pos = focus + Vector3(35, 0, 35)
			dense_pos.y = spawn.y
	car.global_position = dense_pos
	await _settle(20)
	await _view(cam, dense_pos + Vector3(0, 3.4, 0) - heading * 9.0, dense_pos + heading * 25.0 + Vector3(0, 1.5, 0))
	await _measure("04_dense_area")

	# 5 Open terrain
	var open_pos := spawn - heading * 90.0 + right * 120.0
	open_pos.y = spawn.y
	car.global_position = open_pos
	await _settle(16)
	await _view(cam, open_pos + Vector3(0, 6.0, 0), open_pos + heading * 40.0)
	await _measure("05_open_terrain")

	# Return to spawn for garage A/B
	car.global_position = spawn
	await _settle(16)
	await _view(cam, spawn + Vector3(0, 3.2, 0) - heading * 8.5 + Vector3(0, 1.2, 0), spawn + heading * 12.0 + Vector3(0, 1.0, 0))

	# 6 Garage closed
	if garage:
		garage.visible = false
		if garage.has_method("toggle") == false and garage.get_node_or_null("CarPreview"):
			pass
		_set_garage_live(garage, false)
	await _settle(10)
	await _measure("06_garage_closed")

	# 7 Garage open
	if garage:
		garage.visible = true
		_set_garage_live(garage, true)
		await _settle(14)
		await _measure("07_garage_open")
		garage.visible = false
		_set_garage_live(garage, false)

	# Drive sample (gameplay motion) back at spawn
	car.global_position = spawn
	car.set_physics_process(true)
	car.brake = 0.0
	await _settle(8)
	Input.action_press("accelerate")
	for _d in 90:
		await physics_frame
	await _measure("08_driving")
	Input.action_release("accelerate")

	print("PERF_BASELINE_DONE")
	quit()


func _find_chase_cam(car: Node) -> Camera3D:
	var n := car.find_child("Camera3D", true, false)
	if n is Camera3D:
		(n as Camera3D).current = true
		return n as Camera3D
	return null


func _find_blosm(root_n: Node) -> Node:
	var hit := root_n.find_child("DhuleBlosmCity", true, false)
	if hit:
		return hit
	hit = root_n.find_child("dhule_blosm_city", true, false)
	if hit:
		return hit
	# Dynamic walk — mesh name or path contains blosm / dhule_city_osm_buildings
	return _walk_find_blosm(root_n)


func _walk_find_blosm(n: Node) -> Node:
	var nm := str(n.name).to_lower()
	if nm == "dhuleblosmcity" or nm.contains("blosm") or nm.contains("dhule_city_osm_buildings"):
		# Prefer the city root over a child mesh.
		if n.get_child_count() > 0 and nm.contains("buildings"):
			return n.get_parent()
		return n
	for c in n.get_children():
		var found := _walk_find_blosm(c)
		if found:
			return found
	return null


func _blosm_focus(blosm: Node3D) -> Vector3:
	for c in blosm.get_children():
		if c is MeshInstance3D and str(c.name).to_lower().contains("buildings"):
			var mi := c as MeshInstance3D
			if mi.mesh:
				var aabb := mi.get_aabb()
				var center := mi.to_global(aabb.get_center())
				# Prefer a point nearer spawn district rather than absolute mesh center (km-scale).
				return Vector3(center.x * 0.15, 0.0, center.z * 0.15)
	return blosm.global_position


func _set_garage_live(garage: Node, on: bool) -> void:
	var preview := garage.find_child("CarPreview", true, false)
	if preview and preview.has_method("set_live"):
		preview.call("set_live", on)
	elif preview is SubViewportContainer:
		for c in preview.get_children():
			if c is SubViewport:
				(c as SubViewport).render_target_update_mode = (
					SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
				)


func _view(cam: Camera3D, from: Vector3, at: Vector3) -> void:
	if cam == null:
		return
	cam.current = true
	cam.global_position = from
	if from.distance_to(at) > 0.5:
		cam.look_at(at, Vector3.UP)
	await _settle(8)


func _settle(n: int) -> void:
	for _i in n:
		await process_frame


func _measure(tag: String) -> void:
	var fps: Array[float] = []
	var ft: Array[float] = []
	var draws: Array[float] = []
	var objs: Array[float] = []
	var prims: Array[float] = []
	for i in SAMPLES:
		await process_frame
		if i < WARMUP:
			continue
		fps.append(Performance.get_monitor(Performance.TIME_FPS))
		ft.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objs.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	fps.sort()
	ft.sort()
	draws.sort()
	objs.sort()
	prims.sort()
	var mem_s := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var video := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)
	print(
		"PERF ", tag,
		" fps_med=", _med(fps),
		" fps_min=", snapped(fps[0], 0.1) if fps.size() else 0,
		" ft_med_ms=", _med(ft),
		" draws_med=", _med(draws),
		" objects_med=", _med(objs),
		" prims_med=", _med(prims),
		" mem_static_mb=", snapped(mem_s, 0.1),
		" mem_video_mb=", snapped(video, 0.1)
	)


func _med(vals: Array[float]) -> float:
	if vals.is_empty():
		return 0.0
	return snapped(vals[vals.size() / 2], 0.1)


func _inventory(root_n: Node) -> Dictionary:
	var d := {
		"mesh": 0,
		"multimesh": 0,
		"label3d": 0,
		"casters_on": 0,
		"casters_off": 0,
		"transparent": 0,
		"subviewports": 0,
		"unique_mats": {},
		"by_prefix": {},
		"blosm_meshes": 0,
		"blosm_surfaces": 0,
		"road_meshes": 0,
		"tree_like": 0,
	}
	_inv_walk(root_n, d)
	d["unique_mat_count"] = (d["unique_mats"] as Dictionary).size()
	return d


func _inv_walk(n: Node, d: Dictionary) -> void:
	if n is SubViewport:
		d["subviewports"] = int(d["subviewports"]) + 1
	if n is Label3D:
		d["label3d"] = int(d["label3d"]) + 1
	if n is MultiMeshInstance3D:
		d["multimesh"] = int(d["multimesh"]) + 1
		var mmi := n as MultiMeshInstance3D
		if mmi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			d["casters_on"] = int(d["casters_on"]) + 1
		else:
			d["casters_off"] = int(d["casters_off"]) + 1
	if n is MeshInstance3D:
		d["mesh"] = int(d["mesh"]) + 1
		var mi := n as MeshInstance3D
		var path := str(mi.get_path()).to_lower()
		var nm := str(mi.name).to_lower()
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			d["casters_on"] = int(d["casters_on"]) + 1
		else:
			d["casters_off"] = int(d["casters_off"]) + 1
		if path.contains("blosm") or path.contains("dhuleblosmcity") or nm.contains("dhule_city"):
			d["blosm_meshes"] = int(d["blosm_meshes"]) + 1
			if mi.mesh:
				d["blosm_surfaces"] = int(d["blosm_surfaces"]) + mi.mesh.get_surface_count()
		if nm == "roads" or nm == "road_marks" or path.contains("/roads") or nm.begins_with("kit_road"):
			d["road_meshes"] = int(d["road_meshes"]) + 1
		if nm.contains("tree") or nm.contains("canopy") or nm.contains("trunk"):
			d["tree_like"] = int(d["tree_like"]) + 1
		if mi.mesh:
			for si in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(si)
				if mat:
					(d["unique_mats"] as Dictionary)[mat.get_instance_id()] = true
					if mat is BaseMaterial3D:
						var bm := mat as BaseMaterial3D
						if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
							d["transparent"] = int(d["transparent"]) + 1
		var prefix := nm.split("_")[0] if nm.contains("_") else nm
		var bp: Dictionary = d["by_prefix"]
		bp[prefix] = int(bp.get(prefix, 0)) + 1
	for c in n.get_children():
		_inv_walk(c, d)


func _print_inventory(d: Dictionary) -> void:
	print(
		"INV mesh=", d["mesh"],
		" multimesh=", d["multimesh"],
		" label3d=", d["label3d"],
		" subviewports=", d["subviewports"],
		" casters_on=", d["casters_on"],
		" casters_off=", d["casters_off"],
		" transparent_surfs=", d["transparent"],
		" unique_mats=", d["unique_mat_count"],
		" blosm_meshes=", d["blosm_meshes"],
		" blosm_surfaces=", d["blosm_surfaces"],
		" road_meshes=", d["road_meshes"],
		" tree_like=", d["tree_like"]
	)
	var bp: Dictionary = d["by_prefix"]
	var keys: Array = bp.keys()
	keys.sort_custom(func(a, b): return int(bp[a]) > int(bp[b]))
	var top := []
	for i in mini(12, keys.size()):
		top.append("%s=%s" % [keys[i], bp[keys[i]]])
	print("INV_TOP_MESH_PREFIX ", ", ".join(PackedStringArray(top)))


func _print_blosm_detail(blosm: Node) -> void:
	print("BLOSM_ROOT ", blosm.name, " children=", blosm.get_child_count())
	for c in blosm.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var aabb := mi.get_aabb() if mi.mesh else AABB()
			var surfs := mi.mesh.get_surface_count() if mi.mesh else 0
			var mats := []
			for si in surfs:
				var m := mi.get_active_material(si)
				mats.append(m.resource_path if m and m.resource_path != "" else (m.get_class() if m else "null"))
			print(
				"BLOSM_MESH ", c.name,
				" surfs=", surfs,
				" aabb=", snapped(aabb.size.x, 0.1), "x", snapped(aabb.size.y, 0.1), "x", snapped(aabb.size.z, 0.1),
				" cast=", mi.cast_shadow,
				" mats=", ",".join(PackedStringArray(mats))
			)
