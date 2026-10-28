extends Node3D
## OSM Dhule roads + S2 dense Indian street kits (own art).

signal map_ready(spawn_position: Vector3, spawn_heading: Vector2, anchors: Array)

const StreetKit = preload("res://scripts/street_kit.gd")

@export_file("*.json") var map_json_path: String = "res://assets/maps/dhule_roads_game.json"
@export var road_y: float = 0.04
@export var dense_radius: float = 320.0
@export var medium_radius: float = 520.0

var delivery_anchors: Array = []
var spawn_position: Vector3 = Vector3(0, 0.55, 0)
var spawn_heading: Vector2 = Vector2(0, -1)

var _asphalt: StandardMaterial3D
var _major: StandardMaterial3D
var _paint: StandardMaterial3D
var _edge: StandardMaterial3D
var _curb: StandardMaterial3D
var _sidewalk: StandardMaterial3D
var _palette: Array = []
var _road_samples: Array[Vector3] = []


func _ready() -> void:
	if not FileAccess.file_exists(map_json_path):
		push_error("OSM map JSON missing: %s" % map_json_path)
		return
	var file := FileAccess.open(map_json_path, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid OSM game JSON")
		return
	_build(data as Dictionary)
	call_deferred("_emit_map_ready")


func _emit_map_ready() -> void:
	map_ready.emit(spawn_position, spawn_heading, delivery_anchors)


func _mat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	return StreetKit.mat(color, rough)


func _anchor_from_dict(a: Dictionary) -> Dictionary:
	return {
		"pos": Vector3(float(a.get("x", 0)), 0.12, float(a.get("z", 0))),
		"heading": Vector2(float(a.get("hx", 0)), float(a.get("hz", -1))),
		"road": str(a.get("road", "")),
		"highway": str(a.get("highway", "")),
	}


func _build(data: Dictionary) -> void:
	var clip: float = float(data.get("clip_radius_m", 900.0))
	# Slightly cooler asphalt + softer edge paint (less washed yellow)
	_asphalt = _mat(Color(0.14, 0.14, 0.15), 0.94)
	_major = _mat(Color(0.18, 0.18, 0.2), 0.9)
	_paint = _mat(Color(0.88, 0.84, 0.55), 0.7)
	_edge = _mat(Color(0.88, 0.88, 0.86), 0.75)
	_curb = _mat(Color(0.5, 0.48, 0.44), 0.95)
	_sidewalk = _mat(Color(0.58, 0.56, 0.5), 0.92)
	_palette = [
		_mat(Color(0.78, 0.62, 0.42)),
		_mat(Color(0.72, 0.72, 0.68)),
		_mat(Color(0.55, 0.45, 0.38)),
		_mat(Color(0.62, 0.35, 0.28)),
		_mat(Color(0.42, 0.55, 0.48)),
		_mat(Color(0.85, 0.78, 0.62)),
		_mat(Color(0.7, 0.55, 0.55)),
	]
	_road_samples.clear()

	_add_ground(clip)

	var roads: Array = data.get("roads", [])
	# Resolve spawn early so density uses it
	_resolve_spawn(data, roads)

	var rng := RandomNumberGenerator.new()
	rng.seed = 742021
	var shops := 0
	var props := 0

	for road_v in roads:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		if pts.size() < 2:
			continue
		var width: float = float(road.get("width", 7.0))
		var hw: String = str(road.get("highway", "residential"))
		var mat := _major if hw in ["primary", "secondary", "trunk", "motorway", "tertiary"] else _asphalt
		_build_road_strip(pts, width, mat)
		_build_edge_lines(pts, width)
		if hw in ["primary", "secondary", "trunk", "tertiary"]:
			_build_center_dashes(pts)
			_build_curbs(pts, width)
		_sample_road(pts, width)

		var dens := _density_for_polyline(pts)
		if dens <= 0.0:
			continue
		shops += _dress_road_sides(pts, width, dens, rng)
		props += _dress_road_props(pts, width, dens, rng)

	delivery_anchors.clear()
	for a_v in data.get("delivery_anchors", []):
		delivery_anchors.append(_anchor_from_dict(a_v))

	var lots := _fill_empty_lots(clip, rng)
	var landmarks := _add_landmarks(rng)
	var signs := _add_road_name_signs(roads)

	_add_spawn_pad(spawn_position)

	print(
		"PHASE1 map: %d ways, shops~%d props~%d lots~%d landmarks~%d road_signs~%d spawn=(%.1f,%.1f)"
		% [roads.size(), shops, props, lots, landmarks, signs, spawn_position.x, spawn_position.z]
	)


func _resolve_spawn(data: Dictionary, roads: Array) -> void:
	if data.has("spawn"):
		var spawn_data: Dictionary = _anchor_from_dict(data["spawn"])
		spawn_position = spawn_data["pos"] + Vector3(0, 0.43, 0)
		spawn_heading = spawn_data["heading"]
		return
	if not roads.is_empty():
		var p0: Array = (roads[0] as Dictionary)["points"][0]
		spawn_position = Vector3(float(p0[0]), 1.0, float(p0[1]))
		spawn_heading = Vector2(0, -1)


func _density_for_polyline(pts: Array) -> float:
	## 1.0 = dense core, 0.45 = medium, 0 = skip dressing
	var mid: Array = pts[int(pts.size() / 2.0)]
	var d := Vector3(float(mid[0]), 0, float(mid[1])).distance_to(Vector3(spawn_position.x, 0, spawn_position.z))
	if d <= dense_radius:
		return 1.0
	if d <= medium_radius:
		return 0.45
	return 0.0


func _dress_road_sides(pts: Array, width: float, dens: float, rng: RandomNumberGenerator) -> int:
	var placed := 0
	var step := 2 if dens > 0.8 else 3
	for i in range(0, pts.size() - 1, step):
		var a: Array = pts[i]
		var b: Array = pts[mini(i + 1, pts.size() - 1)]
		var p0 := Vector3(float(a[0]), 0, float(a[1]))
		var p1 := Vector3(float(b[0]), 0, float(b[1]))
		var along := p1 - p0
		if along.length() < 4.0:
			continue
		along = along.normalized()
		var outward := Vector3(-along.z, 0, along.x)
		# Continuous sidewalk ribbons both sides
		var yaw := atan2(along.x, along.z)
		var seg_len := p0.distance_to(p1)
		var side_signs: Array[float] = [-1.0, 1.0]
		for side_sign in side_signs:
			var side: Vector3 = outward * side_sign
			var walk_pos: Vector3 = (p0 + p1) * 0.5 + side * (width * 0.5 + 1.1)
			StreetKit.add_box(
				self,
				Vector3(2.2, 0.1, maxf(seg_len, 3.0)),
				walk_pos + Vector3(0, 0.05, 0),
				_sidewalk,
				false,
				yaw
			)
			# Shop row chance
			if rng.randf() > dens * 0.85:
				continue
			var row_origin: Vector3 = p0 + side * (width * 0.5 + 2.2)
			var count := 2 if dens > 0.8 else 1
			if dens > 0.8 and rng.randf() < 0.55:
				count = rng.randi_range(2, 4)
			StreetKit.shop_row(self, row_origin, along, side, count, rng, _palette)
			placed += count
			# Fill leftover empty shoulder with compound wall (cuts “empty lot” look)
			if dens > 0.8 and rng.randf() < 0.25:
				var wall_pos: Vector3 = p0 + side * (width * 0.5 + 6.5) + along * 4.0
				StreetKit.compound_wall(self, wall_pos, along, rng.randf_range(8.0, 14.0))
	return placed


func _dress_road_props(pts: Array, width: float, dens: float, rng: RandomNumberGenerator) -> int:
	var n := 0
	var stride := 2 if dens > 0.8 else 4
	for i in range(0, pts.size() - 1, stride):
		var a: Array = pts[i]
		var b: Array = pts[mini(i + 1, pts.size() - 1)]
		var p0 := Vector3(float(a[0]), 0, float(a[1]))
		var p1 := Vector3(float(b[0]), 0, float(b[1]))
		var along := (p1 - p0)
		if along.length() < 2.0:
			continue
		along = along.normalized()
		var outward := Vector3(-along.z, 0, along.x)
		if rng.randf() < dens * 0.7:
			StreetKit.lamp(self, p0 + outward * (width * 0.5 + 1.3))
			n += 1
		if rng.randf() < dens * 0.45:
			StreetKit.tree(self, p0 - outward * (width * 0.5 + rng.randf_range(3.0, 6.0)), rng)
			n += 1
		if dens > 0.7 and rng.randf() < 0.28:
			# Parked stub on shoulder
			var park := p0 + outward * (width * 0.5 + 2.8) + along * rng.randf_range(1.0, 3.0)
			StreetKit.parked_stub(self, park, along, rng)
			n += 1
		if dens > 0.8 and rng.randf() < 0.12:
			StreetKit.billboard(self, p0 + outward * (width * 0.5 + 8.0), -outward, rng)
			n += 1
	return n


func _add_spawn_pad(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.6
	mesh.bottom_radius = 2.6
	mesh.height = 0.05
	mi.mesh = mesh
	var pad_mat := _mat(Color(0.2, 0.55, 0.95, 0.45), 0.6)
	pad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = pad_mat
	mi.position = Vector3(pos.x, 0.05, pos.z)
	add_child(mi)


func _add_ground(clip: float) -> void:
	var size := clip * 2.2
	# Dusty Maharashtra base (less “empty desert” flat color)
	StreetKit.add_box(self, Vector3(size, 1.0, size), Vector3(0, -0.5, 0), _mat(Color(0.34, 0.3, 0.24)), true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	# Mixed dirt / scrub / packed earth patches
	for _i in 55:
		var px := rng.randf_range(-clip, clip)
		var pz := rng.randf_range(-clip, clip)
		if Vector2(px, pz).length() < 35.0:
			continue
		var tone := rng.randi_range(0, 2)
		var col := Color(0.28, 0.38, 0.22) # scrub
		if tone == 1:
			col = Color(0.45, 0.38, 0.28) # packed earth
		elif tone == 2:
			col = Color(0.32, 0.3, 0.28) # dusty lot
		StreetKit.add_box(
			self,
			Vector3(rng.randf_range(16, 42), 0.07, rng.randf_range(16, 42)),
			Vector3(px, 0.02, pz),
			_mat(col)
		)


func _sample_road(pts: Array, width: float) -> void:
	var step := maxi(1, int(pts.size() / 8.0))
	for i in range(0, pts.size(), step):
		var p: Array = pts[i]
		_road_samples.append(Vector3(float(p[0]), 0.0, float(p[1])))
		# Inflate sample with half-width so lots stay off carriageway
		if width > 0.0 and i + 1 < pts.size():
			var b: Array = pts[i + 1]
			var along := Vector3(float(b[0]) - float(p[0]), 0.0, float(b[1]) - float(p[1]))
			if along.length() > 0.5:
				along = along.normalized()
				var side := Vector3(-along.z, 0, along.x) * (width * 0.5 + 4.0)
				_road_samples.append(Vector3(float(p[0]), 0.0, float(p[1])) + side)
				_road_samples.append(Vector3(float(p[0]), 0.0, float(p[1])) - side)


func _near_road(pos: Vector3, clear_m: float) -> bool:
	for s in _road_samples:
		if pos.distance_to(s) < clear_m:
			return true
	return false


func _fill_empty_lots(clip: float, rng: RandomNumberGenerator) -> int:
	## Phase 1C — plots near core, cleared off roads / spawn / mission pad.
	var n := 0
	var attempts := 90
	for _i in attempts:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(40.0, mini(dense_radius + 40.0, clip * 0.7))
		var pos := Vector3(
			spawn_position.x + cos(ang) * dist,
			0.0,
			spawn_position.z + sin(ang) * dist
		)
		if pos.distance_to(Vector3(spawn_position.x, 0, spawn_position.z)) < 30.0:
			continue
		if _near_road(pos, 14.0):
			continue
		StreetKit.filled_lot(self, pos, rng)
		n += 1
		if n >= 45:
			break
	return n


func _add_road_name_signs(roads: Array) -> int:
	## Real OSM names (not Google). Quieter labels — less debug clutter.
	var placed_names: Dictionary = {}
	var n := 0
	for road_v in roads:
		var road: Dictionary = road_v
		var road_name := str(road.get("name", "")).strip_edges()
		if road_name.is_empty():
			continue
		if placed_names.has(road_name):
			continue
		var dens := _density_for_polyline(road.get("points", []))
		if dens <= 0.0:
			continue
		var pts: Array = road.get("points", [])
		if pts.size() < 2:
			continue
		var mid_i := int(pts.size() / 2.0)
		var p: Array = pts[mid_i]
		var p1: Array = pts[mini(mid_i + 1, pts.size() - 1)]
		var pos := Vector3(float(p[0]), 0.0, float(p[1]))
		var along := Vector3(float(p1[0]) - pos.x, 0.0, float(p1[1]) - pos.z)
		if along.length() < 0.1:
			along = Vector3(0, 0, -1)
		along = along.normalized()
		var side := Vector3(-along.z, 0, along.x) * 7.2
		var label := Label3D.new()
		label.text = road_name
		label.font_size = 36
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 4
		label.modulate = Color(0.95, 0.93, 0.88, 0.92)
		label.position = pos + side + Vector3(0, 2.4, 0)
		add_child(label)
		StreetKit.add_box(self, Vector3(0.1, 2.2, 0.1), pos + side + Vector3(0, 1.1, 0), _mat(Color(0.35, 0.35, 0.38)))
		StreetKit.add_box(self, Vector3(2.2, 0.55, 0.08), pos + side + Vector3(0, 2.4, 0), _mat(Color(0.1, 0.32, 0.18)))
		placed_names[road_name] = true
		n += 1
		if n >= 10:
			break
	return n


func _add_landmarks(rng: RandomNumberGenerator) -> int:
	## Phase 1E — readable Dhule-ish props around spawn / anchors.
	var n := 0
	var forward := Vector3(spawn_heading.x, 0.0, spawn_heading.y).normalized()
	if forward.length() < 0.1:
		forward = Vector3(0, 0, -1)
	var right := Vector3(-forward.z, 0, forward.x)

	StreetKit.water_tower(self, spawn_position + forward * 55.0 + right * 28.0)
	n += 1
	StreetKit.bus_stop(self, spawn_position + forward * 22.0 + right * -12.0, forward)
	n += 1
	for _i in 5:
		var stall_pos := spawn_position + forward * rng.randf_range(18.0, 70.0) + right * rng.randf_range(-25.0, 25.0)
		StreetKit.market_stall(self, stall_pos, rng)
		n += 1

	# Extra landmarks at a few delivery anchors
	var count := mini(4, delivery_anchors.size())
	for i in count:
		var a: Dictionary = delivery_anchors[i]
		var p: Vector3 = a["pos"]
		if i % 2 == 0:
			StreetKit.bus_stop(self, p + Vector3(8, 0, 4), Vector3(1, 0, 0))
		else:
			StreetKit.water_tower(self, p + Vector3(-12, 0, 10))
		n += 1
	return n


func _build_road_strip(pts: Array, width: float, mat: Material) -> void:
	for i in range(pts.size() - 1):
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		var p0 := Vector3(float(a[0]), road_y, float(a[1]))
		var p1 := Vector3(float(b[0]), road_y, float(b[1]))
		var delta := p1 - p0
		var length := delta.length()
		if length < 0.5:
			continue
		var mid := (p0 + p1) * 0.5
		var yaw := atan2(delta.x, delta.z)
		StreetKit.add_box(self, Vector3(width, 0.12, length + 0.45), mid, mat, false, yaw)


func _build_edge_lines(pts: Array, width: float) -> void:
	for i in range(pts.size() - 1):
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		var p0 := Vector3(float(a[0]), road_y + 0.03, float(a[1]))
		var p1 := Vector3(float(b[0]), road_y + 0.03, float(b[1]))
		var delta := p1 - p0
		if delta.length() < 1.2:
			continue
		var dir := delta.normalized()
		var mid := (p0 + p1) * 0.5
		var yaw := atan2(delta.x, delta.z)
		var side := Vector3(-dir.z, 0, dir.x) * (width * 0.5 - 0.25)
		StreetKit.add_box(self, Vector3(0.18, 0.03, delta.length()), mid + side, _edge, false, yaw)
		StreetKit.add_box(self, Vector3(0.18, 0.03, delta.length()), mid - side, _edge, false, yaw)


func _build_curbs(pts: Array, width: float) -> void:
	for i in range(0, pts.size() - 1, 2):
		var a: Array = pts[i]
		var b: Array = pts[mini(i + 1, pts.size() - 1)]
		var p0 := Vector3(float(a[0]), road_y, float(a[1]))
		var p1 := Vector3(float(b[0]), road_y, float(b[1]))
		var delta := p1 - p0
		if delta.length() < 1.0:
			continue
		var dir := delta.normalized()
		var side := Vector3(-dir.z, 0, dir.x) * (width * 0.5 + 0.28)
		var mid := (p0 + p1) * 0.5
		var yaw := atan2(delta.x, delta.z)
		StreetKit.add_box(self, Vector3(0.32, 0.2, minf(delta.length(), 9.0)), mid + side + Vector3(0, 0.06, 0), _curb, false, yaw)
		StreetKit.add_box(self, Vector3(0.32, 0.2, minf(delta.length(), 9.0)), mid - side + Vector3(0, 0.06, 0), _curb, false, yaw)


func _build_center_dashes(pts: Array) -> void:
	var i := 0
	while i < pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[mini(i + 1, pts.size() - 1)]
		var p0 := Vector3(float(a[0]), road_y + 0.025, float(a[1]))
		var p1 := Vector3(float(b[0]), road_y + 0.025, float(b[1]))
		var mid := (p0 + p1) * 0.5
		var delta := p1 - p0
		if delta.length() < 2.0:
			i += 1
			continue
		StreetKit.add_box(self, Vector3(0.22, 0.035, 2.6), mid, _paint, false, atan2(delta.x, delta.z))
		i += 2
