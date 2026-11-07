extends SceneTree
## Phase 2H.3.1 — production main.tscn smoke, drive, shadow, FPS.


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("MAIN_MISSING")
		quit(1)
		return
	var root_n := packed.instantiate()
	root.add_child(root_n)

	var t0 := Time.get_ticks_msec()
	for _i in 200:
		await process_frame
	print("BOOT_MS ", Time.get_ticks_msec() - t0)

	var car := root_n.find_child("PlayerCar", true, false) as VehicleBody3D
	var hud := root_n.find_child("HUD", true, false)
	var mm := root_n.find_child("Minimap", true, false)
	var garage := root_n.find_child("GaragePanel", true, false)
	print("HAS_CAR ", car != null, " HAS_HUD ", hud != null, " HAS_MINIMAP ", mm != null, " HAS_GARAGE ", garage != null)
	if car == null:
		quit(2)
		return

	print("SPAWN_CAR ", car.global_position)
	print(
		"CAR_EXPORTS mass=", car.mass,
		" engine=", car.get("engine_force_value"),
		" brake=", car.get("brake_force_value"),
		" steer=", car.get("steer_limit"),
		" vmax=", car.get("max_speed_kph"),
		" gear=", car.call("current_gear") if car.has_method("current_gear") else "?"
	)

	# Spawn screenshot (stationary).
	await _settle(12)
	await _shot("res://docs/qa/60-production-spawn.png")
	var spawn_fps: float = await _median_fps(24)
	var spawn_draws: float = await _median_draws(24)
	print("PERF_SPAWN fps_med ", spawn_fps, " draws_med ", spawn_draws)

	# Drive: accelerate, sample peak + FPS, then screenshot.
	Input.action_press("accelerate")
	var peak := 0.0
	for _j in 120:
		await physics_frame
		peak = maxf(peak, car.linear_velocity.length() * 3.6)
	print("DRIVE_PEAK_KPH ", snapped(peak, 0.1), " AT ", car.global_position, " gear=", car.call("current_gear"))
	var drive_fps: float = await _median_fps(20)
	print("PERF_DRIVE fps_med ", drive_fps)
	await _shot("res://docs/qa/60-production-driving.png")

	# Steer sample.
	Input.action_press("steer_left")
	for _k in 20:
		await physics_frame
	Input.action_release("steer_left")
	Input.action_release("accelerate")
	Input.action_press("brake")
	for _b in 30:
		await physics_frame
	Input.action_release("brake")
	print("AFTER_BRAKE_KPH ", snapped(car.linear_velocity.length() * 3.6, 0.1))

	# Near-building FPS: nudge toward denser Blosm if present.
	var near_fps := drive_fps
	var blosm := root_n.find_child("DhuleBlosmCity", true, false)
	if blosm == null:
		blosm = root_n.find_child("dhule_blosm_city", true, false)
	if blosm == null:
		blosm = root_n.find_child("dhule_city_osm_buildings", true, false)
	if blosm is Node3D:
		var target: Vector3 = (blosm as Node3D).global_position
		# Soft teleport near mesh origin while keeping Y.
		car.global_position = Vector3(target.x + 40.0, car.global_position.y, target.z + 40.0)
		car.linear_velocity = Vector3.ZERO
		await _settle(30)
		near_fps = await _median_fps(24)
		print("PERF_NEAR_BUILDINGS fps_med ", near_fps, " at ", car.global_position)
	else:
		print("PERF_NEAR_BUILDINGS skipped (no Blosm node)")

	var mem := Performance.get_monitor(Performance.MEMORY_STATIC)
	print("MEM_STATIC_MB ", snapped(mem / (1024.0 * 1024.0), 0.1))

	var casters := {"on": 0, "off": 0, "road_on": 0, "blosm_on": 0}
	_count_casters(root_n, casters)
	print(
		"SHADOW_CASTERS on=", casters["on"],
		" off=", casters["off"],
		" road_on=", casters["road_on"],
		" blosm_on=", casters["blosm_on"]
	)

	# Open garage briefly if present.
	if garage and garage.has_method("open") == false:
		# Toggle via HUD G action if wired.
		pass
	if InputMap.has_action("garage") or InputMap.has_action("toggle_garage"):
		var act := "garage" if InputMap.has_action("garage") else "toggle_garage"
		Input.action_press(act)
		await _settle(8)
		Input.action_release(act)
		print("GARAGE_TOGGLE tried via ", act, " visible=", garage.visible if garage else false)

	print("AUDIT_DONE")
	quit()


func _settle(n: int) -> void:
	for _i in n:
		await process_frame


func _median_fps(samples: int) -> float:
	var vals: Array[float] = []
	for i in samples:
		await process_frame
		if i < 6:
			continue
		vals.append(Performance.get_monitor(Performance.TIME_FPS))
	if vals.is_empty():
		return 0.0
	vals.sort()
	return snapped(vals[vals.size() / 2], 0.1)


func _median_draws(samples: int) -> float:
	var vals: Array[float] = []
	for i in samples:
		await process_frame
		if i < 6:
			continue
		vals.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if vals.is_empty():
		return 0.0
	vals.sort()
	return snapped(vals[vals.size() / 2], 1.0)


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)


func _count_casters(n: Node, acc: Dictionary) -> void:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		var on := gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if on:
			acc["on"] = int(acc["on"]) + 1
		else:
			acc["off"] = int(acc["off"]) + 1
		var nm := str(n.name).to_lower()
		var path := str(n.get_path()).to_lower()
		if on and (nm.contains("road") or path.contains("road") or nm.contains("junction") or nm.contains("crosswalk")):
			acc["road_on"] = int(acc["road_on"]) + 1
		if on and (nm.contains("blosm") or path.contains("blosm") or path.contains("dhule_city")):
			acc["blosm_on"] = int(acc["blosm_on"]) + 1
	for c in n.get_children():
		_count_casters(c, acc)
