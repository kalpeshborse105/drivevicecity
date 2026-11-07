extends Node3D
## Phase 2H.3 visual QA: junctions, crosswalks, shadows, refined prototype shells.


const MAP := "res://assets/maps/dhule_roads_game.json"
const OSM := "res://assets/maps/dhule_city.osm"
const LAT0 := 20.902
const LON0 := 74.777
const M_LAT := 111320.0

const IDS: Array[String] = [
	"1337953920", "1337953903", "1337951730", "1337953921",
	"1337953918", "1337953905", "1337952466", "1337951722",
]

const BuildingShell = preload("res://scripts/building_shell.gd")
const DhuleBuildingStyles = preload("res://scripts/dhule_building_styles.gd")
const RoadSurface = preload("res://scripts/road_surface.gd")
const RoadJunctions = preload("res://scripts/road_junctions.gd")
const AssetKit = preload("res://scripts/asset_kit.gd")
const DhuleShadowPolicy = preload("res://scripts/dhule_shadow_policy.gd")
const RoadCrosswalk = preload("res://scripts/road_crosswalk.gd")

var _car: VehicleBody3D
var _cam: Camera3D
var _aerial := false
var _follow := true
var _origin := Vector3(-636.54, 0.42, 881.83)
var _hud: Label
var _shadow_diag := false
var _junction_debug := false
var _detail := false
var _debug_root: Node3D


func _ready() -> void:
	_car = $PlayerCar
	_cam = $ChaseCam
	_hud_ui()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	var spawn: Dictionary = data["spawn"]
	_origin = Vector3(float(spawn["x"]), 0.42, float(spawn["z"]))
	_ground()
	# One prepare pass for synthetic + nearby OSM so clips stay valid for paint clipping.
	_build_all_roads(data)
	_buildings()
	_place_barrier()
	_car.set_spawn(_origin + Vector3(0, 0, -4), Vector2(float(spawn["hx"]), float(spawn["hz"])))
	print("VISUAL_QA ready junctions ", RoadJunctions.summary, " crosswalks ", RoadCrosswalk.placed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				_aerial = not _aerial
			KEY_J:
				_junction_debug = not _junction_debug
				_draw_junction_debug()
			KEY_S:
				_shadow_diag = not _shadow_diag
				_print_shadow_diag()
			KEY_B:
				_detail = not _detail
				_follow = not _detail
				if _detail:
					lock_view(_origin + Vector3(6, 3.2, 10), _origin + Vector3(-2, 2.0, 18))
			KEY_G:
				get_tree().debug_collisions_hint = not get_tree().debug_collisions_hint


func lock_view(pos: Vector3, at: Vector3) -> void:
	_follow = false
	_cam.current = true
	_cam.global_position = pos
	if pos.distance_to(at) > 0.4:
		_cam.look_at(at, Vector3.UP)


func run_capture() -> void:
	await _frames(10)
	lock_view(_origin + Vector3(8, 18, 12), _origin + Vector3(0, 0.2, 6))
	await _frames(6)
	await _shot("res://docs/qa/57-junction-after.png")
	lock_view(_origin + Vector3(-6, 3.5, 4), _origin + Vector3(4, 0.2, 10))
	await _frames(5)
	await _shot("res://docs/qa/57-markings-close.png")
	_print_shadow_diag()
	lock_view(_origin + Vector3(20, 28, -10), _origin)
	await _frames(5)
	await _shot("res://docs/qa/58-shadow-diag.png")
	_follow = true
	_aerial = false
	await _frames(8)
	await _shot("res://docs/qa/58-shadow-moving.png")
	lock_view(_origin + Vector3(-4, 2.6, 8), _origin + Vector3(2, 1.5, 16))
	await _frames(5)
	await _shot("res://docs/qa/59-buildings-street.png")
	lock_view(_origin + Vector3(16, 36, 20), _origin + Vector3(0, 1, 12))
	await _frames(5)
	await _shot("res://docs/qa/59-buildings-aerial.png")
	await _sample()


func _process(_delta: float) -> void:
	if _hud:
		_hud.text = "C aerial | J junction debug | S shadow diag | B building detail | G collision\ncrosswalks %s  shadow %s" % [
			RoadCrosswalk.placed,
			DhuleShadowPolicy.last_report.get("blosm_shadow_mode", "?"),
		]
	if not _follow or _cam == null or _car == null:
		return
	var car_cam := _car.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if car_cam:
		car_cam.current = false
	_cam.current = true
	if _aerial:
		_cam.global_position = _origin + Vector3(12, 42, 18)
		_cam.look_at(_origin + Vector3(0, 0.5, 8), Vector3.UP)
		return
	var back := _car.global_transform.basis.z
	_cam.global_position = _car.global_position - back * 8.0 + Vector3(0, 2.8, 0)
	_cam.look_at(_car.global_position + Vector3(0, 1.1, 0) + back * 4.0, Vector3.UP)


func _build_all_roads(data: Dictionary) -> void:
	var asphalt := _mat(Color(0.28, 0.28, 0.3))
	var major := _mat(Color(0.26, 0.26, 0.28))
	var paint := _mat(Color(0.93, 0.93, 0.9))
	paint.render_priority = 3
	var base := Vector2(_origin.x - 55.0, _origin.z + 20.0)
	var roads: Array = []
	# Arms must meet at endpoints — junction prepare clusters tips, not mid-crossings.
	roads.append(_way("qa_x_n", [[base.x, base.y - 18], [base.x, base.y]], 7.5, "residential"))
	roads.append(_way("qa_x_s", [[base.x, base.y + 18], [base.x, base.y]], 7.5, "residential"))
	roads.append(_way("qa_x_e", [[base.x + 18, base.y], [base.x, base.y]], 7.5, "residential"))
	roads.append(_way("qa_x_w", [[base.x - 18, base.y], [base.x, base.y]], 6.2, "residential"))
	var t := base + Vector2(42, 0)
	roads.append(_way("qa_t_w", [[t.x - 20, t.y], [t.x, t.y]], 8.0, "secondary"))
	roads.append(_way("qa_t_e", [[t.x + 20, t.y], [t.x, t.y]], 8.0, "secondary"))
	roads.append(_way("qa_t_stem", [[t.x, t.y + 16], [t.x, t.y]], 6.5, "residential"))
	var a := base + Vector2(0, 40)
	roads.append(_way("qa_ang_a", [[a.x - 16, a.y], [a.x, a.y]], 7.0, "residential"))
	roads.append(_way("qa_ang_b", [[a.x + 14, a.y + 8], [a.x, a.y]], 6.0, "residential"))
	var r := base + Vector2(42, 40)
	roads.append(_way("qa_ra_w", [[r.x - 14, r.y], [r.x, r.y]], 9.0, "secondary"))
	roads.append(_way("qa_ra_e", [[r.x + 14, r.y], [r.x, r.y]], 9.0, "secondary"))
	roads.append(_way("qa_rb_n", [[r.x, r.y - 14], [r.x, r.y]], 8.5, "residential"))
	roads.append(_way("qa_rb_s", [[r.x, r.y + 14], [r.x, r.y]], 8.5, "residential"))
	for road_v in data["roads"]:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		for p in pts:
			if Vector2(float(p[0]) - _origin.x, float(p[1]) - _origin.z).length() < 70.0:
				roads.append(road)
				break
	RoadSurface.begin_batch(self)
	RoadSurface.prepare_junctions(roads)
	for road_v in roads:
		var road: Dictionary = road_v
		var hw := str(road.get("highway", "residential"))
		var mat: Material = major if hw in ["secondary", "primary", "tertiary"] else asphalt
		RoadSurface.add_way(self, road.get("points", []), float(road.get("width", 7.0)), 0.04, mat, paint, hw)
	RoadSurface.draw_prepared_junctions(self, 0.04, asphalt, major, paint)
	RoadSurface.flush_batch()


func _way(id: String, pts: Array, width: float, highway: String) -> Dictionary:
	return {"id": id, "points": pts, "width": width, "highway": highway}


func _buildings() -> void:
	var raw := _read_osm()
	var specs: Array = []
	var party: Array = []
	for id in IDS:
		if not raw.has(id):
			continue
		var row: Dictionary = raw[id]
		var poly: PackedVector2Array = row["poly"]
		if _signed(poly) < 0.0:
			poly.reverse()
		var area := absf(_signed(poly))
		var span_min := minf(_span(poly, true), _span(poly, false))
		var span_max := maxf(_span(poly, true), _span(poly, false))
		var style := DhuleBuildingStyles.choose(area, span_min, span_max, id)
		var floors := DhuleBuildingStyles.estimated_floors(style, area)
		specs.append({
			"id": id,
			"poly": poly,
			"floors": floors,
			"style": DhuleBuildingStyles.shell_style(style),
			"front": 0,
			"front_clear": 6.0,
		})
		party.append({"id": id, "poly": poly})
	BuildingShell.add_neighbourhood(self, specs, party)


func _place_barrier() -> void:
	var path := AssetKit.prop_path("barrier")
	if path == "" or not AssetKit.exists(path):
		return
	var n := AssetKit.place_at(self, path, _origin + Vector3(-12, 0, 14), 0.4, 1.0)
	if n:
		_disable_shadows_optional(n)


func _disable_shadows_optional(n: Node) -> void:
	# Keep solid props casting — only strip if needed later.
	pass


func _draw_junction_debug() -> void:
	if _debug_root:
		_debug_root.queue_free()
		_debug_root = null
	if not _junction_debug:
		return
	_debug_root = Node3D.new()
	_debug_root.name = "JunctionDebug"
	add_child(_debug_root)
	for jv in RoadJunctions.clips:
		var j: Dictionary = jv
		var c: Vector2 = j["c"]
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.45
		mi.mesh = sphere
		mi.position = Vector3(c.x, 0.5, c.y)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.4, 0.1)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_debug_root.add_child(mi)


func _print_shadow_diag() -> void:
	var rows := DhuleShadowPolicy.diagnose(self, _cam)
	print("SHADOW_DIAG count ", rows.size())
	for i in mini(12, rows.size()):
		var r: Dictionary = rows[i]
		print("  ", r["name"], " dist=", r["dist"], " aabb=", r["aabb"], " path=", r["path"])


func _hud_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(10, 8)
	_hud.add_theme_font_size_override("font_size", 14)
	layer.add_child(_hud)


func _ground() -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(260, 0.4, 260)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(_origin.x, -0.2, _origin.z)
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mi.mesh = box
	mi.position = col.position
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.52, 0.36)
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


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
	while parser.read() == OK:
		var kind := parser.get_node_type()
		if kind != XMLParser.NODE_ELEMENT and kind != XMLParser.NODE_ELEMENT_END:
			continue
		var name := parser.get_node_name()
		if kind == XMLParser.NODE_ELEMENT and name == "node":
			nodes[parser.get_named_attribute_value_safe("id")] = _xz(
				float(parser.get_named_attribute_value_safe("lat")),
				float(parser.get_named_attribute_value_safe("lon"))
			)
		elif kind == XMLParser.NODE_ELEMENT and name == "way":
			current = parser.get_named_attribute_value_safe("id")
			refs = PackedStringArray()
		elif kind == XMLParser.NODE_ELEMENT and name == "nd" and wanted.has(current):
			refs.append(parser.get_named_attribute_value_safe("ref"))
		elif kind == XMLParser.NODE_ELEMENT_END and name == "way" and wanted.has(current):
			var poly := PackedVector2Array()
			for ref in refs:
				if nodes.has(ref):
					poly.append(nodes[ref])
			if poly.size() >= 4 and poly[0].distance_to(poly[poly.size() - 1]) < 0.05:
				poly.remove_at(poly.size() - 1)
			if poly.size() >= 3:
				out[current] = {"poly": poly}
			current = ""
	return out


func _xz(lat: float, lon: float) -> Vector2:
	var m_lon := M_LAT * cos(deg_to_rad(LAT0))
	return Vector2((lon - LON0) * m_lon, -(lat - LAT0) * M_LAT)


func _signed(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


func _span(poly: PackedVector2Array, on_x: bool) -> float:
	var mn := 1.0e9
	var mx := -1.0e9
	for p in poly:
		var v := p.x if on_x else p.y
		mn = minf(mn, v)
		mx = maxf(mx, v)
	return mx - mn


func _sample() -> void:
	var fps: Array[float] = []
	var draws: Array[float] = []
	for i in 24:
		await get_tree().process_frame
		if i < 8:
			continue
		fps.append(Performance.get_monitor(Performance.TIME_FPS))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	fps.sort()
	draws.sort()
	print(
		"PERF visual_qa fps_med ", snapped(fps[fps.size() / 2], 0.1),
		" draws_med ", snapped(draws[draws.size() / 2], 1.0),
		" crosswalks ", RoadCrosswalk.placed,
		" shadow ", DhuleShadowPolicy.last_report
	)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var src := get_viewport().get_texture().get_image()
	var image := Image.create(src.get_width(), src.get_height(), false, src.get_format())
	image.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i.ZERO)
	image.save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)
