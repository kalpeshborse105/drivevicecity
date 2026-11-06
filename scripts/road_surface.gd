extends RefCounted
## Continuous road ribbons for the playable OSM centre lines.
## One mesh per way. U increases along the way so the texture does not flip
## at each bend. Decks are not extended past the centre line, so neighbours
## do not stack and shimmer.

const TILE_M := 8.0
const RoadJunctions = preload("res://scripts/road_junctions.gd")

static var _batch_parent: Node3D
static var _decks: Dictionary = {}
static var _marks: Dictionary = {}


static func begin_batch(parent: Node3D) -> void:
	_batch_parent = parent
	_decks = {}
	_marks = {}


static func flush_batch() -> int:
	if _batch_parent == null:
		return 0
	var count := 0
	for key in _decks:
		count += _commit_batched(_decks[key]["tool"], _decks[key]["mat"], "roads")
	for key in _marks:
		count += _commit_batched(_marks[key]["tool"], _marks[key]["mat"], "road_marks")
	_batch_parent = null
	_decks = {}
	_marks = {}
	return count


static func _tool_for(store: Dictionary, mat: Material) -> SurfaceTool:
	var id := mat.get_instance_id()
	if not store.has(id):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		store[id] = {"tool": st, "mat": mat}
	return store[id]["tool"]


static func _commit_batched(tool: SurfaceTool, mat: Material, node_name: String) -> int:
	var mesh := tool.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_batch_parent.add_child(mi)
	return 1


static func road_key(value) -> String:
	if value is String:
		return value
	return str(int(round(float(value))))


static func is_roundabout(road_id: String) -> bool:
	return road_id == "217392930" or road_id == "883678059" or road_id == "887725187"


static func add_way(parent: Node3D, pts: Array, width: float, y: float, asphalt: Material, paint: Material, highway: String) -> void:
	var closed := false
	if pts.size() >= 4:
		var a := Vector2(float(pts[0][0]), float(pts[0][1]))
		var b := Vector2(float(pts[pts.size() - 1][0]), float(pts[pts.size() - 1][1]))
		closed = a.distance_to(b) < 0.5
	var points: Array[Vector3] = []
	for p in pts:
		var v := Vector3(float(p[0]), y, float(p[1]))
		if points.is_empty() or points[points.size() - 1].distance_to(v) >= 0.35:
			points.append(v)
	if closed and points.size() >= 2 and points[0].distance_to(points[points.size() - 1]) < 0.5:
		points.remove_at(points.size() - 1)
	if points.size() < 2:
		return
	points = RoadJunctions.trim(points, closed)
	var sides := _sides(points, closed)
	var half := maxf(width, 2.4) * 0.5
	var left: PackedVector3Array = PackedVector3Array()
	var right: PackedVector3Array = PackedVector3Array()
	var dist: PackedFloat32Array = PackedFloat32Array()
	var walked := 0.0
	for i in points.size():
		var scale := _miter_scale(points, sides, i, closed)
		var off := sides[i] * half * scale
		left.append(points[i] + off)
		right.append(points[i] - off)
		if i > 0:
			walked += points[i].distance_to(points[i - 1])
		dist.append(walked)
	var seg_count := points.size() - 1
	if closed and points.size() >= 3:
		seg_count = points.size()
		walked += points[0].distance_to(points[points.size() - 1])
	var batched := _batch_parent != null
	var deck := SurfaceTool.new()
	if batched:
		deck = _tool_for(_decks, asphalt)
	else:
		deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg_count:
		var j := (i + 1) % points.size()
		var u0 := dist[i] / TILE_M
		var u1 := dist[j] / TILE_M
		if j == 0:
			u1 = walked / TILE_M
		_quad(deck, left[i], right[i], right[j], left[j], u0, u1)
	if batched:
		if paint != null and width >= 4.5:
			var marks := _tool_for(_marks, paint)
			_edge_lines(marks, left, right, sides, closed)
			if _wants_centre(highway, width):
				_centre_dashes(marks, points, dist)
		return
	var mesh := deck.commit()
	mesh.surface_set_material(0, asphalt)
	if paint != null and width >= 4.5:
		var loose := SurfaceTool.new()
		loose.begin(Mesh.PRIMITIVE_TRIANGLES)
		_edge_lines(loose, left, right, sides, closed)
		if _wants_centre(highway, width):
			_centre_dashes(loose, points, dist)
		loose.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, paint)
	var mi := MeshInstance3D.new()
	mi.name = "road"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func prepare_junctions(roads: Array) -> int:
	return RoadJunctions.prepare(roads)


static func draw_prepared_junctions(parent: Node3D, y: float, asphalt: Material, major: Material) -> int:
	var n := 0
	for jv in RoadJunctions.clips:
		var j: Dictionary = jv
		var mat: Material = major if bool(j.get("major", false)) else asphalt
		if not bool(j.get("disc", true)):
			continue
		add_junction(parent, j["c"], float(j["r"]), y, mat)
		n += 1
	return n


static func add_junction(parent: Node3D, pos: Vector2, radius: float, y: float, asphalt: Material) -> void:
	if radius < 2.0:
		return
	var batched := _batch_parent != null
	var st := SurfaceTool.new()
	if batched:
		st = _tool_for(_decks, asphalt)
	else:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector3(pos.x, y + 0.01, pos.y)
	var steps := 12
	for i in steps:
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		var p0 := centre + Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := centre + Vector3(cos(a1), 0, sin(a1)) * radius
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(centre)
		st.set_uv(Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5))
		st.add_vertex(p0)
		st.set_uv(Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5))
		st.add_vertex(p1)
	if batched:
		return
	var mesh := st.commit()
	mesh.surface_set_material(0, asphalt)
	var mi := MeshInstance3D.new()
	mi.name = "junction"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func add_roundabout_island(parent: Node3D, pts: Array, width: float, y: float, fill: Material, kerb: Material) -> bool:
	if pts.size() < 6:
		return false
	var cx := 0.0
	var cz := 0.0
	for p in pts:
		cx += float(p[0])
		cz += float(p[1])
	cx /= float(pts.size())
	cz /= float(pts.size())
	var inner := 1e9
	for p in pts:
		inner = minf(inner, Vector2(float(p[0]) - cx, float(p[1]) - cz).length())
	var radius := inner - width * 0.5 - 0.8
	if radius < 1.2 or radius > 40.0:
		return false
	_disc(parent, Vector3(cx, y + 0.012, cz), radius, fill, "roundabout_island")
	_ring(parent, Vector3(cx, y + 0.02, cz), radius, radius + 0.45, kerb, "roundabout_kerb")
	return true


static func _disc(parent: Node3D, centre: Vector3, radius: float, material: Material, node_name: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 16
	for i in steps:
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(centre)
		st.set_uv(Vector2(cos(a0), sin(a0)))
		st.add_vertex(centre + Vector3(cos(a0), 0, sin(a0)) * radius)
		st.set_uv(Vector2(cos(a1), sin(a1)))
		st.add_vertex(centre + Vector3(cos(a1), 0, sin(a1)) * radius)
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _ring(parent: Node3D, centre: Vector3, inner: float, outer: float, material: Material, node_name: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 20
	for i in steps:
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		var i0 := centre + Vector3(cos(a0), 0, sin(a0)) * inner
		var i1 := centre + Vector3(cos(a1), 0, sin(a1)) * inner
		var o0 := centre + Vector3(cos(a0), 0, sin(a0)) * outer
		var o1 := centre + Vector3(cos(a1), 0, sin(a1)) * outer
		_mark(st, i0, o0, o1, i1)
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _sides(points: Array[Vector3], closed: bool = false) -> Array[Vector3]:
	var sides: Array[Vector3] = []
	var prev := Vector3.ZERO
	var n := points.size()
	for i in n:
		var direction := Vector3.ZERO
		var next_i := i + 1
		var prev_i := i - 1
		if closed:
			next_i = (i + 1) % n
			prev_i = (i - 1 + n) % n
		if next_i >= 0 and next_i < n:
			direction += points[next_i] - points[i]
		if prev_i >= 0 and prev_i < n:
			direction += points[i] - points[prev_i]
		if direction.length() < 0.001:
			direction = Vector3(0, 0, 1)
		direction = direction.normalized()
		var side := Vector3(-direction.z, 0.0, direction.x).normalized()
		if prev != Vector3.ZERO and side.dot(prev) < 0.0:
			side = -side
		prev = side
		sides.append(side)
	if closed and sides.size() > 1 and sides[sides.size() - 1].dot(sides[0]) < 0.0:
		sides[0] = -sides[0]
	return sides


static func _miter_scale(points: Array[Vector3], sides: Array[Vector3], i: int, closed: bool = false) -> float:
	var n := points.size()
	if not closed and (i == 0 or i == n - 1):
		return 1.0
	var prev_i := i - 1 if not closed else (i - 1 + n) % n
	var incoming := (points[i] - points[prev_i]).normalized()
	var incoming_side := Vector3(-incoming.z, 0.0, incoming.x)
	if incoming_side.dot(sides[i]) < 0.0:
		incoming_side = -incoming_side
	var denom := sides[i].dot(incoming_side)
	if absf(denom) < 0.35:
		return 1.0
	return clampf(1.0 / denom, 0.75, 1.6)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, u0: float, u1: float) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(u0, 0.0))
	st.add_vertex(a)
	st.set_uv(Vector2(u0, 1.0))
	st.add_vertex(b)
	st.set_uv(Vector2(u1, 1.0))
	st.add_vertex(c)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(u0, 0.0))
	st.add_vertex(a)
	st.set_uv(Vector2(u1, 1.0))
	st.add_vertex(c)
	st.set_uv(Vector2(u1, 0.0))
	st.add_vertex(d)


static func _edge_lines(st: SurfaceTool, left: PackedVector3Array, right: PackedVector3Array, sides: Array[Vector3], closed: bool = false) -> void:
	var lift := Vector3(0, 0.02, 0)
	var count := left.size() - 1
	if closed and left.size() >= 3:
		count = left.size()
	for i in count:
		var j := (i + 1) % left.size()
		var inward_a := -sides[i] * 0.42
		var inward_b := -sides[j] * 0.42
		var hw := 0.07
		_mark(st, left[i] + inward_a - sides[i] * hw + lift, left[i] + inward_a + sides[i] * hw + lift, left[j] + inward_b + sides[j] * hw + lift, left[j] + inward_b - sides[j] * hw + lift)
		_mark(st, right[i] - inward_a - sides[i] * hw + lift, right[i] - inward_a + sides[i] * hw + lift, right[j] - inward_b + sides[j] * hw + lift, right[j] - inward_b - sides[j] * hw + lift)


static func _centre_dashes(st: SurfaceTool, points: Array[Vector3], dist: PackedFloat32Array) -> void:
	var lift := Vector3(0, 0.025, 0)
	var cursor := 1.2
	var limit := dist[dist.size() - 1] - 1.2
	while cursor < limit:
		var a := _at_dist(points, dist, cursor)
		var b := _at_dist(points, dist, minf(cursor + 2.4, limit))
		var delta := b - a
		if delta.length() > 0.4:
			var side := Vector3(-delta.z, 0, delta.x).normalized() * 0.08
			_mark(st, a - side + lift, a + side + lift, b + side + lift, b - side + lift)
		cursor += 6.0


static func _at_dist(points: Array[Vector3], dist: PackedFloat32Array, target: float) -> Vector3:
	for i in dist.size() - 1:
		if dist[i + 1] >= target:
			var span := maxf(dist[i + 1] - dist[i], 0.001)
			var t := (target - dist[i]) / span
			return points[i].lerp(points[i + 1], t)
	return points[points.size() - 1]


static func _mark(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(b)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(d)


static func add_shared_junctions(parent: Node3D, roads: Array, y: float, asphalt: Material) -> int:
	var ends: Array[Dictionary] = []
	for road_v in roads:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		if pts.size() < 2:
			continue
		var width := float(road.get("width", 7.0))
		var rid := str(road.get("id", ""))
		ends.append({"id": rid, "p": Vector2(float(pts[0][0]), float(pts[0][1])), "w": width})
		var last: Array = pts[pts.size() - 1]
		ends.append({"id": rid, "p": Vector2(float(last[0]), float(last[1])), "w": width})
	var used := {}
	var count := 0
	for i in ends.size():
		if used.has(i):
			continue
		var ids := {str(ends[i]["id"]): true}
		var cluster: Array[int] = [i]
		var centre: Vector2 = ends[i]["p"]
		var reach := float(ends[i]["w"])
		for j in range(i + 1, ends.size()):
			if used.has(j):
				continue
			if (ends[j]["p"] as Vector2).distance_to(ends[i]["p"]) > 3.0:
				continue
			cluster.append(j)
			ids[str(ends[j]["id"])] = true
			centre += ends[j]["p"]
			reach = maxf(reach, float(ends[j]["w"]))
		if ids.size() < 3:
			continue
		for k in cluster:
			used[k] = true
		centre /= float(cluster.size())
		add_junction(parent, centre, reach * 0.42, y, asphalt)
		count += 1
	return count


static func add_verified_roundabouts(parent: Node3D, roads: Array, y: float, fill: Material, kerb: Material) -> int:
	var count := 0
	for road_v in roads:
		var road: Dictionary = road_v
		if not is_roundabout(road_key(road.get("id", ""))):
			continue
		if add_roundabout_island(parent, road.get("points", []), float(road.get("width", 9.0)), y, fill, kerb):
			count += 1
	return count


static func _wants_centre(highway: String, width: float) -> bool:
	return width >= 6.0 and highway in ["primary", "secondary", "tertiary", "trunk", "trunk_link", "motorway"]
