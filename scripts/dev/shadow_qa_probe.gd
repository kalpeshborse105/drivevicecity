extends SceneTree
## Phase 2H.4B.1 — inventory casters + A/B/C vehicle shadow stills + drive QA.
## Usage: godot --path . --script res://scripts/dev/shadow_qa_probe.gd -- --mode=A|B|C|inv|drive


const RES := Vector2i(1280, 720)


func _initialize() -> void:
	DisplayServer.window_set_size(RES)
	var mode := _arg_mode()
	print("SHADOW_QA_MODE ", mode)
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for _i in 200:
		await process_frame

	var car := world.find_child("PlayerCar", true, false) as VehicleBody3D
	if car == null:
		push_error("NO_CAR")
		quit(1)
		return
	var cam := car.find_child("Camera3D", true, false) as Camera3D
	if cam:
		cam.current = true

	_print_lights(world)
	var inv := _inventory(world, car)
	_write_inventory(inv)
	print("INV_SUMMARY total_on=", inv.size())

	match mode:
		"inv":
			print("SHADOW_QA_DONE inv")
			quit()
			return
		"A":
			_apply_vehicle_mode(car, "A")
		"B":
			_apply_vehicle_mode(car, "B")
		"C":
			_apply_vehicle_mode(car, "C")
		"drive":
			_apply_vehicle_mode(car, "B")  # approved default during drive if B is winner
		_:
			_apply_vehicle_mode(car, mode)

	await _settle(12)
	_lock_chase(cam, car)
	await _settle(8)
	await _shot("res://docs/qa/68-vehicle-shadow-%s.png" % mode.to_lower())
	_print_vehicle_casters(car)

	if mode == "drive" or mode == "B":
		# Moving-camera road samples with approved vehicle mode.
		Input.action_press("accelerate")
		for step in 5:
			for _f in 45:
				await physics_frame
			_lock_chase(cam, car)
			await _settle(4)
			await _shot("res://docs/qa/69-drive-%d.png" % (step + 1))
		Input.action_release("accelerate")
		# Building / open views
		var spawn := car.global_position
		var heading := -car.global_transform.basis.z
		heading.y = 0.0
		if heading.length() < 0.1:
			heading = Vector3(0, 0, -1)
		heading = heading.normalized()
		if cam:
			cam.global_position = spawn + Vector3(0, 4.5, 0) - heading * 6.0
			cam.look_at(spawn + heading * 30.0 + Vector3(0, 1, 0), Vector3.UP)
		await _settle(6)
		await _shot("res://docs/qa/69-buildings-props.png")
		if cam:
			cam.global_position = spawn - heading * 40.0 + Vector3(0, 8, 25)
			cam.look_at(spawn, Vector3.UP)
		await _settle(6)
		await _shot("res://docs/qa/69-open-terrain.png")

	print("SHADOW_QA_DONE ", mode)
	quit()


func _arg_mode() -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--mode="):
			return str(a).substr(7)
	return "inv"


func _settle(n: int) -> void:
	for _i in n:
		await process_frame


func _lock_chase(cam: Camera3D, car: VehicleBody3D) -> void:
	if cam == null or car == null:
		return
	cam.current = true
	var back := car.global_transform.basis.z
	cam.global_position = car.global_position - back * 8.5 + Vector3(0, 3.0, 0)
	cam.look_at(car.global_position + Vector3(0, 1.0, 0) + back * 4.0, Vector3.UP)


func _shot(path: String) -> void:
	# Prefer a drawn frame; headless can stall forever on frame_post_draw.
	var drawn := false
	for _i in 30:
		await process_frame
		var tex := root.get_viewport().get_texture()
		if tex:
			var img := tex.get_image()
			if img and img.get_width() > 0:
				img.save_png(ProjectSettings.globalize_path(path))
				print("SHOT ", path)
				drawn = true
				break
	if not drawn:
		push_warning("SHOT_SKIP " + path)


func _print_lights(world: Node) -> void:
	for n in _find_lights(world):
		var d := n as DirectionalLight3D
		print(
			"LIGHT ", d.get_path(),
			" energy=", snapped(d.light_energy, 0.01),
			" shadow=", d.shadow_enabled,
			" blur=", d.shadow_blur,
			" opacity=", d.shadow_opacity,
			" bias=", d.shadow_bias,
			" nbias=", d.shadow_normal_bias,
			" mode=", d.directional_shadow_mode,
			" maxdist=", d.directional_shadow_max_distance,
			" rot=", d.rotation_degrees
		)


func _find_lights(n: Node) -> Array:
	var out: Array = []
	if n is DirectionalLight3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_lights(c))
	return out


func _classify(path: String, nm: String) -> String:
	var p := path.to_lower()
	var n := nm.to_lower()
	if p.contains("playercar") or p.contains("visualroot"):
		return "vehicle"
	if p.contains("garage") or p.contains("carpreview") or p.contains("previewviewport"):
		return "garage_preview"
	if p.contains("dhuleblosmcity") or p.contains("blosm") or n.contains("dhule_city"):
		return "blosm"
	if n in ["roads", "road", "road_marks"] or n.begins_with("kit_road") or n.contains("junction") or n.contains("crosswalk") or n.contains("roundabout"):
		return "road"
	if n.contains("terrain") or n.contains("ground") or p.contains("horizon"):
		return "terrain"
	if n.contains("tree") or n.contains("canopy") or n.contains("trunk") or p.contains("multimesh"):
		return "tree_or_multimesh"
	if p.contains("chunk") or p.contains("shell") or n.begins_with("hit_"):
		return "building_chunk"
	if p.contains("street") or p.contains("prop") or n.contains("lamp") or n.contains("pole"):
		return "prop"
	return "other"


func _inventory(world: Node, car: VehicleBody3D) -> Array:
	var rows: Array = []
	_inv_walk(world, car.global_position if car else Vector3.ZERO, rows)
	rows.sort_custom(func(a, b): return float(a["dist_m"]) < float(b["dist_m"]))
	return rows


func _inv_walk(n: Node, car_pos: Vector3, rows: Array) -> void:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			var path := str(n.get_path())
			var nm := str(n.name)
			var pos := (n as Node3D).global_position if n is Node3D else Vector3.ZERO
			var wsize := Vector3.ZERO
			var wpos := pos
			if n is MeshInstance3D and (n as MeshInstance3D).mesh:
				var waabb: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).mesh.get_aabb()
				wsize = waabb.size
				wpos = waabb.get_center()
			elif n is MultiMeshInstance3D:
				wsize = Vector3(-1, -1, -1)  # instance count elsewhere
			rows.append({
				"path": path,
				"name": nm,
				"class": _classify(path, nm),
				"pos": [snapped(wpos.x, 0.01), snapped(wpos.y, 0.01), snapped(wpos.z, 0.01)],
				"aabb_m": [snapped(wsize.x, 0.01), snapped(wsize.y, 0.01), snapped(wsize.z, 0.01)],
				"cast": true,
				"dist_m": snapped(car_pos.distance_to(wpos), 0.1),
				"type": n.get_class(),
			})
	for c in n.get_children():
		_inv_walk(c, car_pos, rows)


func _write_inventory(rows: Array) -> void:
	var by := {}
	for r in rows:
		var k: String = r["class"]
		by[k] = int(by.get(k, 0)) + 1
	print("INV_BY_CLASS ", by)
	var path := ProjectSettings.globalize_path("res://docs/qa/67-shadow-caster-inventory.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"count": rows.size(), "by_class": by, "casters": rows}, "\t"))
		f.close()
		print("INV_FILE ", path)
	# Print nearest 40 for the log.
	for i in mini(40, rows.size()):
		var r: Dictionary = rows[i]
		print(
			"CASTER ", r["class"], " ", r["name"],
			" aabb=", r["aabb_m"],
			" dist=", r["dist_m"],
			" path=", r["path"]
		)


func _apply_vehicle_mode(car: Node, mode: String) -> void:
	var root_v := car.find_child("VisualRoot", true, false)
	if root_v == null:
		root_v = car
	var meshes: Array[MeshInstance3D] = []
	_collect_mi(root_v, meshes)
	# Also wheel meshes on VehicleWheel3D.
	_collect_mi(car, meshes)
	# Deduplicate by instance id
	var seen: Dictionary = {}
	var unique: Array[MeshInstance3D] = []
	for mi in meshes:
		var id := mi.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		unique.append(mi)

	match mode:
		"A":
			# Current production policy: top 2 car-sized world volumes.
			_mode_top_n(unique, 2)
			print("VEH_MODE A top2")
		"B":
			for mi in unique:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_disable_all_geometry_shadows(car)
			print("VEH_MODE B none")
		"C":
			_mode_single_chassis(unique)
			print("VEH_MODE C single")
		_:
			print("VEH_MODE unknown ", mode)


func _mode_top_n(meshes: Array[MeshInstance3D], n: int) -> void:
	var cands: Array = []
	for mi in meshes:
		var waabb := _waabb(mi)
		var plan := maxf(waabb.size.x, waabb.size.z)
		var tall := waabb.size.y
		var nm := str(mi.name).to_lower()
		if nm.contains("tire") or nm.contains("rim") or nm.contains("wheel"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		if plan < 1.2 or plan > 7.5 or tall < 0.35 or tall > 2.8:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		var vol := waabb.get_volume()
		if vol < 1.0 or vol > 45.0:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		cands.append({"mi": mi, "vol": vol, "plan": plan, "tall": tall, "aspect": plan / maxf(minf(waabb.size.x, waabb.size.z), 0.01)})
	cands.sort_custom(func(a, b): return float(a["vol"]) > float(b["vol"]))
	var keep: Dictionary = {}
	for i in mini(n, cands.size()):
		keep[(cands[i]["mi"] as MeshInstance3D).get_instance_id()] = true
		print("VEH_KEEP ", cands[i]["mi"].name, " vol=", snapped(float(cands[i]["vol"]), 0.01), " plan=", snapped(float(cands[i]["plan"]), 0.01))
	for mi in meshes:
		mi.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if keep.has(mi.get_instance_id())
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)


func _mode_single_chassis(meshes: Array[MeshInstance3D]) -> void:
	## Prefer elongated car plan (length >> width), not a near-square envelope blob.
	var best: MeshInstance3D = null
	var best_score := -1.0
	for mi in meshes:
		var waabb := _waabb(mi)
		var sx := waabb.size.x
		var sz := waabb.size.z
		var tall := waabb.size.y
		var plan_max := maxf(sx, sz)
		var plan_min := minf(sx, sz)
		if plan_max < 2.5 or plan_max > 6.5 or tall < 0.5 or tall > 2.2:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		if plan_min < 1.2 or plan_min > 2.8:
			# Reject near-square 5×5 envelopes (Object_10/22 style).
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		var aspect := plan_max / maxf(plan_min, 0.01)
		if aspect < 1.35:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		var score := waabb.get_volume() * aspect
		if score > best_score:
			best_score = score
			best = mi
	for mi in meshes:
		mi.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if mi == best
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
	if best:
		var w := _waabb(best)
		print("VEH_KEEP_SINGLE ", best.name, " size=", w.size, " score=", snapped(best_score, 0.01))
	else:
		print("VEH_KEEP_SINGLE none — all off")


func _waabb(mi: MeshInstance3D) -> AABB:
	if mi.mesh == null:
		return AABB()
	return mi.global_transform * mi.mesh.get_aabb()


func _collect_mi(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		_collect_mi(c, out)


func _print_vehicle_casters(car: Node) -> void:
	var on: Array = []
	_collect_on(car, on)
	print("VEH_CASTERS_ON ", on.size())
	for r in on:
		print("  ", r)


func _disable_all_geometry_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_disable_all_geometry_shadows(c)


func _collect_on(n: Node, out: Array) -> void:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			var size_s := "?"
			if n is MeshInstance3D and (n as MeshInstance3D).mesh:
				size_s = str(_waabb(n as MeshInstance3D).size)
			out.append("%s(%s) size=%s" % [n.name, n.get_class(), size_s])
	for c in n.get_children():
		_collect_on(c, out)
