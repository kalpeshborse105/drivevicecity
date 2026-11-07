extends Node3D
## Phase 2H.4B — real OSM footprint chunk pilot (40–64 buildings).
## Isolated from scenes/main.tscn. Blosm stays optional comparison only.


const OSM := "res://assets/maps/dhule_city.osm"
const MAP := "res://assets/maps/dhule_roads_game.json"
const MANIFEST := "res://docs/qa/64-chunk-pilot-manifest.json"
const BLOSM := "res://assets/models/environments/dhule_blosm_city.glb"
const LAT0 := 20.902
const LON0 := 74.777
const M_LAT := 111320.0
const CLEARANCE_OUT := "res://docs/qa/64-chunk-pilot-clearance.json"

const BuildingShell = preload("res://scripts/building_shell.gd")
const DhuleBuildingStyles = preload("res://scripts/dhule_building_styles.gd")
const AssetPlacementValidator = preload("res://scripts/asset_placement_validator.gd")
const RoadSurface = preload("res://scripts/road_surface.gd")
const AssetKit = preload("res://scripts/asset_kit.gd")

var _car: VehicleBody3D
var _cam: Camera3D
var _aerial := false
var _follow := true
var _show_chunk := true
var _show_blosm := false
var _show_ids := true
var _origin := Vector3(-636.54, 0.42, 881.83)
var _meta: Array = []
var _chunk_root: Node3D
var _blosm_root: Node3D
var _id_root: Node3D
var _hud: Label
var _clearance_rows: Array = []


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
	var built := _buildings_from_manifest(segments)
	_maybe_blosm()
	_car.set_spawn(_origin + Vector3(0, 0, -2), Vector2(float(spawn["hx"]), float(spawn["hz"])))
	_write_clearance()
	print("CHUNK_PILOT ", built)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				_aerial = not _aerial
			KEY_B:
				_show_blosm = not _show_blosm
				if _blosm_root:
					_blosm_root.visible = _show_blosm
				if _chunk_root:
					_chunk_root.visible = not _show_blosm
			KEY_V:
				_show_chunk = not _show_chunk
				if _chunk_root:
					_chunk_root.visible = _show_chunk and not _show_blosm
			KEY_I:
				_show_ids = not _show_ids
				if _id_root:
					_id_root.visible = _show_ids
			KEY_G:
				get_tree().debug_collisions_hint = not get_tree().debug_collisions_hint


func lock_view(pos: Vector3, at: Vector3) -> void:
	_follow = false
	_cam.current = true
	_cam.global_position = pos
	if pos.distance_to(at) > 0.4:
		_cam.look_at(at, Vector3.UP)


func run_capture() -> void:
	await _frames(12)
	lock_view(_origin + Vector3(28, 55, 32), _origin + Vector3(0, 1, 10))
	await _frames(8)
	await _shot("res://docs/qa/64-chunk-aerial.png")
	_follow = true
	_aerial = false
	await _frames(10)
	lock_view(_origin + Vector3(-3, 2.6, 5), _origin + Vector3(4, 1.4, 18))
	await _frames(6)
	await _shot("res://docs/qa/64-chunk-street.png")
	# Collision drive into first accepted building.
	if not _meta.is_empty():
		var m: Dictionary = _meta[0]
		await _teleport_car(Vector3(float(m["cx"]), 0.42, float(m["cz"]) - 9.0), Vector2(0, 1))
		Input.action_press("accelerate")
		var peak := 0.0
		for _i in 90:
			await get_tree().physics_frame
			peak = maxf(peak, _car.linear_velocity.length() * 3.6)
		Input.action_release("accelerate")
		print("DRIVE_HIT id=", m["osm_id"], " speed=", snapped(_car.linear_velocity.length() * 3.6, 0.1), " peak=", snapped(peak, 0.1))
		lock_view(_car.global_position + Vector3(-5, 3.0, -4), _car.global_position + Vector3(0, 1.2, 3))
		await _frames(5)
		await _shot("res://docs/qa/65-chunk-collision.png")
	# Blosm comparison still
	if _blosm_root:
		_show_blosm = true
		_blosm_root.visible = true
		if _chunk_root:
			_chunk_root.visible = false
		lock_view(_origin + Vector3(28, 55, 32), _origin + Vector3(0, 1, 10))
		await _frames(8)
		await _shot("res://docs/qa/64-blosm-compare.png")
		_show_blosm = false
		_blosm_root.visible = false
		if _chunk_root:
			_chunk_root.visible = true
	await _sample()
	print("CHUNK_PILOT_CAPTURE_DONE accepted=", _meta.size())


func _process(_delta: float) -> void:
	if _hud:
		_hud.text = (
			"C aerial | B Blosm/chunk | V chunk mesh | I OSM ids | G collision\n"
			+ "buildings %d  chunk_vis %s  blosm %s"
			% [_meta.size(), _show_chunk and not _show_blosm, _show_blosm]
		)
	if not _follow or _cam == null or _car == null:
		return
	var car_cam := _car.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if car_cam:
		car_cam.current = false
	_cam.current = true
	if _aerial:
		_cam.global_position = _origin + Vector3(22, 58, 26)
		_cam.look_at(_origin + Vector3(0, 1, 12), Vector3.UP)
		return
	var back := _car.global_transform.basis.z
	_cam.global_position = _car.global_position - back * 8.0 + Vector3(0, 2.8, 0)
	_cam.look_at(_car.global_position + Vector3(0, 1.1, 0) + back * 4.0, Vector3.UP)


func _buildings_from_manifest(segments: Array) -> Dictionary:
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var buildings: Array = man.get("buildings", [])
	var specs: Array = []
	var party: Array = []
	var estimated := 0
	var osm_levels := 0
	var rejected := 0
	_id_root = Node3D.new()
	_id_root.name = "OsmIdLabels"
	add_child(_id_root)
	_clearance_rows.clear()
	_meta.clear()
	for b_v in buildings:
		var b: Dictionary = b_v
		var id := str(b["osm_id"])
		var poly := PackedVector2Array()
		for p_v in b["polygon"]:
			var p: Dictionary = p_v
			poly.append(Vector2(float(p["x"]), float(p["z"])))
		if poly.size() < 3:
			rejected += 1
			continue
		_wind(poly)
		var area := float(b.get("area_m2", _area(poly)))
		var style_key := str(b.get("style", DhuleBuildingStyles.STYLE_A))
		var floors := int(b.get("floors", 1))
		var height_source := str(b.get("height_source", "estimated"))
		if height_source == "estimated":
			estimated += 1
		else:
			osm_levels += 1
		var front := _front_edge(poly, segments)
		var aabb := _poly_aabb(poly, 3.2)
		var clear := AssetPlacementValidator.asphalt_clearance(aabb, segments)
		var row := {
			"osm_id": id,
			"ok": true,
			"reason": "ok",
			"front_clear_m": snapped(float(front["clear"]), 0.01),
			"validator_clear_m": snapped(clear, 0.01),
			"area_m2": area,
			"style": style_key,
			"floors": floors,
			"height_source": height_source,
		}
		if float(front["clear"]) < 0.5 or clear < 0.5:
			row["ok"] = false
			row["reason"] = "road_overlap"
			_clearance_rows.append(row)
			rejected += 1
			print("REJECT ", id, " clear front=", row["front_clear_m"], " val=", row["validator_clear_m"])
			continue
		# Neighbour overlap vs already accepted polys.
		var overlap := false
		for prev in party:
			if _polys_overlap(poly, prev["poly"], 0.2):
				overlap = true
				break
		if overlap:
			row["ok"] = false
			row["reason"] = "building_overlap"
			_clearance_rows.append(row)
			rejected += 1
			print("REJECT overlap ", id)
			continue
		_clearance_rows.append(row)
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
		var cx := float(b.get("cx", 0.0))
		var cz := float(b.get("cz", 0.0))
		if cx == 0.0 and cz == 0.0:
			for p2 in poly:
				cx += p2.x
				cz += p2.y
			cx /= float(poly.size())
			cz /= float(poly.size())
		_meta.append({
			"osm_id": id,
			"area_m2": area,
			"vertices": poly.size(),
			"style_variant": style_key,
			"shell_style": shell,
			"floors": floors,
			"height_source": height_source,
			"cx": cx,
			"cz": cz,
			"front_clear_m": row["front_clear_m"],
			"validator_clear_m": row["validator_clear_m"],
			"dist_spawn_m": float(b.get("dist_spawn_m", 0.0)),
		})
		_label3d(Vector3(cx, 4.0, cz), id)
	var host := Node3D.new()
	host.name = "PilotChunkHost"
	add_child(host)
	var result: Dictionary = BuildingShell.add_neighbourhood(host, specs, party)
	_chunk_root = host.get_node_or_null("Chunk_spawn") as Node3D
	if _chunk_root == null and host.get_child_count() > 0:
		_chunk_root = host.get_child(0) as Node3D
	result["estimated"] = estimated
	result["osm_height_or_levels"] = osm_levels
	result["rejected"] = rejected
	result["accepted"] = _meta.size()
	result["manifest_count"] = buildings.size()
	result["surfaces"] = result.get("surfaces", 0)
	print(
		"CHUNK_MESH buildings=", result.get("buildings", 0),
		" surfaces=", result.get("surfaces", 0),
		" accepted=", _meta.size(),
		" rejected=", rejected
	)
	return result


func _maybe_blosm() -> void:
	if not AssetKit.exists(BLOSM):
		return
	var packed: PackedScene = load(BLOSM)
	if packed == null:
		return
	_blosm_root = packed.instantiate() as Node3D
	_blosm_root.name = "BlosmCompare"
	_blosm_root.visible = false
	add_child(_blosm_root)
	for c in _blosm_root.get_children():
		var nm := str(c.name).to_lower()
		if "water" in nm or "road" in nm:
			c.visible = false
		if c is GeometryInstance3D:
			# Comparison only — avoid giant-mesh flicker in pilot.
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _write_clearance() -> void:
	var path := ProjectSettings.globalize_path(CLEARANCE_OUT)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	var accepted := 0
	for r in _clearance_rows:
		if r.get("ok", false):
			accepted += 1
	f.store_string(JSON.stringify({
		"accepted": accepted,
		"rejected": _clearance_rows.size() - accepted,
		"margin_m": 0.5,
		"rows": _clearance_rows,
	}, "\t"))
	f.close()
	print("CLEARANCE_REPORT ", CLEARANCE_OUT, " accepted=", accepted)


func _polys_overlap(a: PackedVector2Array, b: PackedVector2Array, margin: float) -> bool:
	var aa := _poly_aabb(a, 1.0)
	var bb := _poly_aabb(b, 1.0)
	aa = aa.grow(margin)
	return aa.intersects(bb)


func _hud_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(12, 10)
	_hud.add_theme_font_size_override("font_size", 15)
	layer.add_child(_hud)


func _ground(origin: Vector3) -> void:
	var body := StaticBody3D.new()
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
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)
	add_child(body)


func _roads(data: Dictionary) -> void:
	var asphalt := _road_mat("street_road", Color(0.78, 0.78, 0.8))
	var major := _road_mat("avenue_street", Color(0.74, 0.74, 0.77))
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.93, 0.93, 0.9)
	var shown: Array = []
	for road_v in data["roads"]:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		var near := false
		for p in pts:
			if Vector2(float(p[0]) - _origin.x, float(p[1]) - _origin.z).length() < 260.0:
				near = true
				break
		if near:
			shown.append(road)
	RoadSurface.prepare_junctions(shown)
	RoadSurface.begin_batch(self)
	for road_v in shown:
		var road: Dictionary = road_v
		var hw := str(road.get("highway", "residential"))
		var mat: Material = major if hw in ["primary", "secondary", "tertiary", "trunk"] else asphalt
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
	return mat


func _road_segments(data: Dictionary) -> Array:
	var out: Array = []
	for road_v in data["roads"]:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		var half := float(road.get("width", 7.0)) * 0.5
		for i in range(pts.size() - 1):
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			if a.distance_to(Vector2(_origin.x, _origin.z)) > 280.0 and b.distance_to(Vector2(_origin.x, _origin.z)) > 280.0:
				continue
			out.append({"a": a, "b": b, "half": half})
	return out


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


func _poly_aabb(poly: PackedVector2Array, height: float) -> AABB:
	var mn := Vector2(1.0e9, 1.0e9)
	var mx := Vector2(-1.0e9, -1.0e9)
	for p in poly:
		mn.x = minf(mn.x, p.x)
		mn.y = minf(mn.y, p.y)
		mx.x = maxf(mx.x, p.x)
		mx.y = maxf(mx.y, p.y)
	return AABB(Vector3(mn.x, 0.0, mn.y), Vector3(mx.x - mn.x, height, mx.y - mn.y))


func _label3d(pos: Vector3, text: String) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 22
	lab.pixel_size = 0.01
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = pos
	lab.modulate = Color(0.95, 0.95, 0.7)
	_id_root.add_child(lab)


func _teleport_car(pos: Vector3, heading: Vector2) -> void:
	_car.global_position = pos
	_car.linear_velocity = Vector3.ZERO
	_car.angular_velocity = Vector3.ZERO
	if _car.has_method("set_spawn"):
		_car.set_spawn(pos, heading)
	await _frames(4)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)


func _sample() -> void:
	var fps: Array[float] = []
	var draws: Array[float] = []
	for i in 36:
		await get_tree().process_frame
		if i < 8:
			continue
		fps.append(Performance.get_monitor(Performance.TIME_FPS))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	fps.sort()
	draws.sort()
	print(
		"PERF chunk_pilot fps_med=", snapped(fps[fps.size() / 2], 0.1),
		" draws_med=", snapped(draws[draws.size() / 2], 1.0),
		" objects=", snapped(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), 1.0)
	)
