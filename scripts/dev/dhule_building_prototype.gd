extends Node3D
## Spawn-neighbourhood shells from dhule_city.osm. Roads are drawn for context only.

const OSM := "res://assets/maps/dhule_city.osm"
const MAP := "res://assets/maps/dhule_roads_game.json"
const LAT0 := 20.902
const LON0 := 74.777
const M_LAT := 111320.0
const IDS: Array[String] = [
	"1337953920", "1337953903", "1337951730", "1337951726",
	"1337953921", "1337953918", "1337953904", "1337953905",
	"1337952466", "1337953902", "1337953919", "1337951727",
	"1337952468", "1337951724", "1337951722", "1337952467",
]

const BuildingShell = preload("res://scripts/building_shell.gd")
const RoadSurface = preload("res://scripts/road_surface.gd")
const AssetKit = preload("res://scripts/asset_kit.gd")

var _car: VehicleBody3D
var _cam: Camera3D
var _aerial := false
var _follow := true
var _origin := Vector3(-636.54, 0.42, 881.83)


func _ready() -> void:
	_car = $PlayerCar
	_cam = $ChaseCam
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	var spawn: Dictionary = data["spawn"]
	_origin = Vector3(float(spawn["x"]), 0.42, float(spawn["z"]))
	_ground(_origin)
	_roads(data)
	var built := _buildings(_road_segments(data))
	_car.set_spawn(_origin, Vector2(float(spawn["hx"]), float(spawn["hz"])))
	print("BUILDING_PROTO ", built)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		_aerial = not _aerial


func lock_view(pos: Vector3, at: Vector3) -> void:
	_follow = false
	_cam.current = true
	_cam.global_position = pos
	_cam.look_at(at, Vector3.UP)


func _process(_delta: float) -> void:
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
	var verified := 0
	for id in IDS:
		if not raw.has(id):
			push_warning("missing footprint %s" % id)
			continue
		var row: Dictionary = raw[id]
		var poly: PackedVector2Array = row["poly"]
		_wind(poly)
		var area := _area(poly)
		var floors := 1
		var style := "compact"
		var source := "estimated"
		if str(row["tags"].get("shop", "")) != "":
			style = "shop"
		elif str(row["tags"].get("building", "")) in ["commercial", "retail"]:
			style = "mixed"
		elif str(row["tags"].get("building", "")) in ["school", "college", "hospital"]:
			style = "civic"
		if row["tags"].has("height"):
			source = "verified_height"
			verified += 1
			floors = maxi(1, int(float(str(row["tags"]["height"])) / 3.1))
		elif row["tags"].has("building:levels"):
			source = "verified_levels"
			verified += 1
			floors = maxi(1, int(str(row["tags"]["building:levels"])))
		else:
			estimated += 1
			if area >= 72.0 and style == "compact":
				floors = 2
				style = "urban"
		var front := _front_edge(poly, segments)
		party.append({"id": id, "poly": poly})
		specs.append({
			"id": id,
			"poly": poly,
			"floors": floors,
			"style": style,
			"front": front["index"],
			"front_clear": front["clear"],
			"source": source,
			"area": area,
			"verts": poly.size(),
		})
		print("FOOTPRINT ", id, " verts ", poly.size(), " area ", snapped(area, 0.1), " floors ", floors, " ", source, " clear ", snapped(front["clear"], 0.01))
	var result: Dictionary = BuildingShell.add_neighbourhood(self, specs, party)
	result["estimated"] = estimated
	result["verified"] = verified
	return result


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
			var lat := float(parser.get_named_attribute_value_safe("lat"))
			var lon := float(parser.get_named_attribute_value_safe("lon"))
			nodes[nid] = _xz(lat, lon)
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
			if a.distance_to(Vector2(_origin.x, _origin.z)) > 220.0 and b.distance_to(Vector2(_origin.x, _origin.z)) > 220.0:
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
			if Vector2(float(p[0]) - _origin.x, float(p[1]) - _origin.z).length() < 160.0:
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
	shape.size = Vector3(420, 0.4, 420)
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
