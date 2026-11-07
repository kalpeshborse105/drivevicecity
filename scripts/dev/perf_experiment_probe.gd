extends SceneTree
## Phase 2H.4A — isolated production experiments (one flag via -- --exp=NAME).
## Names: baseline | vehicle_shadows | minimap_throttle | shadow_distance | blosm_off


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var exp := _exp_name()
	print("EXP_NAME ", exp)
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for _i in 200:
		await process_frame

	var car := world.find_child("PlayerCar", true, false) as VehicleBody3D
	var cam := car.find_child("Camera3D", true, false) as Camera3D
	if cam:
		cam.current = true
	car.engine_force = 0.0
	car.brake = 35.0
	car.linear_velocity = Vector3.ZERO
	if car.has_method("set_physics_process"):
		car.set_physics_process(false)

	match exp:
		"vehicle_shadows":
			_vehicle_shadow_opt(car)
		"minimap_throttle":
			_minimap_throttle(world)
		"shadow_distance":
			_shadow_distance(world, 60.0)
		"blosm_off":
			var b := world.find_child("DhuleBlosmCity", true, false)
			if b is Node3D:
				(b as Node3D).visible = false
				print("EXP blosm hidden (reversible)")
		_:
			print("EXP baseline (no change)")

	await _settle(16)
	var spawn := car.global_position
	var heading := -car.global_transform.basis.z
	heading.y = 0.0
	if heading.length() < 0.1:
		heading = Vector3(0, 0, -1)
	heading = heading.normalized()
	if cam:
		cam.global_position = spawn + Vector3(0, 3.2, 0) - heading * 8.5 + Vector3(0, 1.2, 0)
		cam.look_at(spawn + heading * 12.0 + Vector3(0, 1.0, 0), Vector3.UP)
	await _settle(10)
	await _sample("spawn")
	# Long road
	if cam:
		cam.global_position = spawn + Vector3(0, 4.5, 0) - heading * 4.0
		cam.look_at(spawn + heading * 120.0 + Vector3(0, 1.0, 0), Vector3.UP)
	await _settle(8)
	await _sample("long_road")
	print("EXP_DONE ", exp)
	quit()


func _exp_name() -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--exp="):
			return str(a).substr(6)
	return "baseline"


func _vehicle_shadow_opt(car: Node) -> void:
	## Keep shadow on the single largest MeshInstance under VisualRoot; disable the rest.
	var root_v := car.find_child("VisualRoot", true, false)
	if root_v == null:
		root_v = car
	var best: MeshInstance3D = null
	var best_vol := -1.0
	var all: Array[MeshInstance3D] = []
	_collect_mi(root_v, all)
	for mi in all:
		if mi.mesh == null:
			continue
		var vol := mi.get_aabb().get_volume()
		if vol > best_vol:
			best_vol = vol
			best = mi
	var n_off := 0
	for mi in all:
		if mi == best:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		else:
			if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				n_off += 1
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("EXP vehicle_shadows kept=", best.name if best else "-", " disabled=", n_off, " total_mi=", all.size())


func _collect_mi(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		_collect_mi(c, out)


func _minimap_throttle(world: Node) -> void:
	var mm := world.find_child("Minimap", true, false)
	if mm == null:
		print("EXP minimap missing")
		return
	var vp := mm.find_child("SubViewport", true, false) as SubViewport
	if vp == null:
		return
	# Disable continuous world re-draw; update once then pause (probe measures steady state).
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	print("EXP minimap SubViewport UPDATE_DISABLED")


func _shadow_distance(world: Node, dist: float) -> void:
	var n := 0
	for light in _lights(world):
		(light as DirectionalLight3D).directional_shadow_max_distance = dist
		n += 1
	print("EXP shadow_distance ", dist, " lights=", n)


func _lights(n: Node) -> Array:
	var out: Array = []
	if n is DirectionalLight3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_lights(c))
	return out


func _settle(n: int) -> void:
	for _i in n:
		await process_frame


func _sample(tag: String) -> void:
	var fps: Array[float] = []
	var draws: Array[float] = []
	var prims: Array[float] = []
	var ft: Array[float] = []
	for i in 32:
		await process_frame
		if i < 8:
			continue
		fps.append(Performance.get_monitor(Performance.TIME_FPS))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		ft.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	fps.sort()
	draws.sort()
	prims.sort()
	ft.sort()
	print(
		"EXP_PERF ", tag,
		" fps_med=", snapped(fps[fps.size() / 2], 0.1),
		" fps_min=", snapped(fps[0], 0.1),
		" ft_med_ms=", snapped(ft[ft.size() / 2], 0.1),
		" draws_med=", snapped(draws[draws.size() / 2], 1.0),
		" prims_med=", snapped(prims[prims.size() / 2], 1.0)
	)
