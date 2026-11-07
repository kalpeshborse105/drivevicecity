extends Node3D
## Isolated asset fit test. Production Blosm city stays unchanged.

const OSM := "res://assets/maps/dhule_city.osm"
const MAP := "res://assets/maps/dhule_roads_game.json"
const LAT0 := 20.902
const LON0 := 74.777
const M_LAT := 111320.0
const COURT := "482794524"
const SHOP_ESTIMATE := "1337951728"
const HOUSE := "res://assets/kit/buildings/indian_house.glb"
const SHOP := "res://assets/kit/buildings/bhelpuri_shop.glb"
const STREET_PACK := "res://assets/kit/props/street_asset_pack.glb"
const IDS: Array[String] = [
	"1337953920", "1337952466", "1337951727", "1337952467",
	"1337953903", "1337951730", "1337953905", "1337953919",
	"1337953924", "1337953918", "1337951724", "1337953921",
	"1337951726", "1337953904", "1337951729", "1337952468",
	"1337953902", "1337951728", "1337951722", "1337952469",
	"1337951719", "1337952474", "1337951720", "1337951715",
]

const BuildingAssetFitter = preload("res://scripts/building_asset_fitter.gd")
const RoadSurface = preload("res://scripts/road_surface.gd")
const AssetKit = preload("res://scripts/asset_kit.gd")

var _car: VehicleBody3D
var _cam: Camera3D
var _aerial := false
var _follow := true
var _debug := true
var _origin := Vector3(-636.54, 0.42, 881.83)
var _bump := {}
var _views := {}
var _result := {}


func _ready() -> void:
	_car = $PlayerCar
	_cam = $ChaseCam
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	var spawn: Dictionary = data["spawn"]
	_origin = Vector3(float(spawn["x"]), 0.42, float(spawn["z"]))
	_ground(_origin)
	_roads(data)
	var segments := _road_segments(data)
	var specs := _load_specs(segments)
	_result = BuildingAssetFitter.place_neighbourhood(self, specs, segments, {"debug": true, "assets": true})
	_shelf()
	_car.set_spawn(_origin, Vector2(float(spawn["hx"]), float(spawn["hz"])))
	print("ASSET_TEST ", {
		"fitted": _result.get("fitted", 0),
		"procedural": _result.get("procedural", 0),
		"rejected": _result.get("rejected", 0),
	})
	for row_v in _result.get("reports", []):
		var row: Dictionary = row_v
		print(
			"AUDIT ",
			row["id"],
			" asset=",
			row["asset"],
			" result=",
			row["result"],
			" clear=",
			row["clearance"],
			" inside=",
			row["inside_polygon"],
			" road=",
			row["road_overlap"],
			" reason=",
			row["reason"]
		)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			_aerial = not _aerial
		elif event.keycode == KEY_V:
			_debug = not _debug
			var dbg := get_node_or_null("AssetNeighbourhood/ClearanceDebug")
			if dbg:
				dbg.visible = _debug


func lock_view(pos: Vector3, at: Vector3) -> void:
	_follow = false
	var car_cam := _car.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if car_cam:
		car_cam.current = false
	_cam.current = true
	_cam.far = 320.0
	_cam.global_position = pos
	if pos.distance_to(at) > 0.4:
		_cam.look_at(at, Vector3.UP)


func run_capture() -> void:
	var street := _view_from("1337953920", 14.0, 2.8, 4.0)
	var aerial_pos := Vector3(-620.0, 78.0, 850.0)
	var aerial_at := Vector3(-640.0, 0.0, 890.0)
	var shelf_pos := _origin + Vector3(28, 3.8, -20)
	var shelf_at := _origin + Vector3(28, 1.5, -8)
	_car.visible = false
	var dbg := get_node_or_null("AssetNeighbourhood/ClearanceDebug")
	if dbg:
		dbg.visible = false
	lock_view(street["pos"], street["at"])
	await _frames(10)
	await _shot("res://docs/qa/48-street.png")
	await _sample("asset_street")
	lock_view(aerial_pos, aerial_at)
	await _frames(6)
	await _shot("res://docs/qa/48-aerial.png")
	await _sample("asset_aerial")
	if dbg:
		dbg.visible = true
	lock_view(aerial_pos + Vector3(0, -20, 0), aerial_at)
	await _frames(6)
	await _shot("res://docs/qa/48-clearance.png")
	if dbg:
		dbg.visible = false
	lock_view(shelf_pos, shelf_at)
	await _frames(8)
	await _shot("res://docs/qa/48-compare.png")
	_car.visible = true
	await _drive()


func _process(_delta: float) -> void:
	if not _follow or _cam == null or _car == null:
		return
	var car_cam := _car.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if car_cam:
		car_cam.current = false
	_cam.current = true
	if _aerial:
		_cam.global_position = _origin + Vector3(18, 70, 22)
		_cam.look_at(_origin + Vector3(0, 1, 8), Vector3.UP)
		return
	var back := _car.global_transform.basis.z
	_cam.global_position = _car.global_position - back * 8.0 + Vector3(0, 2.8, 0)
	_cam.look_at(_car.global_position + Vector3(0, 1.1, 0) + back * 4.0, Vector3.UP)


func _shelf() -> void:
	var shelf := Node3D.new()
	shelf.name = "AssetShelf"
	add_child(shelf)
	var base := _origin + Vector3(28, 0, -8)
	_label(shelf, base + Vector3(0, 3.2, 0), "original assets")
	_place_raw(shelf, HOUSE, base + Vector3(-6, 0, 0), "indian_house raw")
	_place_norm(shelf, HOUSE, base + Vector3(0, 0, 0), "indian_house 8m")
	_place_norm(shelf, SHOP, base + Vector3(6, 0, 0), "bhelpuri cart")
	_label(shelf, base + Vector3(12, 2.2, 0), "street pack = props only")
	# Do not instance street_asset_pack.glb here — it is a 46-mesh prop diorama (~56 MB) and not a building.


func _place_raw(parent: Node3D, path: String, at: Vector3, title: String) -> void:
	if not AssetKit.exists(path):
		return
	var n := AssetKit.instance(path)
	if n == null:
		return
	n.position = at
	var a := AssetKit.mesh_aabb(n)
	n.position.y = at.y - a.position.y
	parent.add_child(n)
	_label(parent, at + Vector3(0, a.size.y + 0.6, 0), title)


func _place_norm(parent: Node3D, path: String, at: Vector3, title: String) -> void:
	if not AssetKit.exists(path):
		return
	var n := AssetKit.normalized(path)
	if n == null:
		return
	n.position = at
	var a := AssetKit.mesh_aabb(n)
	n.position.y = at.y - a.position.y
	parent.add_child(n)
	_label(parent, at + Vector3(0, a.size.y + 0.6, 0), title)


func _find_named(n: Node, want: String) -> Node:
	if str(n.name) == want:
		return n
	for c in n.get_children():
		var hit := _find_named(c, want)
		if hit:
			return hit
	return null


func _label(parent: Node3D, at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 42
	label.pixel_size = 0.02
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)


func _load_specs(segments: Array) -> Array:
	var raw := _read_osm()
	var specs: Array = []
	for id in IDS:
		if id == COURT or not raw.has(id):
			continue
		var row: Dictionary = raw[id]
		var poly: PackedVector2Array = row["poly"]
		_wind(poly)
		var area := _area(poly)
		var front := _front_edge(poly, segments)
		if float(front["clear"]) < 2.0:
			print("SKIP road ", id, " clear ", snapped(float(front["clear"]), 0.01))
			continue
		var kind := _classify(id, row["tags"], area, float(front["face"]), float(front["longest"]))
		var outward: Vector2 = front["outward"]
		var edge_a: Vector2 = poly[int(front["index"])]
		var edge_b: Vector2 = poly[(int(front["index"]) + 1) % poly.size()]
		var front_mid := (edge_a + edge_b) * 0.5
		_views[id] = {"mid": front_mid, "out": outward}
		if id == "1337953920":
			var mid_poly := Vector2.ZERO
			for p in poly:
				mid_poly += p
			mid_poly /= float(poly.size())
			var approach := mid_poly + outward * 6.0
			_bump = {"x": approach.x, "z": approach.y, "hx": -outward.x, "hz": -outward.y, "id": id}
		specs.append({
			"id": id,
			"poly": poly,
			"floors": int(kind["floors"]),
			"style": str(kind["style"]),
			"front": int(front["index"]),
			"front_clear": float(front["clear"]),
			"source": str(kind["source"]),
			"area": area,
			"verts": poly.size(),
		})
	return specs


func _classify(id: String, tags: Dictionary, area: float, face: float, longest: float) -> Dictionary:
	var bld := str(tags.get("building", "yes"))
	var floors := 1
	var source := "estimated"
	if tags.has("height"):
		source = "verified_height"
		floors = maxi(1, int(float(str(tags["height"])) / 3.1))
	elif tags.has("building:levels"):
		source = "verified_levels"
		floors = maxi(1, int(str(tags["building:levels"])))
	var style := "cottage"
	if bld == "apartments" or (source != "estimated" and floors >= 3):
		style = "apartment"
	elif str(tags.get("shop", "")) != "" or bld in ["commercial", "retail"]:
		style = "commercial" if area >= 160.0 else "shop"
		if source == "estimated":
			floors = 2 if area >= 70.0 else 1
	elif id == SHOP_ESTIMATE:
		style = "shop"
		floors = 2
		source = "visual_estimate"
	elif area >= 180.0 and area <= 500.0:
		style = "family"
		floors = 2
	elif face < 4.6 and longest > 8.0:
		style = "row"
		floors = 2 if area >= 72.0 else 1
	elif area < 72.0:
		style = "cottage"
		floors = 1
	else:
		style = "family"
		floors = 2
	return {"style": style, "floors": floors, "source": source}


func _view_from(id: String, back: float, lift: float, side: float) -> Dictionary:
	var view: Dictionary = _views[id]
	var mid: Vector2 = view["mid"]
	var out: Vector2 = view["out"]
	var lateral := Vector2(-out.y, out.x)
	var pos := mid + out * back + lateral * side
	return {
		"pos": Vector3(pos.x, lift, pos.y),
		"at": Vector3(mid.x + lateral.x * side * 0.25, 1.6, mid.y + lateral.y * side * 0.25),
	}


func _drive() -> void:
	if _bump.is_empty():
		print("DRIVE missing target")
		return
	_follow = false
	_car.visible = true
	var house := get_node_or_null("AssetNeighbourhood/FittedAssets/asset_%s" % str(_bump["id"])) as Node3D
	var toward := Vector3(float(_bump["hx"]), 0.0, float(_bump["hz"]))
	var start := Vector3(float(_bump["x"]), 0.42, float(_bump["z"]))
	if house:
		var box := AssetKit.mesh_aabb(house)
		var mid := box.position + box.size * 0.5
		toward = (Vector3(mid.x, 0.0, mid.z) - start).normalized()
		if toward.length() < 0.1:
			toward = Vector3(float(_bump["hx"]), 0.0, float(_bump["hz"]))
	_car.set_spawn(start, Vector2(toward.x, toward.z))
	Input.action_press("accelerate")
	var peak := 0.0
	var elapsed := 0.0
	while elapsed < 4.0:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		peak = maxf(peak, _car.linear_velocity.length() * 3.6)
	Input.action_release("accelerate")
	var speed := _car.linear_velocity.length() * 3.6
	var at := _car.global_position
	var hit_name := ""
	var query := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.3, 0), at + Vector3(0, 1.3, 0) + toward * 10.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		hit_name = str(hit["collider"])
	lock_view(at - toward * 7.0 + Vector3(0, 2.4, 0), at + Vector3(0, 1.2, 0))
	await _frames(4)
	await _shot("res://docs/qa/48-collision.png")
	print("DRIVE id ", _bump["id"], " hit ", hit_name, " speed ", snapped(speed, 0.1), " peak ", snapped(peak, 0.1), " at ", snapped(at.x, 0.1), " ", snapped(at.z, 0.1))


func _sample(tag: String) -> void:
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
	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var static_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	print("PERF ", tag, " fps_med ", snapped(fps[fps.size() / 2], 0.1), " fps_min ", snapped(fps[0], 0.1), " draws_med ", snapped(draws[draws.size() / 2], 1.0), " vram ", snapped(vram, 0.1), " static ", snapped(static_mb, 0.1))


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var src := get_viewport().get_texture().get_image()
	var image := Image.create(src.get_width(), src.get_height(), false, src.get_format())
	image.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i.ZERO)
	image.save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path, " cam ", _cam.global_position)


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
			nodes[parser.get_named_attribute_value_safe("id")] = _xz(
				float(parser.get_named_attribute_value_safe("lat")),
				float(parser.get_named_attribute_value_safe("lon"))
			)
		elif kind == XMLParser.NODE_ELEMENT and name == "way":
			current = parser.get_named_attribute_value_safe("id")
			refs = PackedStringArray()
			tags = {}
		elif kind == XMLParser.NODE_ELEMENT and name == "nd" and wanted.has(current):
			refs.append(parser.get_named_attribute_value_safe("ref"))
		elif kind == XMLParser.NODE_ELEMENT and name == "tag" and wanted.has(current):
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


func _front_edge(poly: PackedVector2Array, segments: Array) -> Dictionary:
	var best_clear := 1.0e9
	var rows: Array = []
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var hit := _nearest_road((a + b) * 0.5, segments)
		var clear := float(hit["dist"]) - float(hit["half"])
		rows.append({"i": i, "clear": clear, "len": a.distance_to(b)})
		if clear < best_clear:
			best_clear = clear
	var face := 0.0
	var longest := 0.0
	var front_i := 0
	var front_len := -1.0
	for row_v in rows:
		var row: Dictionary = row_v
		var length := float(row["len"])
		if length > longest:
			longest = length
		if float(row["clear"]) <= best_clear + 1.6 and length >= 1.2:
			face += length
			if length > front_len:
				front_len = length
				front_i = int(row["i"])
	var a2: Vector2 = poly[front_i]
	var b2: Vector2 = poly[(front_i + 1) % poly.size()]
	var edge := b2 - a2
	var outward := Vector2.RIGHT
	if edge.length() > 0.01:
		outward = Vector2(-edge.y, edge.x) / edge.length()
	return {"index": front_i, "clear": best_clear, "face": face, "longest": longest, "outward": outward}


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
	var origin := Vector2(_origin.x, _origin.z)
	for road_v in data["roads"]:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		var half := float(road.get("width", 7.0)) * 0.5
		for i in range(pts.size() - 1):
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			if a.distance_to(origin) > 240.0 and b.distance_to(origin) > 240.0:
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
		var near := false
		for p in road.get("points", []):
			if Vector2(float(p[0]) - _origin.x, float(p[1]) - _origin.z).length() < 210.0:
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
	shape.size = Vector3(520, 0.4, 520)
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
