extends SceneTree
## Headless geometry audit for Dhule + Mumbai placement clearance.
## Run: godot --headless --path D:\drivevicecity -s res://tools/placement_audit.gd

const OsmRoadBuilder = preload("res://scripts/osm_road_builder.gd")
const MumbaiCityBuilder = preload("res://scripts/mumbai_city_builder.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = await _audit_dhule() and ok
	ok = await _audit_mumbai() and ok
	print("PLACEMENT_AUDIT_RESULT=%s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _audit_dhule() -> bool:
	var map: Node3D = OsmRoadBuilder.new()
	root.add_child(map)
	await create_timer(0.5).timeout
	var samples: Array = map.get("_road_samples")
	if samples == null or (samples as Array).is_empty():
		printerr("DHULE_AUDIT_FAIL no road samples")
		map.queue_free()
		return false
	var tree_holder := map.get_node_or_null("TreeColliders")
	var trunk_cols := 0
	if tree_holder:
		trunk_cols = tree_holder.get_child_count()
	# Probe: no MultiMesh canopy transform origin should sit deep on asphalt.
	var on_road := 0
	var checked := 0
	for c in map.get_children():
		if c is MultiMeshInstance3D:
			var mmi := c as MultiMeshInstance3D
			if mmi.multimesh == null:
				continue
			var mm := mmi.multimesh
			var n := mini(mm.instance_count, 80)
			for i in n:
				var xf := mm.get_instance_transform(i)
				var p := xf.origin
				checked += 1
				if _depth_vs_samples(samples, p) > 1.5:
					on_road += 1
	print("dhule_audit samples=%d tree_cols=%d mm_checked=%d mm_deep_on_asphalt=%d" % [
		(samples as Array).size(), trunk_cols, checked, on_road
	])
	map.queue_free()
	# Canopy centres can overhang slightly; deep (>1.5 m into asphalt) is a defect.
	if on_road > checked / 4 and checked > 20:
		printerr("DHULE_AUDIT_FAIL too many canopy centres deep on asphalt")
		return false
	return true


func _audit_mumbai() -> bool:
	var map: Node3D = MumbaiCityBuilder.new()
	root.add_child(map)
	await create_timer(0.8).timeout
	var buildings := int(map.get("building_count"))
	var trees := int(map.get("tree_count"))
	var segs := int(map.get("road_segment_count"))
	var colliders := int(map.get("building_colliders"))
	print("mumbai_audit buildings=%d colliders=%d trees=%d segs=%d" % [buildings, colliders, trees, segs])
	if buildings < 80 or segs < 40:
		printerr("MUMBAI_AUDIT_FAIL low counts")
		map.queue_free()
		return false
	# Spot-check tree MultiMesh origins vs asphalt (not road StaticBodies — those sit on asphalt by design).
	var on_road := 0
	var checked := 0
	for c in map.get_children():
		if c is MultiMeshInstance3D:
			var mmi := c as MultiMeshInstance3D
			if mmi.multimesh == null:
				continue
			var mm := mmi.multimesh
			var n := mini(mm.instance_count, 60)
			for i in n:
				var xf := mm.get_instance_transform(i)
				checked += 1
				if map.has_method("_asphalt_edge_clearance"):
					var clr: float = map.call("_asphalt_edge_clearance", xf.origin.x, xf.origin.z)
					if clr < -0.5:
						on_road += 1
	print("mumbai_audit tree_mm_checked=%d deep_on_asphalt=%d" % [checked, on_road])
	map.queue_free()
	if checked > 10 and on_road > checked / 3:
		printerr("MUMBAI_AUDIT_FAIL trees deep on asphalt")
		return false
	return true


func _depth_vs_samples(samples: Array, pos: Vector3) -> float:
	var best := -100000.0
	var flat := Vector3(pos.x, 0.0, pos.z)
	for s_v in samples:
		var s: Vector3 = s_v
		var half: float = maxf(s.y, 3.5)
		var pen := half - flat.distance_to(Vector3(s.x, 0.0, s.z))
		if pen > best:
			best = pen
	return best
