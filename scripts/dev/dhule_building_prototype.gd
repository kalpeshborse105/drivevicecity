extends Node3D
## Phase 2H.2 — authentic Dhule building prototype from real OSM rings.
## Isolated from scenes/main.tscn. Does not touch Blosm or vehicle forces.


const OSM := "res://assets/maps/dhule_city.osm"
const MAP := "res://assets/maps/dhule_roads_game.json"
const LAT0 := 20.902
const LON0 := 74.777
const M_LAT := 111320.0

## 16 real way ids near spawn. Prefer 72–180 m²; include irregular + two quads.
const IDS: Array[String] = [
	"1337953920", "1337953903", "1337951730", "1337953921",
	"1337953918", "1337953905", "1337953904", "1337952466",
	"1337953902", "1337953919", "1337952468", "1337952467",
	"1337951722", "1337951728", "1337951691", "1337951692",
]

const BuildingShell = preload("res://scripts/building_shell.gd")
const DhuleBuildingStyles = preload("res://scripts/dhule_building_styles.gd")
const AssetPlacementValidator = preload("res://scripts/asset_placement_validator.gd")
const RoadSurface = preload("res://scripts/road_surface.gd")
const AssetKit = preload("res://scripts/asset_kit.gd")

var _car: VehicleBody3D
var _cam: Camera3D
var _aerial := false
var _follow := true
var _show_footprints := true
var _show_collision := false
var _origin := Vector3(-636.54, 0.42, 881.83)
var _meta: Array = []
var _footprint_root: Node3D
var _hud: Label
var _info: Label


func _ready() -> void:
	_car = $PlayerCar
	_cam = $ChaseCam
	_hud_ui()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	var spawn: Dictionary = data["spawn"]
	_origin = Vector3(float(spawn["x"]), 0.42, float(spawn["z"]))
	_ground(_origin)
	_roads(data)
	var segments := _road_segments(data)
	var built := _buildings(segments)
	_car.set_spawn(_origin, Vector2(float(spawn["hx"]), float(spawn["hz"])))
	print("BUILDING_PROTO ", built)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				_aerial = not _aerial
			KEY_F:
				_show_footprints = not _show_footprints
				if _footprint_root:
					_footprint_root.visible = _show_footprints
			KEY_G:
				_show_collision = not _show_collision
				get_tree().debug_collisions_hint = _show_collision
			KEY_H:
				_info.visible = not _info.visible


func lock_view(pos: Vector3, at: Vector3) -> void:
	_follow = false
	_cam.current = true
	_cam.global_position = pos
	if pos.distance_to(at) > 0.4:
		_cam.look_at(at, Vector3.UP)


func run_capture() -> void:
	_car.visible = false
	_show_footprints = true
	if _footprint_root:
		_footprint_root.visible = true
	lock_view(_origin + Vector3(22, 42, 28), _origin + Vector3(0, 1.0, 14))
	await _frames(8)
	await _shot("res://docs/qa/56-aerial.png")
	_car.visible = true
	_follow = true
	_aerial = false
	await _frames(10)
	lock_view(_origin + Vector3(-2, 2.4, 6), _origin + Vector3(2, 1.2, 16))
	await _frames(6)
	await _shot("res://docs/qa/56-street.png")
	# Drive into first accepted building.
	if not _meta.is_empty():
		var m: Dictionary = _meta[0]
		var cx := float(m["cx"])
		var cz := float(m["cz"])
		var start := Vector3(cx, 0.42, cz - 10.0)
		await _teleport_car(start, Vector2(0, 1))
		Input.action_press("accelerate")
		var peak := 0.0
		var elapsed := 0.0
		while elapsed < 3.5:
			await get_tree().physics_frame
			elapsed += get_physics_process_delta_time()
			peak = maxf(peak, _car.linear_velocity.length() * 3.6)
		Input.action_release("accelerate")
		var speed := _car.linear_velocity.length() * 3.6
		print(
			"DRIVE_HIT id=", m["osm_id"],
			" speed=", snapped(speed, 0.1),
			" peak=", snapped(peak, 0.1),
			" at=", _car.global_position
		)
		lock_view(_car.global_position + Vector3(-4, 2.6, -3), _car.global_position + Vector3(0, 1.0, 2))
		await _frames(4)
		await _shot("res://docs/qa/56-collision.png")
	await _sample("proto_block")


func _process(_delta: float) -> void:
	_update_hud()
	if not _follow or _cam == null or _car == null:
		return
	var car_cam := _car.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if car_cam:
		car_cam.current = false
	_cam.current = true
	if _aerial:
		_cam.global_position = _origin + Vector3(18, 48, 22)
		_cam.look_at(_origin + Vector3(0, 1, 12), Vector3.UP)
		return
	var back := _car.global_transform.basis.z
	_cam.global_position = _car.global_position - back * 8.0 + Vector3(0, 2.8, 0)
	_cam.look_at(_car.global_position + Vector3(0, 1.1, 0) + back * 4.0, Vector3.UP)


func _buildings(segments: Array) -> Dictionary:
	var raw := _read_osm()
	var specs: Array = []
	var party: Array = []
	var estimated := 0
	var osm_levels := 0
	var rejected := 0
	_footprint_root = Node3D.new()
	_footprint_root.name = "FootprintOutlines"
	add_child(_footprint_root)
	for id in IDS:
		if not raw.has(id):
			push_warning("missing footprint %s" % id)
			rejected += 1
			continue
		var row: Dictionary = raw[id]
		var poly: PackedVector2Array = row["poly"]
		_wind(poly)
		var area := _area(poly)
		var tags: Dictionary = row["tags"]
		var building_tag := str(tags.get("building", ""))
		# Never invent shop/temple/school from name. Only explicit tags.
		if building_tag in ["school", "college", "hospital", "commercial", "retail"] or tags.has("shop") or tags.has("amenity"):
			print("SKIP tagged special ", id, " building=", building_tag)
			rejected += 1
			continue
		var span_x := _span_x(poly)
		var span_z := _span_z(poly)
		var span_min := minf(span_x, span_z)
		var span_max := maxf(span_x, span_z)
		var style_key := DhuleBuildingStyles.choose(area, span_min, span_max, id)
		var floors := 1
		var height_source := "estimated"
		var source_levels := ""
		if tags.has("height"):
			height_source = "osm"
			source_levels = str(tags["height"])
			floors = maxi(1, int(ceili(float(str(tags["height"])) / 3.1)))
			osm_levels += 1
		elif tags.has("building:levels"):
			height_source = "osm"
			source_levels = str(tags["building:levels"])
			floors = maxi(1, int(str(tags["building:levels"])))
			osm_levels += 1
		else:
			floors = DhuleBuildingStyles.estimated_floors(style_key, area)
			estimated += 1
		var front := _front_edge(poly, segments)
		if float(front["clear"]) < 0.5:
			print("REJECT road_overlap ", id, " clear ", snapped(float(front["clear"]), 0.01))
			_draw_footprint(poly, Color(1.0, 0.2, 0.15))
			rejected += 1
			continue
		# Footprint AABB vs asphalt polygons (Phase 2G validator).
		var aabb := _poly_aabb(poly, 3.2)
		var clear := AssetPlacementValidator.asphalt_clearance(aabb, segments)
		if clear < 0.5:
			print("REJECT validator ", id, " clear ", snapped(clear, 0.01))
			_draw_footprint(poly, Color(1.0, 0.35, 0.1))
			rejected += 1
			continue
		_draw_footprint(poly, Color(0.15, 0.85, 1.0))
		var cx := 0.0
		var cz := 0.0
		for p in poly:
			cx += p.x
			cz += p.y
		cx /= float(poly.size())
		cz /= float(poly.size())
		var shell := DhuleBuildingStyles.shell_style(style_key)
		party.append({"id": id, "poly": poly})
		specs.append({
			"id": id,
			"poly": poly,
			"floors": floors,
			"style": shell,
			"front": front["index"],
			"front_clear": front["clear"],
		})
		var rec := {
			"osm_id": id,
			"building": building_tag,
			"source_levels": source_levels,
			"estimated_levels": floors if height_source == "estimated" else "",
			"floors": floors,
			"height_source": height_source,
			"area_m2": snapped(area, 0.01),
			"vertices": poly.size(),
			"style_variant": style_key,
			"shell_style": shell,
			"collision": true,
			"front_clear_m": snapped(float(front["clear"]), 0.01),
			"validator_clear_m": snapped(clear, 0.01),
			"cx": snapped(cx, 0.01),
			"cz": snapped(cz, 0.01),
			"dist_spawn_m": snapped(Vector2(cx - _origin.x, cz - _origin.z).length(), 0.01),
			"span_min_m": snapped(span_min, 0.01),
			"span_max_m": snapped(span_max, 0.01),
		}
		_meta.append(rec)
		_label3d(Vector3(cx, 4.2, cz), "%s\n%s\n%.0fm² %s" % [id, style_key, area, height_source])
		print(
			"FOOTPRINT ", id,
			" verts ", poly.size(),
			" area ", snapped(area, 0.1),
			" style ", style_key,
			" floors ", floors,
			" ", height_source,
			" clear ", snapped(float(front["clear"]), 0.01)
		)
	var result: Dictionary = BuildingShell.add_neighbourhood(self, specs, party)
	result["estimated"] = estimated
	result["osm_height_or_levels"] = osm_levels
	result["rejected"] = rejected
	result["accepted"] = _meta.size()
	result["meta"] = _meta
	return result


func _hud_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ProtoHUD"
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(12, 10)
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.text = "C aerial | F footprints | G collision | H labels"
	layer.add_child(_hud)
	_info = Label.new()
	_info.position = Vector2(12, 36)
	_info.add_theme_font_size_override("font_size", 14)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size = Vector2(520, 160)
	layer.add_child(_info)


func _update_hud() -> void:
	if _info == null or _car == null:
		return
	var best: Dictionary = {}
	var best_d := 1.0e9
	var p := Vector2(_car.global_position.x, _car.global_position.z)
	for m_v in _meta:
		var m: Dictionary = m_v
		var d := p.distance_to(Vector2(float(m["cx"]), float(m["cz"])))
		if d < best_d:
			best_d = d
			best = m
	if best.is_empty():
		_info.text = "No buildings"
		return
	var lvl := str(best["source_levels"]) if str(best["height_source"]) == "osm" else "est %s" % str(best["estimated_levels"])
	_info.text = (
		"OSM %s\narea %.1f m²  verts %s\nstyle %s\nheight %s (%s)\nclear road %.2f m  collision %s"
		% [
			best["osm_id"],
			float(best["area_m2"]),
			best["vertices"],
			best["style_variant"],
			lvl,
			best["height_source"],
			float(best["front_clear_m"]),
			best["collision"],
		]
	)


func _read_osm() -> Dictionary:
	var wanted := {}
	for id in IDS:
		wanted[id] = true
	var nodes := {}
	var out := {}
	var parser := XMLParser.new()
	if parser.open(OSM) != OK:
		return out
	var current := ""
	var refs: PackedStringArray = []
	var tags := {}
	while parser.read() == OK:
		var kind := parser.get_node_type()
		if kind != XMLParser.NODE_ELEMENT and kind != XMLParser.NODE_ELEMENT_END:
			continue
		var name := parser.get_node_name()
		if kind == XMLParser.NODE_ELEMENT and name == "node":
			var nid := parser.get_named_attribute_value_safe("id")
			nodes[nid] = _xz(
				float(parser.get_named_attribute_value_safe("lat")),
				float(parser.get_named_attribute_value_safe("lon"))
			)
		elif kind == XMLParser.NODE_ELEMENT and name == "way":
			current = parser.get_named_attribute_value_safe("id")
			refs = PackedStringArray()
			tags = {}
		elif kind == XMLParser.NODE_ELEMENT and name == "nd" and current != "" and wanted.has(current):
			refs.append(parser.get_named_attribute_value_safe("ref"))
		elif kind == XMLParser.NODE_ELEMENT and name == "tag" and current != "" and wanted.has(current):
			tags[parser.get_named_attribute_value_safe("k")] = parser.get_named_attribute_value_safe("v")
		elif kind == XMLParser.NODE_ELEMENT_END and name == "way" and wanted.has(current):
			var poly := PackedVector2Array()
			for ref in refs:
				if nodes.has(ref):
					poly.append(nodes[ref])
			if poly.size() >= 4 and poly[0].distance_to(poly[poly.size() - 1]) < 0.05:
				poly.remove_at(poly.size() - 1)
			if poly.size() >= 3:
				out[current] = {"poly": poly, "tags": tags.duplicate()}
			current = ""
	return out


func _xz(lat: float, lon: float) -> Vector2:
	var m_lon := M_LAT * cos(deg_to_rad(LAT0))
	return Vector2((lon - LON0) * m_lon, -(lat - LAT0) * M_LAT)


func _wind(poly: PackedVector2Array) -> void:
	if _signed(poly) < 0.0:
		poly.reverse()


func _signed(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


func _area(poly: PackedVector2Array) -> float:
	return absf(_signed(poly))


func _span_x(poly: PackedVector2Array) -> float:
	var mn := 1.0e9
	var mx := -1.0e9
	for p in poly:
		mn = minf(mn, p.x)
		mx = maxf(mx, p.x)
	return mx - mn


func _span_z(poly: PackedVector2Array) -> float:
	var mn := 1.0e9
	var mx := -1.0e9
	for p in poly:
		mn = minf(mn, p.y)
		mx = maxf(mx, p.y)
	return mx - mn


func _poly_aabb(poly: PackedVector2Array, height: float) -> AABB:
	var mn := Vector2(1.0e9, 1.0e9)
	var mx := Vector2(-1.0e9, -1.0e9)
	for p in poly:
		mn.x = minf(mn.x, p.x)
		mn.y = minf(mn.y, p.y)
		mx.x = maxf(mx.x, p.x)
		mx.y = maxf(mx.y, p.y)
	return AABB(Vector3(mn.x, 0.0, mn.y), Vector3(mx.x - mn.x, height, mx.y - mn.y))


func _front_edge(poly: PackedVector2Array, segments: Array) -> Dictionary:
	var best_i := 0
	var best_d := 1.0e9
	var best_clear := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if a.distance_to(b) < 1.6:
			continue
		var mid := (a + b) * 0.5
		var hit := _nearest_road(mid, segments)
		if float(hit["dist"]) < best_d:
			best_d = float(hit["dist"])
			best_clear = float(hit["dist"]) - float(hit["half"])
			best_i = i
	return {"index": best_i, "clear": best_clear}


func _nearest_road(p: Vector2, segments: Array) -> Dictionary:
	var best := 1.0e9
	var half := 3.5
	for seg_v in segments:
		var seg: Dictionary = seg_v
		var a: Vector2 = seg["a"]
		var b: Vector2 = seg["b"]
		var ab := b - a
		var den := ab.length_squared()
		var t := 0.0 if den == 0.0 else clampf((p - a).dot(ab) / den, 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			half = float(seg["half"])
	return {"dist": best, "half": half}


func _road_segments(data: Dictionary) -> Array:
	var out: Array = []
	for road_v in data["roads"]:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		var half := float(road.get("width", 7.0)) * 0.5
		for i in range(pts.size() - 1):
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			if a.distance_to(Vector2(_origin.x, _origin.z)) > 240.0 and b.distance_to(Vector2(_origin.x, _origin.z)) > 240.0:
				continue
			out.append({"a": a, "b": b, "half": half})
	return out


func _roads(data: Dictionary) -> void:
	var asphalt := _road_mat("street_road", Color(0.78, 0.78, 0.8))
	var major := _road_mat("avenue_street", Color(0.74, 0.74, 0.77))
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.93, 0.93, 0.9)
	paint.roughness = 0.55
	var shown: Array = []
	for road_v in data["roads"]:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		var near := false
		for p in pts:
			if Vector2(float(p[0]) - _origin.x, float(p[1]) - _origin.z).length() < 200.0:
				near = true
				break
		if near:
			shown.append(road)
	RoadSurface.prepare_junctions(shown)
	RoadSurface.begin_batch(self)
	for road_v in shown:
		var road: Dictionary = road_v
		var hw := str(road.get("highway", "residential"))
		var mat: Material = major if hw in ["primary", "secondary", "tertiary", "trunk", "trunk_link"] else asphalt
		RoadSurface.add_way(self, road.get("points", []), float(road.get("width", 7.0)), 0.04, mat, paint, hw)
	RoadSurface.draw_prepared_junctions(self, 0.04, asphalt, major)
	RoadSurface.flush_batch()


func _road_mat(kit_key: String, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.9
	var tex := AssetKit.road_albedo_clean(kit_key)
	if tex:
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


func _ground(origin: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := BoxShape3D.new()
	shape.size = Vector3(480, 0.4, 480)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(origin.x, -0.2, origin.z)
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh.mesh = box
	mesh.position = col.position
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.46, 0.52, 0.36)
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)


func _draw_footprint(poly: PackedVector2Array, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in poly.size() + 1:
		var p: Vector2 = poly[i % poly.size()]
		im.surface_set_color(color)
		im.surface_add_vertex(Vector3(p.x, 0.12, p.y))
	im.surface_end()
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat
	_footprint_root.add_child(mi)


func _label3d(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 28
	label.pixel_size = 0.018
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 1, 0.85)
	add_child(label)


func _teleport_car(start: Vector3, heading: Vector2) -> void:
	_car.set_physics_process(false)
	_car.freeze = true
	_car.set_spawn(start, heading)
	var forward := Vector3(heading.x, 0.0, heading.y).normalized()
	var xf := Transform3D(Basis.looking_at(-forward, Vector3.UP), Vector3(start.x, 0.42, start.z))
	var rid := _car.get_rid()
	for _i in 4:
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
		_car.global_transform = xf
		_car.linear_velocity = Vector3.ZERO
		_car.angular_velocity = Vector3.ZERO
		_car.freeze = true
		await get_tree().physics_frame
	_car.freeze = false
	_car.set_physics_process(true)
	await get_tree().physics_frame


func _sample(tag: String) -> void:
	var fps: Array[float] = []
	var draws: Array[float] = []
	var objects: Array[float] = []
	for i in 24:
		await get_tree().process_frame
		if i < 8:
			continue
		fps.append(Performance.get_monitor(Performance.TIME_FPS))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	fps.sort()
	draws.sort()
	objects.sort()
	var bodies := 0
	_count_bodies(self, {"n": 0})
	# recount properly
	bodies = _count_static(self)
	print(
		"PERF ", tag,
		" fps_med ", snapped(fps[fps.size() / 2], 0.1),
		" draws_med ", snapped(draws[draws.size() / 2], 1.0),
		" objects_med ", snapped(objects[objects.size() / 2], 1.0),
		" static_bodies ", bodies,
		" buildings ", _meta.size()
	)


func _count_bodies(_n: Node, _acc: Dictionary) -> void:
	pass


func _count_static(n: Node) -> int:
	var c := 1 if n is StaticBody3D else 0
	for ch in n.get_children():
		c += _count_static(ch)
	return c


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var src := get_viewport().get_texture().get_image()
	var image := Image.create(src.get_width(), src.get_height(), false, src.get_format())
	image.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i.ZERO)
	image.save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)
