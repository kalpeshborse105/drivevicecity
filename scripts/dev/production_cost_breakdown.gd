extends SceneTree
## Phase 2H.4A — name the draw/mesh cost owners in production main.tscn.


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for _i in 200:
		await process_frame

	var buckets := {}
	var caster_buckets := {}
	var mat_owners := {}
	_walk(world, buckets, caster_buckets, mat_owners)

	print("COST_MESH_BUCKETS")
	_print_sorted(buckets, 25)
	print("COST_CASTER_BUCKETS")
	_print_sorted(caster_buckets, 20)
	print("COST_MAT_OWNER_SAMPLES")
	var mk: Array = mat_owners.keys()
	mk.sort_custom(func(a, b): return int(mat_owners[a]) > int(mat_owners[b]))
	for i in mini(15, mk.size()):
		print("  ", mk[i], "=", mat_owners[mk[i]])

	# Hide-category A/B at spawn camera — one category at a time, restore after.
	var car := world.find_child("PlayerCar", true, false) as VehicleBody3D
	var cam := car.find_child("Camera3D", true, false) as Camera3D
	if cam:
		cam.current = true
	await _settle(12)
	await _sample("BASE")

	await _ab_hide(world, "HIDE_LABEL3D", func(n): return n is Label3D)
	await _ab_hide(world, "HIDE_MULTIMESH", func(n): return n is MultiMeshInstance3D)
	await _ab_hide(world, "HIDE_BLOSM", func(n): return str(n.get_path()).contains("DhuleBlosmCity"))
	await _ab_hide(world, "HIDE_OBJECT_PREFIX", func(n): return n is MeshInstance3D and str(n.name).to_lower().begins_with("object"))
	await _ab_minimap(world, false, "MINIMAP_OFF")
	await _ab_minimap(world, true, "MINIMAP_ON")
	await _ab_shadows_small(world, "SHADOWS_OFF_SMALL_MESH")

	print("COST_BREAKDOWN_DONE")
	quit()


func _walk(n: Node, buckets: Dictionary, casters: Dictionary, mats: Dictionary) -> void:
	if n is MeshInstance3D or n is MultiMeshInstance3D:
		var bucket := _bucket(n)
		buckets[bucket] = int(buckets.get(bucket, 0)) + 1
		var gi := n as GeometryInstance3D
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			casters[bucket] = int(casters.get(bucket, 0)) + 1
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var mi := n as MeshInstance3D
			for si in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(si)
				if mat:
					var key := bucket
					mats[key] = int(mats.get(key, 0)) + 1
	for c in n.get_children():
		_walk(c, buckets, casters, mats)


func _bucket(n: Node) -> String:
	var path := str(n.get_path())
	var low := path.to_lower()
	if low.contains("dhuleblosmcity") or low.contains("blosm"):
		return "blosm"
	if low.contains("playercar") or low.contains("visualroot"):
		return "player_car"
	if low.contains("minimap") or low.contains("minicam"):
		return "minimap"
	if low.contains("carpreview") or low.contains("previewviewport") or low.contains("garage"):
		return "garage_preview"
	if n is MultiMeshInstance3D:
		return "multimesh:" + str(n.name).to_lower()
	if n is Label3D:
		return "label3d"
	var nm := str(n.name).to_lower()
	if nm in ["roads", "road_marks"] or nm.begins_with("kit_road") or nm.contains("roundabout"):
		return "roads"
	if nm.begins_with("object"):
		# Parent chain for kit props
		var p := n.get_parent()
		while p:
			var pn := str(p.name)
			if pn.begins_with("street_") or pn.contains("Solid_") or pn.contains("kit") or pn.contains("prop"):
				return "prop:" + pn.left(24)
			if pn.contains("DhuleMap") or pn.contains("Osm"):
				break
			p = p.get_parent()
		return "mesh:object*"
	if nm.begins_with("main") or nm.begins_with("spare") or nm.contains("cylinder"):
		return "mesh:vehicle_kit_parts"
	return "mesh:" + nm.left(28)


func _print_sorted(d: Dictionary, limit: int) -> void:
	var keys: Array = d.keys()
	keys.sort_custom(func(a, b): return int(d[a]) > int(d[b]))
	for i in mini(limit, keys.size()):
		print("  ", keys[i], "=", d[keys[i]])


func _settle(n: int) -> void:
	for _i in n:
		await process_frame


func _sample(tag: String) -> void:
	var fps: Array[float] = []
	var draws: Array[float] = []
	var prims: Array[float] = []
	for i in 28:
		await process_frame
		if i < 8:
			continue
		fps.append(Performance.get_monitor(Performance.TIME_FPS))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	fps.sort()
	draws.sort()
	prims.sort()
	print(
		"AB ", tag,
		" fps_med=", snapped(fps[fps.size() / 2], 0.1),
		" draws_med=", snapped(draws[draws.size() / 2], 1.0),
		" prims_med=", snapped(prims[prims.size() / 2], 1.0)
	)


func _ab_hide(world: Node, tag: String, pred: Callable) -> void:
	var hidden: Array[Node] = []
	_collect_pred(world, pred, hidden)
	for n in hidden:
		if n is Node3D:
			(n as Node3D).visible = false
		elif n is CanvasItem:
			(n as CanvasItem).visible = false
	await _settle(10)
	await _sample(tag)
	for n in hidden:
		if is_instance_valid(n):
			if n is Node3D:
				(n as Node3D).visible = true
			elif n is CanvasItem:
				(n as CanvasItem).visible = true
	await _settle(8)


func _collect_pred(n: Node, pred: Callable, out: Array[Node]) -> void:
	if pred.call(n):
		out.append(n)
	for c in n.get_children():
		_collect_pred(c, pred, out)


func _ab_minimap(world: Node, on: bool, tag: String) -> void:
	var mm := world.find_child("Minimap", true, false)
	if mm == null:
		print("AB ", tag, " skipped")
		return
	var vp := mm.find_child("SubViewport", true, false) as SubViewport
	if vp:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if mm is CanvasItem:
		(mm as CanvasItem).visible = on
	await _settle(10)
	await _sample(tag)


func _ab_shadows_small(world: Node, tag: String) -> void:
	var changed: Array = []
	_shadow_walk(world, changed)
	await _settle(10)
	await _sample(tag)
	for row in changed:
		(row[0] as GeometryInstance3D).cast_shadow = row[1]
	await _settle(6)


func _shadow_walk(n: Node, changed: Array) -> void:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		var path := str(gi.get_path()).to_lower()
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and not path.contains("dhuleblosmcity") and not path.contains("playercar"):
			# Turn off shadows on small meshes (AABB plan < 8 m)
			var plan := 99.0
			if n is MeshInstance3D and (n as MeshInstance3D).mesh:
				var s := (n as MeshInstance3D).get_aabb().size
				plan = maxf(s.x, s.z)
			if plan < 8.0:
				changed.append([gi, gi.cast_shadow])
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_shadow_walk(c, changed)
