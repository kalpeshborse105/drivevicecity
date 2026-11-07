extends RefCounted
## Phase 2H.3 — keep useful shadows, kill road/marking/terrain casters and giant-mesh flicker.


static var last_report: Dictionary = {}


static func apply_after_roads(map_root: Node) -> void:
	if map_root == null:
		return
	var root := map_root
	while root.get_parent() != null and root.get_parent() is Node3D:
		root = root.get_parent()
	var stats := {
		"roads_off": 0,
		"marks_off": 0,
		"blosm_buildings": 0,
		"blosm_shadow_mode": "",
		"lights_tuned": 0,
		"casters_on": 0,
	}
	_walk(map_root, stats)
	_tune_lights(root, stats)
	last_report = stats
	print(
		"SHADOW policy roads_off=", stats["roads_off"],
		" marks_off=", stats["marks_off"],
		" blosm=", stats["blosm_shadow_mode"],
		" lights=", stats["lights_tuned"],
		" casters_on≈", stats["casters_on"]
	)


static func diagnose(root: Node, cam: Camera3D = null) -> Array:
	## Temporary diagnostic list of shadow casters near the camera.
	var out: Array = []
	_diag_walk(root, cam, out)
	out.sort_custom(func(a, b): return float(a.get("dist", 0)) < float(b.get("dist", 0)))
	return out


static func _is_blosm_buildings(n: Node, nm: String) -> bool:
	if "dhule_city.osm_buildings" in nm or "dhule_city_osm_buildings" in nm:
		return true
	if nm.contains("buildings") and n.get_parent() != null and str(n.get_parent().name) == "DhuleBlosmCity":
		return true
	return false


static func _walk(n: Node, stats: Dictionary) -> void:
	var nm := str(n.name).to_lower()
	if n is MeshInstance3D or n is MultiMeshInstance3D:
		var gi := n as GeometryInstance3D
		if nm in ["roads", "road", "road_marks", "junction", "roundabout_island", "roundabout_kerb"] or nm.begins_with("kit_road_crossing"):
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if "mark" in nm or "junction" in nm or "crossing" in nm:
				stats["marks_off"] = int(stats["marks_off"]) + 1
			else:
				stats["roads_off"] = int(stats["roads_off"]) + 1
		elif _is_blosm_buildings(n, nm):
			stats["blosm_buildings"] = int(stats["blosm_buildings"]) + 1
			var aabb := (n as MeshInstance3D).get_aabb() if n is MeshInstance3D else AABB()
			var plan := maxf(aabb.size.x, aabb.size.z)
			# Joined city mesh spans kilometres — cascade shadows flicker on empty ground.
			if plan > 1500.0:
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				stats["blosm_shadow_mode"] = "off_giant_aabb_%.0fm" % plan
			else:
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				stats["blosm_shadow_mode"] = "on"
				stats["casters_on"] = int(stats["casters_on"]) + 1
		elif "water" in nm or "dhule_city_osm_water" in nm:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			stats["casters_on"] = int(stats["casters_on"]) + 1
	if n.has_method("set") and n.get("cast_shadows") != null and nm.contains("terrain"):
		n.set("cast_shadows", RenderingServer.SHADOW_CASTING_SETTING_OFF)
	for c in n.get_children():
		_walk(c, stats)


static func _tune_lights(root: Node, stats: Dictionary) -> void:
	for n in _find_lights(root):
		var light := n as DirectionalLight3D
		light.shadow_enabled = true
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		light.directional_shadow_max_distance = 110.0
		light.directional_shadow_split_1 = 0.08
		light.directional_shadow_split_2 = 0.22
		light.directional_shadow_split_3 = 0.5
		light.shadow_bias = 0.04
		light.shadow_normal_bias = 1.2
		light.directional_shadow_pancake_size = 4.0
		stats["lights_tuned"] = int(stats["lights_tuned"]) + 1


static func _find_lights(n: Node) -> Array:
	var out: Array = []
	if n is DirectionalLight3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_lights(c))
	return out


static func _diag_walk(n: Node, cam: Camera3D, out: Array) -> void:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			var pos := Vector3.ZERO
			if n is Node3D:
				pos = (n as Node3D).global_position
			var dist := 0.0
			var in_range := true
			if cam:
				dist = cam.global_position.distance_to(pos)
				in_range = dist < 120.0
			var aabb := AABB()
			if n is MeshInstance3D and (n as MeshInstance3D).mesh:
				aabb = (n as MeshInstance3D).get_aabb()
			out.append({
				"path": str(n.get_path()),
				"name": n.name,
				"pos": pos,
				"aabb": aabb.size,
				"cast_shadow": true,
				"dist": snapped(dist, 0.1),
				"in_shadow_range": in_range,
			})
	for c in n.get_children():
		_diag_walk(c, cam, out)
