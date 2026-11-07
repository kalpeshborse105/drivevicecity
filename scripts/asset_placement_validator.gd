extends RefCounted
## Rejects static props that overlap asphalt, junctions, or float off the ground.


const AssetKit = preload("res://scripts/asset_kit.gd")

const ROAD_MARGIN_M := 0.5
const FLOAT_EPS_M := 0.25
const BURY_EPS_M := 0.6


static func asphalt_clearance(aabb: AABB, road_segments: Array) -> float:
	var poly := _aabb_footprint(aabb)
	var best := 1.0e9
	for p in poly:
		best = minf(best, _point_clearance(p, road_segments))
	best = minf(best, _point_clearance(Vector2(aabb.position.x + aabb.size.x * 0.5, aabb.position.z + aabb.size.z * 0.5), road_segments))
	return best


static func validate_node(
	node: Node3D,
	road_segments: Array,
	opts: Dictionary = {}
) -> Dictionary:
	var aabb := AssetKit.mesh_aabb(node)
	var margin := float(opts.get("margin", ROAD_MARGIN_M))
	var report := {
		"ok": true,
		"reason": "ok",
		"clearance": 0.0,
		"aabb": aabb,
		"floating": false,
		"buried": false,
		"road_overlap": false,
	}
	if aabb.size.length() < 0.02:
		report["ok"] = false
		report["reason"] = "empty_mesh"
		return report
	var clear := asphalt_clearance(aabb, road_segments)
	report["clearance"] = snapped(clear, 0.01)
	if clear < margin:
		report["ok"] = false
		report["reason"] = "road_overlap"
		report["road_overlap"] = true
		return report
	var ground_y := float(opts.get("ground_y", 0.0))
	var bottom := aabb.position.y
	if bottom > ground_y + FLOAT_EPS_M:
		report["ok"] = false
		report["reason"] = "floating"
		report["floating"] = true
		return report
	if bottom < ground_y - BURY_EPS_M:
		report["ok"] = false
		report["reason"] = "buried"
		report["buried"] = true
		return report
	var max_plan := float(opts.get("max_plan_m", 20.0))
	if maxf(aabb.size.x, aabb.size.z) > max_plan:
		report["ok"] = false
		report["reason"] = "oversized_plan"
		return report
	var max_h := float(opts.get("max_height_m", 12.0))
	if aabb.size.y > max_h:
		report["ok"] = false
		report["reason"] = "oversized_height"
		return report
	var buildings: Array = opts.get("buildings", [])
	if not buildings.is_empty() and _overlaps_any_footprint(aabb, buildings, float(opts.get("building_margin", 0.25))):
		report["ok"] = false
		report["reason"] = "building_overlap"
		return report
	var neighbours: Array = opts.get("neighbours", [])
	if not neighbours.is_empty() and _overlaps_any_aabb(aabb, neighbours, float(opts.get("neighbour_margin", 0.2))):
		report["ok"] = false
		report["reason"] = "neighbour_overlap"
		return report
	return report


static func segments_from_roads(roads: Array, origin: Vector2 = Vector2.ZERO, radius: float = 1.0e9) -> Array:
	var out: Array = []
	for road_v in roads:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		var half := float(road.get("width", 7.0)) * 0.5
		for i in range(pts.size() - 1):
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			if origin != Vector2.ZERO and a.distance_to(origin) > radius and b.distance_to(origin) > radius:
				continue
			out.append({"a": a, "b": b, "half": half})
	return out


static func _aabb_footprint(aabb: AABB) -> PackedVector2Array:
	var x0 := aabb.position.x
	var z0 := aabb.position.z
	var x1 := x0 + aabb.size.x
	var z1 := z0 + aabb.size.z
	return PackedVector2Array([
		Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)
	])


static func _point_clearance(p: Vector2, segments: Array) -> float:
	var best := 1.0e9
	for seg_v in segments:
		var seg: Dictionary = seg_v
		var a: Vector2 = seg["a"]
		var b: Vector2 = seg["b"]
		var half := float(seg["half"])
		var ab := b - a
		var den := ab.length_squared()
		var t := 0.0 if den == 0.0 else clampf((p - a).dot(ab) / den, 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t) - half)
	return best


static func _overlaps_any_footprint(aabb: AABB, footprints: Array, margin: float) -> bool:
	## footprints: Array of PackedVector2Array or Array[Vector2] rings in XZ.
	var poly := _aabb_footprint(aabb)
	for ring_v in footprints:
		var ring: PackedVector2Array = PackedVector2Array(ring_v) if typeof(ring_v) != TYPE_PACKED_VECTOR2_ARRAY else ring_v
		if ring.size() < 3:
			continue
		for p in poly:
			if _point_in_ring(p, ring, margin):
				return true
		for q in ring:
			if aabb.has_point(Vector3(q.x, aabb.position.y + aabb.size.y * 0.5, q.y)):
				return true
	return false


static func _overlaps_any_aabb(aabb: AABB, others: Array, margin: float) -> bool:
	var grown := aabb.grow(margin)
	for other_v in others:
		var other: AABB = other_v
		if grown.intersects(other):
			return true
	return false


static func _point_in_ring(p: Vector2, ring: PackedVector2Array, margin: float) -> bool:
	## Expand ring edges by margin, then even-odd fill.
	if margin > 0.0:
		for i in ring.size():
			var a: Vector2 = ring[i]
			var b: Vector2 = ring[(i + 1) % ring.size()]
			var ab := b - a
			var den := ab.length_squared()
			var t := 0.0 if den == 0.0 else clampf((p - a).dot(ab) / den, 0.0, 1.0)
			if p.distance_to(a + ab * t) <= margin:
				return true
	var inside := false
	var j := ring.size() - 1
	for i in ring.size():
		var pi: Vector2 = ring[i]
		var pj: Vector2 = ring[j]
		if ((pi.y > p.y) != (pj.y > p.y)) and (p.x < (pj.x - pi.x) * (p.y - pi.y) / maxf(pj.y - pi.y, 0.0001) + pi.x):
			inside = not inside
		j = i
	return inside
