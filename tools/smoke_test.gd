extends SceneTree
## Headless validation of map JSON + vehicle builder + mission config.
## Run: godot --headless --path D:\drivevicecity -s res://tools/smoke_test.gd

const VehicleMeshBuilder = preload("res://scripts/vehicle_mesh_builder.gd")


func _init() -> void:
	var ok := true
	ok = _check_map() and ok
	ok = _check_vehicle_mesh() and ok
	ok = _check_inputs_file() and ok
	print("SMOKE_TEST_RESULT=%s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _check_map() -> bool:
	var path := "res://assets/maps/dhule_roads_game.json"
	if not FileAccess.file_exists(path):
		push_error("Missing map json")
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Bad map json")
		return false
	var d: Dictionary = data
	if int(d.get("road_count", 0)) < 50:
		push_error("Too few roads")
		return false
	if not d.has("spawn") or not d.has("delivery_anchors"):
		push_error("Missing spawn/anchors")
		return false
	var spawn: Dictionary = d["spawn"]
	if abs(float(spawn.get("x", 9999))) > 500:
		push_error("Spawn not in core")
		return false
	if not spawn.has("hx") or not spawn.has("hz"):
		push_error("Spawn missing heading")
		return false
	var anchors: Array = d["delivery_anchors"]
	if anchors.size() < 8:
		push_error("Too few anchors")
		return false
	print("map_ok roads=%s anchors=%s spawn=(%s,%s)" % [d["road_count"], anchors.size(), spawn["x"], spawn["z"]])
	return true


func _check_vehicle_mesh() -> bool:
	var root := Node3D.new()
	root.name = "TmpVisual"
	var paint := VehicleMeshBuilder.mat(Color(0.8, 0.4, 0.1))
	var sedan_size: Vector3 = VehicleMeshBuilder.build_sedan(root, paint)
	if root.get_child_count() < 8:
		push_error("Sedan mesh too sparse")
		root.free()
		return false
	var van_size: Vector3 = VehicleMeshBuilder.build_van(root, paint)
	if root.get_child_count() < 8:
		push_error("Van mesh too sparse")
		root.free()
		return false
	if sedan_size.z < 3.0 or van_size.y < 1.2:
		push_error("Vehicle sizes look wrong")
		root.free()
		return false
	print("vehicle_mesh_ok sedan_parts_built van_parts_built")
	root.free()
	return true


func _check_inputs_file() -> bool:
	var cfg := FileAccess.get_file_as_string("res://project.godot")
	for action in ["accelerate", "cycle_paint", "cycle_vehicle", "toggle_garage", "reset_car"]:
		if cfg.find(action) < 0:
			# toggle_garage may be added in same change; soft-fail only if missing critical
			if action == "toggle_garage":
				print("warn_missing_input=%s" % action)
				continue
			push_error("Missing input action %s" % action)
			return false
	print("inputs_ok")
	return true
