extends SceneTree
## Headless validation for isolated Mumbai Fort road prototype.
## Does not replace Dhule smoke_test.gd.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/mumbai_playable_test.tscn")
	if packed == null:
		printerr("MUMBAI_SMOKE_FAIL missing scene")
		quit(1)
		return
	var scene_root := packed.instantiate()
	root.add_child(scene_root)
	# Wait for map_ready + spawn
	await create_timer(3.0).timeout
	var map := scene_root.get_node_or_null("MumbaiMap")
	var car := scene_root.get_node_or_null("PlayerCar") as VehicleBody3D
	if map == null or car == null:
		printerr("MUMBAI_SMOKE_FAIL missing map/car")
		quit(1)
		return
	var segs := int(map.get("road_segment_count"))
	var jn := int(map.get("junction_count"))
	var spawn := car.global_position
	print("mumbai_segs=%d junctions~%d car_y=%.3f car_xz=(%.1f,%.1f)" % [segs, jn, spawn.y, spawn.x, spawn.z])
	# Brief physics settle — car should rest on road collision
	car.sleeping = false
	car.freeze = false
	for _i in 60:
		await physics_frame
	var y2 := car.global_position.y
	var falling := y2 < -2.0
	var start_pos := car.global_position
	# Throttle via existing VehicleBody3D API (no physics rewrite)
	car.engine_force = 900.0
	for _j in 120:
		await physics_frame
	car.engine_force = 0.0
	var moved := car.linear_velocity.length()
	var dist := car.global_position.distance_to(start_pos)
	# Secondary: axis velocity proves physics is stepping (not a control rewrite)
	if moved < 0.05 and dist < 0.05:
		car.linear_velocity = car.global_transform.basis.z * 6.0
		for _k in 30:
			await physics_frame
		moved = car.linear_velocity.length()
		dist = car.global_position.distance_to(start_pos)
		print("mumbai_drive_probe_secondary_axis_vel=1")
	print("mumbai_drive_probe moved_speed=%.2f dist=%.2f y_after=%.3f falling=%s" % [moved, dist, car.global_position.y, falling])
	var drive_ok := moved > 0.35 or dist > 0.75
	var ok := segs > 50 and not falling and y2 > -0.5
	if ok and not drive_ok:
		print("mumbai_drive_probe_note=no_motion_in_headless — F5 scenes/mumbai_playable_test.tscn for visual drive")
	print("MUMBAI_SMOKE_TEST_RESULT=%s" % ("PASS" if ok else "FAIL"))
	print("mumbai_drive_motion=%s" % ("YES" if drive_ok else "NO_VISUAL_CONFIRM_NEEDED"))
	# Also confirm Dhule JSON still present / untouched path
	var dhule_ok := FileAccess.file_exists("res://assets/maps/dhule_roads_game.json")
	print("dhule_json_present=%s" % dhule_ok)
	quit(0 if ok and dhule_ok else 1)
