extends Node3D
## Isolated Mumbai Fort OSM road prototype — roads + collision only.
## Does NOT touch Dhule. Does NOT use mumbai_city.glb for roads.

signal map_ready(spawn_position: Vector3, spawn_heading: Vector2, anchors: Array)

const StreetKit = preload("res://scripts/street_kit.gd")
const AssetKit = preload("res://scripts/asset_kit.gd")

@export_file("*.json") var map_json_path: String = "res://assets/maps/mumbai_fort_roads_game.json"
@export var road_y: float = 0.04

var spawn_position: Vector3 = Vector3(0, 0.55, 0)
var spawn_heading: Vector2 = Vector2(0, -1)
var road_segment_count: int = 0
var junction_count: int = 0

var _asphalt: StandardMaterial3D
var _major: StandardMaterial3D
var _edge: StandardMaterial3D
var _curb: StandardMaterial3D
var _road_samples: Array[Vector3] = []


func _ready() -> void:
	if not FileAccess.file_exists(map_json_path):
		push_error("Mumbai map JSON missing: %s" % map_json_path)
		return
	var file := FileAccess.open(map_json_path, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid Mumbai game JSON")
		return
	_build(data as Dictionary)
	call_deferred("_emit_ready")


func _emit_ready() -> void:
	map_ready.emit(spawn_position, spawn_heading, [])


func _mat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	return StreetKit.mat(color, rough)


func _build(data: Dictionary) -> void:
	_asphalt = _kit_or_flat("street_road", Color(0.22, 0.22, 0.24), 0.9)
	_major = _kit_or_flat("avenue_street", Color(0.2, 0.2, 0.22), 0.86)
	_edge = _mat(Color(0.88, 0.88, 0.86), 0.7)
	_curb = _mat(Color(0.5, 0.48, 0.44), 0.95)

	var clip := float(data.get("clip_radius_m", 900.0))
	_add_ground(clip)

	var roads: Array = data.get("roads", [])
	junction_count = int(data.get("junction_clusters_approx", 0))
	for road_v in roads:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		if pts.size() < 2:
			continue
		var width: float = float(road.get("width", 7.0))
		var hw: String = str(road.get("highway", "residential"))
		var is_major := hw in ["primary", "secondary", "trunk", "motorway", "tertiary"]
		var mat := _major if is_major else _asphalt
		road_segment_count += _build_road_strip(pts, width, mat, is_major)

	if data.has("spawn"):
		var s: Dictionary = data["spawn"]
		spawn_position = Vector3(float(s.get("x", 0)), 0.55, float(s.get("z", 0)))
		spawn_heading = Vector2(float(s.get("hx", 0)), float(s.get("hz", -1)))
	elif not roads.is_empty():
		var p0: Array = (roads[0] as Dictionary)["points"][0]
		spawn_position = Vector3(float(p0[0]), 0.55, float(p0[1]))

	print(
		"MUMBAI_PROTO map: roads=%d segs=%d junctions~%d spawn=(%.1f,%.1f) attr=%s"
		% [
			roads.size(),
			road_segment_count,
			junction_count,
			spawn_position.x,
			spawn_position.z,
			str(data.get("attribution", "")),
		]
	)


func _kit_or_flat(kit_key: String, tint: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = rough
	var tex := AssetKit.road_albedo_clean(kit_key)
	if tex:
		m.albedo_texture = tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _add_ground(clip: float) -> void:
	var size := clip * 2.2
	var ground := _mat(Color(0.35, 0.38, 0.28), 0.95)
	StreetKit.add_box(self, Vector3(size, 1.0, size), Vector3(0, -0.5, 0), ground, true)


func _build_road_strip(pts: Array, width: float, mat: Material, is_major: bool) -> int:
	var n := 0
	var tile_m := 12.0 if is_major else 10.0
	var i := 0
	while i < pts.size() - 1:
		var a0: Array = pts[i]
		var b0: Array = pts[i + 1]
		var p_start := Vector3(float(a0[0]), road_y, float(a0[1]))
		var p_next := Vector3(float(b0[0]), road_y, float(b0[1]))
		var d0 := p_next - p_start
		var len0 := d0.length()
		if len0 < 0.5:
			i += 1
			continue
		var dir0 := d0 / len0
		# Merge nearly colinear short segments into one deck
		var p_end := p_next
		var j := i + 1
		var run_len := len0
		while j < pts.size() - 1 and run_len < 28.0:
			var a1: Array = pts[j]
			var b1: Array = pts[j + 1]
			var q0 := Vector3(float(a1[0]), road_y, float(a1[1]))
			var q1 := Vector3(float(b1[0]), road_y, float(b1[1]))
			var dj := q1 - q0
			var lj := dj.length()
			if lj < 0.4:
				j += 1
				continue
			var dirj := dj / lj
			if dir0.dot(dirj) < 0.92:
				break
			p_end = q1
			run_len += lj
			j += 1
		var delta := p_end - p_start
		var length := delta.length()
		if length < 0.5:
			i = maxi(j, i + 1)
			continue
		var dir := delta / length
		var mid := p_start + dir * (length * 0.5)
		var yaw := atan2(dir.x, dir.z)
		var deck_len := length + 0.35
		var deck_pos := mid + Vector3(0, 0.0, 0)
		StreetKit.add_road_deck(self, width, deck_len, deck_pos, yaw, mat, tile_m, true)
		# Matching collision — top near road surface (not one giant city collider)
		StreetKit.add_box(
			self,
			Vector3(width * 0.98, 0.28, deck_len),
			mid + Vector3(0, -0.12, 0),
			mat,
			true,
			yaw
		)
		# Edge paint + curbs on majors
		var side := Vector3(-dir.z, 0, dir.x)
		StreetKit.add_box(
			self,
			Vector3(0.16, 0.03, length),
			mid + side * (width * 0.5 - 0.2) + Vector3(0, 0.02, 0),
			_edge,
			false,
			yaw
		)
		StreetKit.add_box(
			self,
			Vector3(0.16, 0.03, length),
			mid - side * (width * 0.5 - 0.2) + Vector3(0, 0.02, 0),
			_edge,
			false,
			yaw
		)
		if is_major and width >= 8.0:
			StreetKit.add_box(
				self,
				Vector3(0.28, 0.18, minf(length, 10.0)),
				mid + side * (width * 0.5 + 0.2) + Vector3(0, 0.05, 0),
				_curb,
				false,
				yaw
			)
			StreetKit.add_box(
				self,
				Vector3(0.28, 0.18, minf(length, 10.0)),
				mid - side * (width * 0.5 + 0.2) + Vector3(0, 0.05, 0),
				_curb,
				false,
				yaw
			)
		_road_samples.append(Vector3(mid.x, 0.0, mid.z))
		n += 1
		i = maxi(j, i + 1)
	return n
