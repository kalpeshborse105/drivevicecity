extends SceneTree
## Phase 2H.4B.3 — A/B identify dark patches: shadows vs ground overlays vs material.
## Usage: godot --path . --script res://scripts/dev/ground_surface_qa_probe.gd -- --mode=A|B|C|D|inv|drive


const RES := Vector2i(1280, 720)
const OUT := "res://docs/qa"


func _initialize() -> void:
	DisplayServer.window_set_size(RES)
	var mode := _arg_mode()
	print("GROUND_QA_MODE ", mode)
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for _i in 220:
		await process_frame

	var car := world.find_child("PlayerCar", true, false) as VehicleBody3D
	var cam := car.find_child("Camera3D", true, false) as Camera3D if car else null
	if cam:
		cam.current = true

	var inv := _inventory_ground(world, car.global_position if car else Vector3.ZERO)
	_write_json("%s/73-ground-surface-inventory.json" % OUT, {"mode": mode, "rows": inv})
	print("GROUND_INV rows=", inv.size())
	for r in inv:
		if float(r.get("dist_m", 999)) < 120.0:
			print(
				"NEAR ", snapped(float(r["dist_m"]), 0.1),
				" cast=", r["cast"],
				" ", r["kind"],
				" ", r["path"],
				" aabb=", r["aabb_m"],
				" mat=", r.get("mat", "")
			)

	match mode:
		"inv":
			print("GROUND_QA_DONE inv")
			quit()
			return
		"A":
			_set_sun_shadows(world, true)
			print("AB A shadows_on")
		"B":
			_set_sun_shadows(world, false)
			print("AB B shadows_off")
		"C":
			_set_sun_shadows(world, true)
			var hidden := _hide_ground_overlays(world)
			print("AB C overlays_hidden=", hidden)
		"D":
			_set_sun_shadows(world, true)
			var n := _neutral_ground_materials(world)
			print("AB D neutral_mats=", n)
		"drive":
			_set_sun_shadows(world, true)
			_force_afternoon(world)
		_:
			print("AB unknown ", mode)

	if mode in ["A", "C", "D"]:
		_force_afternoon(world)

	await _settle(10)
	_lock_chase(cam, car)
	await _settle(8)
	await _shot("%s/73-ab-%s.png" % [OUT, mode.to_lower()])

	if mode == "drive" or mode == "C":
		Input.action_press("accelerate")
		for step in 4:
			for _f in 40:
				await physics_frame
			_lock_chase(cam, car)
			await _settle(3)
			await _shot("%s/75-drive-%d.png" % [OUT, step + 1])
		Input.action_release("accelerate")
		await _sample_perf()

	print("GROUND_QA_DONE ", mode)
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
	cam.global_position = car.global_position - back * 9.0 + Vector3(0, 3.2, 0)
	cam.look_at(car.global_position + Vector3(0, 1.0, 0) + back * 5.0, Vector3.UP)


func _shot(path: String) -> void:
	for _i in 20:
		await process_frame
		var tex := root.get_viewport().get_texture()
		if tex:
			var img := tex.get_image()
			if img and img.get_width() > 0:
				img.save_png(ProjectSettings.globalize_path(path))
				print("SHOT ", path)
				return
	push_warning("SHOT_SKIP " + path)


func _set_sun_shadows(world: Node, on: bool) -> void:
	for n in _find_lights(world):
		var d := n as DirectionalLight3D
		if str(d.name).to_lower().contains("moon"):
			d.shadow_enabled = false
			continue
		d.shadow_enabled = on


func _force_afternoon(world: Node) -> void:
	## Keep QA stills comparable — live IST dusk turns the whole frame black.
	var vfx := world.find_child("VfxEnvironment", true, false)
	if vfx and vfx.has_method("apply_preset"):
		vfx.call("apply_preset", 1) # Sunny Noon
	for n in _find_lights(world):
		var d := n as DirectionalLight3D
		if str(d.name).to_lower().contains("moon"):
			continue
		d.light_energy = 1.35
		d.rotation_degrees = Vector3(-42.0, -50.0, 0.0)


func _find_lights(n: Node) -> Array:
	var out: Array = []
	if n is DirectionalLight3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_lights(c))
	return out


func _inventory_ground(world: Node, origin: Vector3) -> Array:
	var rows: Array = []
	_walk_ground(world, origin, rows)
	rows.sort_custom(func(a, b): return float(a["dist_m"]) < float(b["dist_m"]))
	return rows


func _walk_ground(n: Node, origin: Vector3, rows: Array) -> void:
	var path := str(n.get_path())
	var pl := path.to_lower()
	var nm := str(n.name).to_lower()
	var is_groundish := (
		"dhulemap" in pl
		or "horizon" in pl
		or "terrain" in pl
		or nm.contains("ground")
		or nm.contains("lot")
		or n is MultiMeshInstance3D
	)
	if n is GeometryInstance3D and is_groundish:
		var gi := n as GeometryInstance3D
		var pos := (n as Node3D).global_position if n is Node3D else Vector3.ZERO
		var aabb := Vector3.ZERO
		var y0 := pos.y
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var wa: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).mesh.get_aabb()
			aabb = wa.size
			y0 = wa.position.y
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
			var mm := (n as MultiMeshInstance3D).multimesh
			if mm.mesh:
				aabb = mm.mesh.get_aabb().size
			aabb.x *= 1.0 # instance scales live in transforms
		var mat_name := ""
		if gi.material_override:
			mat_name = gi.material_override.resource_name
			if mat_name == "" and gi.material_override is StandardMaterial3D:
				var sm := gi.material_override as StandardMaterial3D
				mat_name = "alb=%s rough=%.2f tex=%s" % [
					sm.albedo_color,
					sm.roughness,
					sm.albedo_texture != null,
				]
		var kind := "other"
		if "terrain3d" in pl or nm == "terrain3d":
			kind = "terrain3d"
		elif n is MultiMeshInstance3D:
			kind = "multimesh_box_batch"
		elif aabb.x > 500.0 or aabb.z > 500.0:
			kind = "ground_slab"
		elif y0 < 0.2 and aabb.y < 0.5:
			kind = "ground_overlay"
		rows.append({
			"path": path,
			"name": n.name,
			"kind": kind,
			"type": n.get_class(),
			"pos": [snapped(pos.x, 0.01), snapped(pos.y, 0.01), snapped(pos.z, 0.01)],
			"aabb_m": [snapped(aabb.x, 0.01), snapped(aabb.y, 0.01), snapped(aabb.z, 0.01)],
			"surface_y": snapped(y0, 0.01),
			"cast": gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"dist_m": snapped(origin.distance_to(pos), 0.1),
			"mat": mat_name,
			"visible": gi.visible,
		})
	for c in n.get_children():
		_walk_ground(c, origin, rows)


func _hide_ground_overlays(world: Node) -> int:
	## Hide thin MultiMesh box batches and non-slab ground overlays under DhuleMap.
	var n := 0
	var map := world.find_child("DhuleMap", true, false)
	if map == null:
		return 0
	n += _hide_overlay_walk(map)
	return n


func _hide_overlay_walk(n: Node) -> int:
	var count := 0
	if n is MultiMeshInstance3D:
		var mmi := n as MultiMeshInstance3D
		# Visual-only box batches from StreetKit.flush_box_batch — cast already off.
		if mmi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			var mm := mmi.multimesh
			var thin := false
			if mm and mm.mesh:
				# Unit box scaled in instance transforms; treat all map MMI with shadow off as overlay candidates.
				thin = true
			if thin and mmi.material_override is StandardMaterial3D:
				var sm := mmi.material_override as StandardMaterial3D
				# Keep road asphalt materials (dark grey ~0.75+)? Scrub/earth are mid greens/browns without textures.
				if sm.albedo_texture == null and sm.albedo_color.v < 0.55:
					mmi.visible = false
					count += 1
	elif n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh is BoxMesh:
			var sz: Vector3 = (mi.mesh as BoxMesh).size
			if sz.y <= 0.15 and maxf(sz.x, sz.z) >= 6.0 and mi.position.y < 0.2:
				mi.visible = false
				count += 1
	for c in n.get_children():
		count += _hide_overlay_walk(c)
	return count


func _neutral_ground_materials(world: Node) -> int:
	var n := 0
	var map := world.find_child("DhuleMap", true, false)
	if map == null:
		return 0
	var neutral := StandardMaterial3D.new()
	neutral.albedo_color = Color(0.55, 0.55, 0.52)
	neutral.roughness = 1.0
	n += _neutral_walk(map, neutral)
	return n


func _neutral_walk(n: Node, mat: Material) -> int:
	var count := 0
	if n is MultiMeshInstance3D or n is MeshInstance3D:
		var gi := n as GeometryInstance3D
		var path := str(n.get_path()).to_lower()
		if "road" in path or "mark" in path or "junction" in path:
			pass
		elif gi.material_override is StandardMaterial3D:
			var sm := gi.material_override as StandardMaterial3D
			# Retexture base ground slab + solid overlays only.
			if sm.albedo_texture != null or (sm.albedo_color.v < 0.7 and (n as Node3D).global_position.y < 0.3):
				gi.material_override = mat
				count += 1
	for c in n.get_children():
		count += _neutral_walk(c, mat)
	return count


func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
		print("GROUND_INV_FILE ", path)


func _sample_perf() -> void:
	var fps: Array[float] = []
	var draws: Array[float] = []
	for i in 40:
		await process_frame
		if i < 10:
			continue
		fps.append(Performance.get_monitor(Performance.TIME_FPS))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	fps.sort()
	draws.sort()
	print(
		"PERF ground_qa fps_med=", snapped(fps[fps.size() / 2], 0.1),
		" draws_med=", snapped(draws[draws.size() / 2], 1.0),
		" objects=", snapped(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), 1.0)
	)
