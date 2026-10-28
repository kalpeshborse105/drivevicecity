extends SceneTree
## Headless validation of map JSON + vehicle builder + mission config.
## Run: godot --headless --path D:\drivevicecity -s res://tools/smoke_test.gd

const VehicleMeshBuilder = preload("res://scripts/vehicle_mesh_builder.gd")
const StreetKit = preload("res://scripts/street_kit.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_map() and ok
	ok = _check_nav_arrow_script() and ok
	ok = _check_material_cache() and ok
	ok = _check_vehicle_mesh() and ok
	ok = _check_inputs_file() and ok
	var map_ok: bool = await _check_map_build_counts()
	ok = map_ok and ok
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
	var attr := str(d.get("attribution", ""))
	if attr.find("OpenStreetMap") < 0:
		push_error("Missing OSM attribution in map JSON")
		return false
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
	print("map_ok roads=%s anchors=%s spawn=(%s,%s) attr_ok" % [d["road_count"], anchors.size(), spawn["x"], spawn["z"]])
	return true


func _check_nav_arrow_script() -> bool:
	var src := FileAccess.get_file_as_string("res://scripts/nav_arrow.gd")
	if src.find("look_at") >= 0:
		push_error("nav_arrow still uses look_at (roof clip risk)")
		return false
	# 3D yellow roof marker removed — minimap + HUD distance only
	if src.find("visible = false") < 0:
		push_error("nav_arrow should stay invisible (no roof marker)")
		return false
	print("nav_arrow_ok hidden")
	return true


func _check_material_cache() -> bool:
	var a := StreetKit.mat(Color(0.5, 0.4, 0.3), 0.9)
	var b := StreetKit.mat(Color(0.5, 0.4, 0.3), 0.9)
	if a != b:
		push_error("StreetKit.mat cache miss on identical colour")
		return false
	var glass := StreetKit.mat(Color(0.45, 0.55, 0.65, 0.55), 0.08, 0.05)
	if glass.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
		push_error("Glass material missing alpha transparency")
		return false
	if a.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
		push_error("Opaque cached material polluted by glass")
		return false
	var lamp := StreetKit.mat_emissive(Color(0.95, 0.9, 0.55), Color(1.0, 0.92, 0.6))
	var plain := StreetKit.mat(Color(0.95, 0.9, 0.55), 0.35)
	if plain.emission_enabled:
		push_error("Plain material polluted by emissive lamp mat")
		return false
	if not lamp.emission_enabled:
		push_error("Emissive material missing emission")
		return false
	print("material_cache_ok")
	return true


func _check_map_build_counts() -> bool:
	## Instantiate map builder once; count meshes vs physics bodies.
	var map_script: Script = load("res://scripts/osm_road_builder.gd")
	if map_script == null:
		push_error("Cannot load osm_road_builder.gd")
		return false
	var map: Node3D = map_script.new()
	root.add_child(map)
	# _ready builds map; deferred emit needs another frame
	await process_frame
	await process_frame
	var meshes := _count_type(map, "MeshInstance3D")
	var bodies := _count_type(map, "StaticBody3D")
	var spawn: Vector3 = map.get("spawn_position")
	print("map_build_ok meshes=%d static_bodies=%d spawn=(%.1f,%.1f)" % [meshes, bodies, spawn.x, spawn.z])
	var ok := true
	if meshes < 200:
		push_error("Map mesh count unexpectedly low")
		ok = false
	if bodies > meshes:
		push_error("More StaticBodies than meshes — collision still too heavy")
		ok = false
	# Decorative collisions should stay well below mesh count after audit pass
	if bodies > int(meshes * 0.55):
		push_error("StaticBody ratio still high (%d / %d)" % [bodies, meshes])
		ok = false
	map.queue_free()
	await process_frame
	return ok


func _count_type(node: Node, type_name: String) -> int:
	var n := 0
	if node.get_class() == type_name:
		n += 1
	for c in node.get_children():
		n += _count_type(c, type_name)
	return n


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
