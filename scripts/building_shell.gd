extends RefCounted
## Extrudes a real OSM footprint. The polygon is the ground plan.
## Styles differ by floors, shutters and balconies. No shop name is generated.


const PARTY_M := 0.9
const PLASTER: Array[Color] = [
	Color(0.93, 0.86, 0.70),
	Color(0.78, 0.62, 0.46),
	Color(0.86, 0.74, 0.70),
	Color(0.70, 0.76, 0.78),
]


static func add_neighbourhood(parent: Node3D, specs: Array, party: Array) -> Dictionary:
	var plaster := _mat(Color.WHITE, 0.9, true)
	var roof_m := _mat(Color(0.42, 0.40, 0.38), 0.95, false)
	var glass := _mat(Color(0.10, 0.16, 0.22), 0.12, false)
	var dark := _mat(Color(0.16, 0.15, 0.14), 0.8, false)
	var metal := _mat(Color(0.45, 0.48, 0.50), 0.45, false)
	var tools := {
		"plaster": _tool(plaster),
		"roof": _tool(roof_m),
		"glass": _tool(glass),
		"dark": _tool(dark),
		"metal": _tool(metal),
	}
	var root := Node3D.new()
	root.name = "SpawnBuildings"
	parent.add_child(root)
	var bodies := 0
	var ids: Array[String] = []
	for spec_v in specs:
		var spec: Dictionary = spec_v
		var poly: PackedVector2Array = spec["poly"]
		if poly.size() < 3:
			continue
		var id := str(spec["id"])
		var floors: int = int(spec["floors"])
		var style := str(spec.get("style", "urban"))
		var front: int = int(spec.get("front", 0))
		var front_clear: float = float(spec.get("front_clear", 4.0))
		var tint: Color = PLASTER[int(id) % PLASTER.size()]
		if style == "civic":
			tint = Color(0.78, 0.78, 0.76)
		var height := _height(style, floors)
		_extrude(tools, poly, id, style, floors, height, front, front_clear, tint, party)
		_body(root, id, poly, height)
		ids.append(id)
		bodies += 1
	var mesh := ArrayMesh.new()
	var surfaces := 0
	for key in ["plaster", "roof", "glass", "dark", "metal"]:
		var pair: Array = tools[key]
		var st: SurfaceTool = pair[0]
		if int(pair[1]) == 0:
			continue
		st.commit(mesh)
		mesh.surface_set_material(surfaces, pair[2])
		surfaces += 1
	var visual := MeshInstance3D.new()
	visual.name = "Shell"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	visual.set_meta("osm_ids", ids)
	root.add_child(visual)
	return {"buildings": bodies, "surfaces": surfaces, "ids": ids}


static func _height(style: String, floors: int) -> float:
	if style == "shop" or style == "mixed":
		return 3.6 + float(maxi(floors - 1, 0)) * 3.0
	if style == "civic":
		return 3.8 * float(maxi(floors, 1))
	if floors <= 1:
		return 3.55
	return 3.25 + 3.0 * float(floors - 1)


static func _extrude(
	tools: Dictionary,
	poly: PackedVector2Array,
	id: String,
	style: String,
	floors: int,
	height: float,
	front: int,
	front_clear: float,
	tint: Color,
	party: Array
) -> void:
	var plaster: Array = tools["plaster"]
	var roof: Array = tools["roof"]
	var glass: Array = tools["glass"]
	var dark: Array = tools["dark"]
	var metal: Array = tools["metal"]
	var n := poly.size()
	var ground_h := 3.55 if floors <= 1 else 3.25
	if style == "shop" or style == "mixed":
		ground_h = 3.6
	var upper_h := 3.0
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var edge := b - a
		var length := edge.length()
		if length < 0.15:
			continue
		var outward := Vector2(edge.y, -edge.x) / length
		var shared := _party(a, b, id, party)
		var trim := tint.darkened(0.18)
		var thick := 0.28
		var ia := a - outward * thick
		var ib := b - outward * thick
		_wall(plaster, a, b, 0.0, 0.32, outward, trim)
		_wall(plaster, a, b, 0.32, height, outward, tint)
		_wall(plaster, a, b, height, height + 0.62, outward, trim)
		_wall(plaster, ib, ia, 0.0, height + 0.62, -outward, tint.darkened(0.06))
		_horiz(plaster, a, ia, ib, b, height + 0.62, Vector3.UP, trim)
		_box(plaster, Vector3(a.x, (height + 0.62) * 0.5, a.y), Vector3(thick, height + 0.62, thick), tint)
		if floors >= 2:
			_band(plaster, a, b, ground_h, outward, trim)
		var road_face := i == front
		var shop_front := road_face and style in ["shop", "mixed"]
		if shop_front:
			_shutter(metal, plaster, a, b, outward, ground_h, tint)
		elif road_face and length > 1.8:
			_door(dark, a, b, outward)
		if not shared and not shop_front and length > 2.5:
			_windows(glass, plaster, a, b, outward, floors, ground_h, upper_h, road_face, tint)
		if (
			road_face
			and floors >= 2
			and not shared
			and length > 4.2
			and front_clear > 1.8
			and style != "civic"
			and style != "shop"
		):
			_balcony(plaster, metal, a, b, outward, ground_h, tint)
	_roof(roof, poly, height)
	_tank(metal, poly, height, int(id))
	if _area(poly) >= 80.0:
		_stair(plaster, poly, height, tint)


static func _wall(pair: Array, a: Vector2, b: Vector2, y0: float, y1: float, outward: Vector2, col: Color) -> void:
	var n := Vector3(outward.x, 0.0, outward.y)
	var a0 := Vector3(a.x, y0, a.y)
	var a1 := Vector3(a.x, y1, a.y)
	var b1 := Vector3(b.x, y1, b.y)
	var b0 := Vector3(b.x, y0, b.y)
	_quad(pair, a0, a1, b1, b0, n, col)


static func _band(pair: Array, a: Vector2, b: Vector2, y: float, outward: Vector2, col: Color) -> void:
	var s: Vector2 = outward * 0.03
	_wall(pair, a + s, b + s, y - 0.06, y + 0.08, outward, col)


static func _door(pair: Array, a: Vector2, b: Vector2, outward: Vector2) -> void:
	var mid := (a + b) * 0.5 + outward * 0.04
	var along := (b - a).normalized()
	var half := along * 0.48
	var p0 := mid - half
	var p1 := mid + half
	_wall(pair, p0, p1, 0.05, 2.2, outward, Color(0.20, 0.16, 0.13))


static func _windows(
	glass: Array,
	trim: Array,
	a: Vector2,
	b: Vector2,
	outward: Vector2,
	floors: int,
	ground_h: float,
	upper_h: float,
	road_face: bool,
	tint: Color
) -> void:
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var count := maxi(1, int(length / 3.2))
	for f in floors:
		var y := ground_h * 0.55 if f == 0 else ground_h + (float(f - 1) + 0.55) * upper_h
		for c in count:
			var t := (float(c) + 0.5) / float(count)
			if road_face and f == 0 and absf(t - 0.5) < 0.18:
				continue
			var centre := a.lerp(b, t) + outward * 0.045
			var half := along * 0.55
			_wall(glass, centre - half, centre + half, y - 0.7, y + 0.62, outward, Color.WHITE)
			var shade := centre + outward * 0.16
			_wall(trim, shade - along * 0.78, shade + along * 0.78, y + 0.64, y + 0.78, outward, tint.darkened(0.35))


static func _shutter(metal: Array, trim: Array, a: Vector2, b: Vector2, outward: Vector2, ground_h: float, tint: Color) -> void:
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var count := maxi(1, int(length / 2.8))
	for c in count:
		var t := (float(c) + 0.5) / float(count)
		var centre := a.lerp(b, t) + outward * 0.04
		var half := along * (length / float(count) * 0.38)
		_wall(metal, centre - half, centre + half, 0.15, 2.55, outward, Color.WHITE)
	var board := (a + b) * 0.5 + outward * 0.07
	_wall(trim, board - along * (length * 0.46), board + along * (length * 0.46), ground_h - 0.85, ground_h - 0.2, outward, tint.darkened(0.28))


static func _balcony(plaster: Array, rail: Array, a: Vector2, b: Vector2, outward: Vector2, y: float, tint: Color) -> void:
	var along := (b - a).normalized()
	var mid := (a + b) * 0.5
	var width := minf(a.distance_to(b) * 0.5, 3.2)
	var inner := mid + outward * 0.02
	var outer := mid + outward * 0.9
	var side := along * (width * 0.5)
	var y0 := y - 0.05
	_horiz(plaster, inner - side, inner + side, outer + side, outer - side, y0, Vector3.UP, tint.darkened(0.08))
	_wall(rail, outer - side, outer + side, y0, y0 + 0.9, outward, tint.darkened(0.3))


static func _roof(pair: Array, poly: PackedVector2Array, y: float) -> void:
	var index := Geometry2D.triangulate_polygon(poly)
	if index.is_empty():
		return
	for t in range(0, index.size(), 3):
		var p0: Vector2 = poly[index[t]]
		var p1: Vector2 = poly[index[t + 1]]
		var p2: Vector2 = poly[index[t + 2]]
		var a := Vector3(p0.x, y, p0.y)
		var b := Vector3(p1.x, y, p1.y)
		var c := Vector3(p2.x, y, p2.y)
		if (b - a).cross(c - a).y < 0.0:
			var swap := b
			b = c
			c = swap
		_tri(pair, a, b, c, Vector3.UP, Color.WHITE)


static func _tank(pair: Array, poly: PackedVector2Array, y: float, seed: int) -> void:
	var spot := _inside(poly)
	var shift := Vector2(float(seed % 5) - 2.0, float((seed / 5) % 5) - 2.0) * 0.35
	var at := spot + shift
	if not Geometry2D.is_point_in_polygon(at, poly):
		at = spot
	_box(pair, Vector3(at.x, y + 0.55, at.y), Vector3(1.05, 1.1, 1.05), Color(0.18, 0.22, 0.28))


static func _stair(pair: Array, poly: PackedVector2Array, y: float, tint: Color) -> void:
	var at := _inside(poly) + Vector2(1.4, -1.1)
	if not Geometry2D.is_point_in_polygon(at, poly):
		at = _inside(poly)
	_box(pair, Vector3(at.x, y + 0.7, at.y), Vector3(1.5, 1.4, 1.5), tint.darkened(0.1))


static func _inside(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= float(poly.size())
	if Geometry2D.is_point_in_polygon(c, poly):
		return c
	var index := Geometry2D.triangulate_polygon(poly)
	if index.size() >= 3:
		return (poly[index[0]] + poly[index[1]] + poly[index[2]]) / 3.0
	return poly[0]


static func _body(root: Node3D, id: String, poly: PackedVector2Array, height: float) -> void:
	var faces := PackedVector3Array()
	var n := poly.size()
	for i in n:
		var a := Vector3(poly[i].x, 0.0, poly[i].y)
		var b := Vector3(poly[(i + 1) % n].x, 0.0, poly[(i + 1) % n].y)
		var a1 := Vector3(a.x, height, a.z)
		var b1 := Vector3(b.x, height, b.z)
		faces.append_array([a, b, b1, a, b1, a1])
	var index := Geometry2D.triangulate_polygon(poly)
	for t in range(0, index.size(), 3):
		var p0 := Vector3(poly[index[t]].x, height, poly[index[t]].y)
		var p1 := Vector3(poly[index[t + 1]].x, height, poly[index[t + 1]].y)
		var p2 := Vector3(poly[index[t + 2]].x, height, poly[index[t + 2]].y)
		faces.append_array([p0, p1, p2])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = "hit_%s" % id
	body.set_meta("osm_id", id)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	root.add_child(body)


static func _party(a: Vector2, b: Vector2, id: String, party: Array) -> bool:
	var mid := (a + b) * 0.5
	for other_v in party:
		var other: Dictionary = other_v
		if str(other["id"]) == id:
			continue
		var poly: PackedVector2Array = other["poly"]
		for i in poly.size():
			var c: Vector2 = poly[i]
			var d: Vector2 = poly[(i + 1) % poly.size()]
			if _seg_dist(mid, c, d) < PARTY_M:
				return true
	return false


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var den := ab.length_squared()
	var t := 0.0 if den == 0.0 else clampf((p - a).dot(ab) / den, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


static func _box(pair: Array, c: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var p := [
		c + Vector3(-h.x, -h.y, -h.z),
		c + Vector3(h.x, -h.y, -h.z),
		c + Vector3(h.x, h.y, -h.z),
		c + Vector3(-h.x, h.y, -h.z),
		c + Vector3(-h.x, -h.y, h.z),
		c + Vector3(h.x, -h.y, h.z),
		c + Vector3(h.x, h.y, h.z),
		c + Vector3(-h.x, h.y, h.z),
	]
	_quad(pair, p[4], p[5], p[6], p[7], Vector3(0, 0, 1), col)
	_quad(pair, p[1], p[0], p[3], p[2], Vector3(0, 0, -1), col)
	_quad(pair, p[5], p[1], p[2], p[6], Vector3(1, 0, 0), col)
	_quad(pair, p[0], p[4], p[7], p[3], Vector3(-1, 0, 0), col)
	_quad(pair, p[3], p[2], p[6], p[7], Vector3(0, 1, 0), col)
	_quad(pair, p[0], p[1], p[5], p[4], Vector3(0, -1, 0), col)


static func _horiz(pair: Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2, y: float, n: Vector3, col: Color) -> void:
	_quad(pair, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3(d.x, y, d.y), n, col)


static func _quad(pair: Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	_tri(pair, a, b, c, n, col)
	_tri(pair, a, c, d, n, col)


static func _tri(pair: Array, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	var st: SurfaceTool = pair[0]
	pair[1] = int(pair[1]) + 3
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(a)
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(b)
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(c)


static func _tool(mat: Material) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return [st, 0, mat]


static func _mat(color: Color, rough: float, vertex: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.vertex_color_use_as_albedo = vertex
	return mat
