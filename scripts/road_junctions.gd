extends RefCounted
## Junctions taken from the playable centre lines.
## Source coordinates are not moved. A disc is added only where two or more
## ways already meet at an angle, so straight splits stay as plain ribbons.

const JOIN_M := 4.2
const STRAIGHT_DEG := 18.0

static var clips: Array = []
static var summary: String = ""


static func prepare(roads: Array) -> int:
	clips = []
	var ends: Array[Dictionary] = []
	for road_v in roads:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		if pts.size() < 2:
			continue
		var closed := _same_point(pts[0], pts[pts.size() - 1])
		var width := float(road.get("width", 7.0))
		var hw := str(road.get("highway", ""))
		var major := hw in ["primary", "secondary", "tertiary", "trunk", "trunk_link", "motorway"]
		var spot: Array[int] = [0]
		if not closed:
			spot.append(pts.size() - 1)
		for ei in spot:
			var here: Array = pts[ei]
			var other: Array = pts[1] if ei == 0 else pts[pts.size() - 2]
			var direction := Vector2(float(other[0]) - float(here[0]), float(other[1]) - float(here[1]))
			if direction.length() < 0.2:
				continue
			ends.append({
				"p": Vector2(float(here[0]), float(here[1])),
				"dir": direction.normalized(),
				"seg": direction.length(),
				"w": width,
				"id": str(road.get("id", "")),
				"major": major,
			})
	var used := {}
	var straight := 0
	var bends := 0
	var corners := 0
	var three := 0
	var four := 0
	for i in ends.size():
		if used.has(i):
			continue
		var group: Array[int] = [i]
		used[i] = true
		var k := 0
		while k < group.size():
			var gp: Vector2 = ends[group[k]]["p"]
			for j in ends.size():
				if used.has(j):
					continue
				if gp.distance_to(ends[j]["p"]) <= JOIN_M:
					used[j] = true
					group.append(j)
			k += 1
		var ids := {}
		for gi in group:
			ids[str(ends[gi]["id"])] = true
		if ids.size() < 2:
			continue
		var max_ang := 0.0
		for a in group.size():
			for b in range(a + 1, group.size()):
				var dot := absf((ends[group[a]]["dir"] as Vector2).dot(ends[group[b]]["dir"]))
				max_ang = maxf(max_ang, rad_to_deg(acos(clampf(dot, -1.0, 1.0))))
		var centre := Vector2.ZERO
		var is_major := false
		var arms: Array[Dictionary] = []
		for gi in group:
			var arm: Dictionary = ends[gi]
			centre += arm["p"]
			is_major = is_major or bool(arm["major"])
			arms.append(arm)
		centre /= float(group.size())
		arms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var da: Vector2 = a["dir"]
			var db: Vector2 = b["dir"]
			return atan2(da.y, da.x) < atan2(db.y, db.x)
		)
		var max_half := 1.2
		for arm in arms:
			max_half = maxf(max_half, float(arm["w"]) * 0.5)
		for ai in arms.size():
			var prev: Dictionary = arms[(ai + arms.size() - 1) % arms.size()]
			var nxt: Dictionary = arms[(ai + 1) % arms.size()]
			var gap := minf(_heading_gap(arms[ai]["dir"], prev["dir"]), _heading_gap(arms[ai]["dir"], nxt["dir"]))
			var half_w := float(arms[ai]["w"]) * 0.5
			# Pull tips farther so ribbons stop under the join pad (kills blink).
			var pull := 0.7
			if gap > 2.6:
				pull = 0.65
			elif gap < 0.28:
				pull = half_w * 0.55
			else:
				pull = clampf(half_w / tan(gap * 0.5) + 0.35, 0.7, max_half + 1.2)
			arms[ai]["pull"] = minf(pull, float(arms[ai]["seg"]) * 0.85)
		clips.append({"c": centre, "r": max_half, "major": is_major, "disc": true, "arms": arms})
		if ids.size() == 2 and max_ang < STRAIGHT_DEG:
			straight += 1
		elif ids.size() >= 4:
			four += 1
		elif ids.size() == 3:
			three += 1
		elif max_ang >= 50.0:
			corners += 1
		else:
			bends += 1
	var arms := _roundabout_arms(roads, ends)
	summary = "straight %d bends %d corners %d three %d four %d arms %d" % [straight, bends, corners, three, four, arms]
	return clips.size()


static func _roundabout_arms(roads: Array, ends: Array[Dictionary]) -> int:
	var rings: Array[Dictionary] = []
	for road_v in roads:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		if pts.size() < 6 or not _same_point(pts[0], pts[pts.size() - 1]):
			continue
		rings.append({
			"pts": pts,
			"id": str(road.get("id", "")),
			"half": float(road.get("width", 9.0)) * 0.5,
			"major": str(road.get("highway", "")) in ["primary", "secondary", "tertiary", "trunk", "trunk_link", "motorway"],
		})
	var added := 0
	for end in ends:
		var p: Vector2 = end["p"]
		for ring_v in rings:
			var ring: Dictionary = ring_v
			if str(end["id"]) == str(ring["id"]):
				continue
			var pts: Array = ring["pts"]
			var near := false
			for i in pts.size() - 1:
				if _point_segment(p, Vector2(float(pts[i][0]), float(pts[i][1])), Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))) < 2.2:
					near = true
					break
			if not near:
				continue
			clips.append({"c": p, "r": float(ring["half"]), "major": bool(ring["major"]) or bool(end["major"]), "disc": false})
			added += 1
			break
	return added


static func _point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var den := ab.length_squared()
	var t := 0.0 if den == 0.0 else clampf((p - a).dot(ab) / den, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func trim(points: Array[Vector3], closed: bool) -> Array[Vector3]:
	if closed or clips.is_empty() or points.size() < 2:
		return points
	var raw: Array = []
	for p in points:
		raw.append(p)
	raw = _trim_end(raw, true)
	raw = _trim_end(raw, false)
	var out: Array[Vector3] = []
	for p in raw:
		out.append(p)
	if out.size() < 2:
		return points
	return out


static func _heading_gap(a: Vector2, b: Vector2) -> float:
	return acos(clampf(a.normalized().dot(b.normalized()), -1.0, 1.0))


static func _trim_end(pts: Array, at_start: bool) -> Array:
	if pts.size() < 2:
		return pts
	var end: Vector3 = pts[0] if at_start else pts[pts.size() - 1]
	var flat := Vector2(end.x, end.z)
	var pull := 0.0
	var best_r := 0.0
	var best_c := Vector2.ZERO
	var arm_hit := false
	for jv in clips:
		var j: Dictionary = jv
		if j.has("arms"):
			for arm_v in j["arms"]:
				var arm: Dictionary = arm_v
				if flat.distance_to(arm["p"]) <= 2.4:
					pull = maxf(pull, float(arm["pull"]) + 0.25)
					arm_hit = true
			continue
		var c: Vector2 = j["c"]
		var radius := float(j["r"])
		if flat.distance_to(c) <= radius + 0.35 and radius > best_r:
			best_r = radius
			best_c = c
	if arm_hit:
		return _pull_tip(pts, at_start, pull)
	if best_r <= 0.0:
		return pts
	var guard := 0
	while pts.size() > 2 and guard < 8:
		guard += 1
		var tip: Vector3 = pts[0] if at_start else pts[pts.size() - 1]
		if Vector2(tip.x, tip.z).distance_to(best_c) >= best_r - 0.05:
			break
		if at_start:
			pts.remove_at(0)
		else:
			pts.remove_at(pts.size() - 1)
	if pts.size() < 2:
		return pts
	var tip2: Vector3 = pts[0] if at_start else pts[pts.size() - 1]
	var inner: Vector3 = pts[1] if at_start else pts[pts.size() - 2]
	var edge := _circle_point(tip2, inner, best_c, best_r - 0.08)
	if at_start:
		pts[0] = edge
	else:
		pts[pts.size() - 1] = edge
	return pts


static func _pull_tip(pts: Array, at_start: bool, pull: float) -> Array:
	var remain := 0.0
	for i in pts.size() - 1:
		remain += (pts[i] as Vector3).distance_to(pts[i + 1])
	pull = minf(pull, remain * 0.45)
	if pull < 0.05:
		return pts
	var left := pull
	while pts.size() > 2 and left > 0.0:
		var tip: Vector3 = pts[0] if at_start else pts[pts.size() - 1]
		var nxt: Vector3 = pts[1] if at_start else pts[pts.size() - 2]
		var seg := tip.distance_to(nxt)
		if seg > left + 0.01:
			var moved := tip.lerp(nxt, left / seg)
			if at_start:
				pts[0] = moved
			else:
				pts[pts.size() - 1] = moved
			return pts
		left -= seg
		if at_start:
			pts.remove_at(0)
		else:
			pts.remove_at(pts.size() - 1)
	return pts


static func _circle_point(inside: Vector3, outside: Vector3, centre: Vector2, radius: float) -> Vector3:
	var a := Vector2(inside.x, inside.z)
	var b := Vector2(outside.x, outside.z)
	var lo := 0.0
	var hi := 1.0
	for _i in 8:
		var mid := (lo + hi) * 0.5
		var p := a.lerp(b, mid)
		if p.distance_to(centre) < radius:
			lo = mid
		else:
			hi = mid
	var on := a.lerp(b, hi)
	return Vector3(on.x, inside.y, on.y)


static func _same_point(a, b) -> bool:
	return Vector2(float(a[0]), float(a[1])).distance_to(Vector2(float(b[0]), float(b[1]))) < 0.5
