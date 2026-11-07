extends RefCounted
## Fit kit building GLBs inside real OSM footprints without touching the asphalt.
## Uniform scale only. Rejects any placement that overlaps a road surface.


const AssetKit = preload("res://scripts/asset_kit.gd")
const BuildingShell = preload("res://scripts/building_shell.gd")

const ROAD_MARGIN_M := 0.5
const POLY_INSET_M := 0.2
const HOUSE_PATH := "res://assets/kit/buildings/indian_house.glb"
static func place_neighbourhood(
	parent: Node3D,
	specs: Array,
	road_segments: Array,
	opts: Dictionary = {}
) -> Dictionary:
	var show_debug := bool(opts.get("debug", true))
	var allow_assets := bool(opts.get("assets", true))
	var procedural_specs: Array = []
	var reports: Array = []
	var root := Node3D.new()
	root.name = "AssetNeighbourhood"
	parent.add_child(root)
	var asset_root := Node3D.new()
	asset_root.name = "FittedAssets"
	root.add_child(asset_root)
	var debug_root := Node3D.new()
	debug_root.name = "ClearanceDebug"
	debug_root.visible = show_debug
	root.add_child(debug_root)
	var fitted := 0
	var procedural := 0
	var rejected := 0
	for spec_v in specs:
		var spec: Dictionary = spec_v
		var report := _try_asset(asset_root, debug_root, spec, road_segments, allow_assets)
		reports.append(report)
		if str(report["result"]) == "fitted":
			fitted += 1
		elif str(report["result"]) == "procedural":
			procedural_specs.append(spec)
			procedural += 1
		else:
			rejected += 1
			print("REJECT ", report["id"], " ", report["reason"], " clear ", snapped(float(report["clearance"]), 0.01))
	var shell := {"buildings": 0, "surfaces": 0, "ids": [], "walls": 0}
	if not procedural_specs.is_empty():
		shell = BuildingShell.add_neighbourhood(root, procedural_specs, procedural_specs)
		_draw_procedural_debug(debug_root, procedural_specs, road_segments)
	_draw_road_debug(debug_root, road_segments)
	return {
		"fitted": fitted,
		"procedural": procedural,
		"rejected": rejected,
		"reports": reports,
		"shell": shell,
		"debug": debug_root,
	}


static func _try_asset(
	asset_root: Node3D,
	debug_root: Node3D,
	spec: Dictionary,
	road_segments: Array,
	allow_assets: bool
) -> Dictionary:
	var id := str(spec["id"])
	var poly: PackedVector2Array = spec["poly"]
	var style := str(spec.get("style", "family"))
	var front: int = int(spec.get("front", 0))
	var area := float(spec.get("area", _area(poly)))
	var poly_clear := _polygon_road_clearance(poly, road_segments)
	var report := {
		"id": id,
		"style": style,
		"asset": "",
		"footprint_area": snapped(area, 0.1),
		"asset_area": 0.0,
		"clearance": snapped(poly_clear, 0.01),
		"inside_polygon": false,
		"road_overlap": poly_clear < ROAD_MARGIN_M,
		"neighbour_overlap": false,
		"collision": false,
		"result": "procedural",
		"reason": "",
		"yaw_estimate": false,
	}
	_draw_poly(debug_root, poly, Color(0.2, 0.85, 0.35) if poly_clear >= ROAD_MARGIN_M else Color(0.95, 0.2, 0.15), 0.08)
	if poly_clear < ROAD_MARGIN_M:
		report["result"] = "rejected"
		report["reason"] = "footprint_road_clearance"
		return report
	if not allow_assets:
		report["reason"] = "assets_disabled"
		return report
	var path := _asset_for_style(style, area)
	if path == "":
		report["reason"] = "no_suitable_asset"
		return report
	if not AssetKit.exists(path):
		report["reason"] = "missing_asset"
		return report
	report["asset"] = path.get_file()
	var yaw := _front_yaw(poly, front)
	report["yaw_estimate"] = true
	var probe := _prepared_house(path)
	if probe == null:
		report["reason"] = "instantiate_failed"
		return report
	var raw_aabb := AssetKit.mesh_aabb(probe)
	if raw_aabb.size.length() < 0.05:
		probe.queue_free()
		report["reason"] = "empty_mesh"
		return report
	var fit := _fit_uniform(poly, front, raw_aabb, yaw)
	if not bool(fit["ok"]):
		probe.queue_free()
		report["reason"] = str(fit["reason"])
		return report
	var scale: float = float(fit["scale"])
	var centre: Vector2 = fit["centre"]
	probe.name = "asset_%s" % id
	probe.set_meta("osm_id", id)
	probe.scale = Vector3.ONE * scale
	probe.rotation.y = yaw
	probe.position = Vector3(centre.x, 0.0, centre.y)
	asset_root.add_child(probe)
	var placed := probe
	var world_aabb := AssetKit.mesh_aabb(placed)
	placed.position.y = -world_aabb.position.y
	world_aabb = AssetKit.mesh_aabb(placed)
	var box := _aabb_poly(world_aabb)
	var box_clear := _polygon_road_clearance(box, road_segments)
	var inside := _poly_inside(box, poly, POLY_INSET_M * 0.25)
	report["asset_area"] = snapped(world_aabb.size.x * world_aabb.size.z, 0.1)
	report["clearance"] = snapped(minf(poly_clear, box_clear), 0.01)
	report["inside_polygon"] = inside
	report["road_overlap"] = box_clear < ROAD_MARGIN_M
	_draw_poly(debug_root, box, Color(0.2, 0.55, 1.0), 0.12)
	_draw_clear_label(debug_root, centre, report["clearance"])
	if box_clear < ROAD_MARGIN_M or not inside:
		asset_root.remove_child(placed)
		placed.queue_free()
		report["result"] = "procedural"
		report["reason"] = "asset_failed_clearance" if box_clear < ROAD_MARGIN_M else "asset_outside_polygon"
		return report
	_add_box_collision(placed, world_aabb, id)
	report["collision"] = true
	report["result"] = "fitted"
	report["reason"] = "ok"
	print(
		"FIT ",
		id,
		" ",
		report["asset"],
		" scale ",
		snapped(scale, 0.001),
		" clear ",
		report["clearance"],
		" area ",
		report["asset_area"],
		"/",
		report["footprint_area"]
	)
	return report


static func _asset_for_style(style: String, area: float) -> String:
	# indian_house is the only complete residential shell in the new downloads.
	# bhelpuri_shop is a cart-sized prop — keep it on the comparison shelf, do not stretch it into a footprint.
	if style in ["cottage", "family", "row"] and area >= 55.0 and area <= 120.0:
		return HOUSE_PATH
	return ""


static func _fit_uniform(poly: PackedVector2Array, front: int, raw_aabb: AABB, yaw: float) -> Dictionary:
	var centre := _inside(poly)
	var half_x := raw_aabb.size.x * 0.5
	var half_z := raw_aabb.size.z * 0.5
	var local_corners := [
		Vector2(-half_x, -half_z),
		Vector2(half_x, -half_z),
		Vector2(half_x, half_z),
		Vector2(-half_x, half_z),
	]
	var cos_y := cos(yaw)
	var sin_y := sin(yaw)
	var lo := 0.2
	var hi := 1.8
	var height := raw_aabb.size.y
	if height > 0.01:
		hi = minf(hi, 9.5 / height)
	var best := 0.0
	for _i in 18:
		var mid := (lo + hi) * 0.5
		if _box_inside(centre, local_corners, cos_y, sin_y, mid, poly, POLY_INSET_M):
			best = mid
			lo = mid
		else:
			hi = mid
	if best <= 0.0 or (height > 0.01 and height * best < 2.8):
		return {"ok": false, "reason": "too_small_to_fit", "scale": best}
	return {"ok": true, "scale": best, "centre": centre, "reason": "ok"}


static func _box_inside(
	centre: Vector2,
	local_corners: Array,
	cos_y: float,
	sin_y: float,
	scale: float,
	poly: PackedVector2Array,
	inset: float
) -> bool:
	for c_v in local_corners:
		var c: Vector2 = c_v
		var local := c * scale
		var world := centre + Vector2(local.x * cos_y + local.y * sin_y, -local.x * sin_y + local.y * cos_y)
		if not Geometry2D.is_point_in_polygon(world, poly):
			return false
		if _dist_to_poly(world, poly) < inset:
			return false
	return true


static func _prepared_house(path: String) -> Node3D:
	## Raw GLB, longest plan axis on Z, bottom at y=0, centred on origin. No forced 8 m length.
	var raw := AssetKit.instance(path)
	if raw == null:
		return null
	AssetKit.ensure_materials(raw)
	var wrap := Node3D.new()
	wrap.add_child(raw)
	var a := AssetKit.mesh_aabb(raw)
	if a.size.x > a.size.z * 1.15:
		raw.rotation.y = PI * 0.5
		a = AssetKit.mesh_aabb(wrap)
	var centre := a.position + a.size * 0.5
	raw.position -= Vector3(centre.x, a.position.y, centre.z)
	return wrap


static func _front_yaw(poly: PackedVector2Array, front: int) -> float:
	var a: Vector2 = poly[front]
	var b: Vector2 = poly[(front + 1) % poly.size()]
	var edge := b - a
	if edge.length() < 0.01:
		return 0.0
	var outward := Vector2(-edge.y, edge.x).normalized()
	# Model local +Z faces the road after yaw.
	return atan2(outward.x, outward.y)


static func _add_box_collision(node: Node3D, world_aabb: AABB, id: String) -> void:
	_strip_physics(node)
	var body := StaticBody3D.new()
	body.name = "hit_%s" % id
	body.set_meta("osm_id", id)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(world_aabb.size.x * 0.92, world_aabb.size.y * 0.95, world_aabb.size.z * 0.92)
	col.shape = shape
	var centre := world_aabb.position + world_aabb.size * 0.5
	col.position = node.to_local(centre)
	body.add_child(col)
	node.add_child(body)


static func _strip_physics(n: Node) -> void:
	for c in n.get_children():
		_strip_physics(c)
	if n is StaticBody3D or n is RigidBody3D or n is CollisionShape3D:
		n.queue_free()


static func _polygon_road_clearance(poly: PackedVector2Array, segments: Array) -> float:
	var best := 1.0e9
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		for t in 5:
			var p := a.lerp(b, float(t) / 4.0)
			best = minf(best, _point_road_clearance(p, segments))
	best = minf(best, _point_road_clearance(_inside(poly), segments))
	return best


static func _point_road_clearance(p: Vector2, segments: Array) -> float:
	var best := 1.0e9
	for seg_v in segments:
		var seg: Dictionary = seg_v
		var a: Vector2 = seg["a"]
		var b: Vector2 = seg["b"]
		var half := float(seg["half"])
		var ab := b - a
		var den := ab.length_squared()
		var t := 0.0 if den == 0.0 else clampf((p - a).dot(ab) / den, 0.0, 1.0)
		var d := p.distance_to(a + ab * t) - half
		if d < best:
			best = d
	return best


static func _aabb_poly(aabb: AABB) -> PackedVector2Array:
	var x0 := aabb.position.x
	var z0 := aabb.position.z
	var x1 := aabb.position.x + aabb.size.x
	var z1 := aabb.position.z + aabb.size.z
	return PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)])


static func _poly_inside(inner: PackedVector2Array, outer: PackedVector2Array, slack: float) -> bool:
	for p in inner:
		if not Geometry2D.is_point_in_polygon(p, outer):
			if _dist_to_poly(p, outer) > slack:
				return false
	return true


static func _dist_to_poly(p: Vector2, poly: PackedVector2Array) -> float:
	var best := 1.0e9
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var ab := b - a
		var den := ab.length_squared()
		var t := 0.0 if den == 0.0 else clampf((p - a).dot(ab) / den, 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


static func _ray_exit(origin: Vector2, dir: Vector2, poly: PackedVector2Array) -> float:
	var best := -1.0
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var hit: Variant = Geometry2D.segment_intersects_segment(origin, origin + dir * 200.0, a, b)
		if typeof(hit) != TYPE_VECTOR2:
			continue
		var p: Vector2 = hit
		var d := origin.distance_to(p)
		if d > 0.02 and (best < 0.0 or d < best):
			best = d
	return best


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


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


static func _draw_poly(parent: Node3D, poly: PackedVector2Array, color: Color, y: float) -> void:
	if poly.size() < 2:
		return
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in poly:
		im.surface_set_color(color)
		im.surface_add_vertex(Vector3(p.x, y, p.y))
	im.surface_set_color(color)
	im.surface_add_vertex(Vector3(poly[0].x, y, poly[0].y))
	im.surface_end()
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat
	parent.add_child(mi)


static func _draw_clear_label(parent: Node3D, at: Vector2, clearance: float) -> void:
	var label := Label3D.new()
	label.text = "%.1fm" % clearance
	label.font_size = 28
	label.pixel_size = 0.018
	label.position = Vector3(at.x, 0.35, at.y)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 0.95, 0.4)
	parent.add_child(label)


static func _draw_road_debug(parent: Node3D, segments: Array) -> void:
	for seg_v in segments:
		var seg: Dictionary = seg_v
		var a: Vector2 = seg["a"]
		var b: Vector2 = seg["b"]
		var half := float(seg["half"])
		var ab := b - a
		if ab.length() < 0.2:
			continue
		var n := Vector2(-ab.y, ab.x).normalized() * half
		var poly := PackedVector2Array([a + n, b + n, b - n, a - n])
		_draw_poly(parent, poly, Color(1.0, 0.35, 0.1, 1.0), 0.05)


static func _draw_procedural_debug(parent: Node3D, specs: Array, road_segments: Array) -> void:
	for spec_v in specs:
		var spec: Dictionary = spec_v
		var poly: PackedVector2Array = spec["poly"]
		var clear := _polygon_road_clearance(poly, road_segments)
		_draw_poly(parent, poly, Color(0.85, 0.75, 0.2), 0.09)
		_draw_clear_label(parent, _inside(poly), clear)
