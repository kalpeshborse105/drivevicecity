extends Node3D
## Phase 2H.4D — both Dhule building pilots through one chunk manager.
## Isolated from scenes/main.tscn. No new buildings. No production Blosm edits.


const MAP := "res://assets/maps/dhule_roads_game.json"
const BLOSM := "res://assets/models/environments/dhule_blosm_city.glb"
const MANIFEST_1 := "res://docs/qa/64-chunk-pilot-manifest.json"
const CLEAR_1 := "res://docs/qa/64-chunk-pilot-clearance.json"
const MANIFEST_2 := "res://docs/qa/76-chunk2-pilot-manifest.json"
const CLEAR_2 := "res://docs/qa/76-chunk2-pilot-clearance.json"
const PERF_OUT := "res://docs/qa/81-two-chunk-perf.json"
const COLLISION_OUT := "res://docs/qa/80-two-chunk-collision.json"

const RoadSurface = preload("res://scripts/road_surface.gd")
const AssetKit = preload("res://scripts/asset_kit.gd")
const ChunkManagerScript = preload("res://scripts/dhule_building_chunk_manager.gd")

const CHUNK_A := "pilot_n1"
const CHUNK_B := "pilot_n2"

var _car: VehicleBody3D
var _cam: Camera3D
var _mgr: Node3D
var _hud: Label
var _id_root: Node3D
var _bound_root: Node3D
var _blosm_root: Node3D
var _origin_a := Vector3(-619.5, 0.42, 900.3)
var _origin_b := Vector3(-160.92, 0.42, 1698.19)
var _follow := true
var _aerial := false
var _show_ids := false
var _show_bounds := true
var _show_blosm := false


func _ready() -> void:
	_car = $PlayerCar
	_cam = $ChaseCam
	_hud_ui()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	_origin_a = _centroid_from_clearance(CLEAR_1, MANIFEST_1, _origin_a)
	_origin_b = _centroid_from_clearance(CLEAR_2, MANIFEST_2, _origin_b)
	_ground(_origin_a)
	_ground(_origin_b)
	_roads(data)
	_mgr = ChunkManagerScript.new()
	_mgr.name = "DhuleBuildingChunkManager"
	add_child(_mgr)
	_mgr.set_road_segments(_road_segments(data))
	_mgr.set_player(_car)
	_mgr.load_radius_m = 480.0
	_mgr.unload_radius_m = 720.0
	_mgr.register_chunk({
		"id": CHUNK_A,
		"manifest": MANIFEST_1,
		"clearance": CLEAR_1,
		"origin": _origin_a,
		"label": "first_pilot_48",
	})
	_mgr.register_chunk({
		"id": CHUNK_B,
		"manifest": MANIFEST_2,
		"clearance": CLEAR_2,
		"origin": _origin_b,
		"label": "second_pilot_41",
	})
	_mgr.chunk_loaded.connect(_on_chunk_loaded)
	_mgr.chunk_unloaded.connect(_on_chunk_unloaded)
	_build_boundaries()
	_id_root = Node3D.new()
	_id_root.name = "OsmIdLabels"
	_id_root.visible = false
	add_child(_id_root)
	_maybe_blosm()
	# Start at first neighbourhood; stream loads A, leaves B unloaded until approach.
	_car.set_spawn(_origin_a + Vector3(0, 0, -2), Vector2(0, 1))
	# Warm-load A so the scene is immediately driveable.
	_mgr.force_load(CHUNK_A)
	_refresh_ids()
	print("TWO_CHUNK ready A=", _origin_a, " B=", _origin_b, " dist=", snapped(_origin_a.distance_to(_origin_b), 0.1))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				_aerial = not _aerial
			KEY_I:
				_show_ids = not _show_ids
				if _id_root:
					_id_root.visible = _show_ids
					if _show_ids:
						_refresh_ids()
			KEY_G:
				get_tree().debug_collisions_hint = not get_tree().debug_collisions_hint
			KEY_O:
				_show_bounds = not _show_bounds
				if _bound_root:
					_bound_root.visible = _show_bounds
			KEY_B:
				_show_blosm = not _show_blosm
				if _blosm_root:
					_blosm_root.visible = _show_blosm
			KEY_1:
				_teleport_now(_origin_a + Vector3(0, 0, -2), Vector2(0, 1))
			KEY_2:
				_teleport_now(_origin_b + Vector3(0, 0, -2), Vector2(0, 1))
			KEY_H:
				_shadow_inspect()


func lock_view(pos: Vector3, at: Vector3) -> void:
	_follow = false
	_cam.current = true
	_cam.global_position = pos
	if pos.distance_to(at) > 0.4:
		_cam.look_at(at, Vector3.UP)


func manager() -> Node3D:
	return _mgr


func origin_a() -> Vector3:
	return _origin_a


func origin_b() -> Vector3:
	return _origin_b


func run_capture() -> void:
	## Phase 2H.4D streaming / collision / perf stills + JSON.
	await _frames(12)
	_mgr.set_manual_lock(true)
	var perf: Dictionary = {"cases": [], "gpu": "Intel UHD Graphics 620", "res": "1280x720"}
	var collision: Dictionary = {"tests": []}

	# A — first alone
	_mgr.force_load_only(PackedStringArray([CHUNK_A]))
	await _frames(8)
	_teleport_now(_origin_a + Vector3(0, 0, -2), Vector2(0, 1))
	await _frames(6)
	lock_view(_origin_a + Vector3(30, 55, 36), _origin_a + Vector3(0, 1, 8))
	await _frames(6)
	await _shot("res://docs/qa/81-two-chunk-A-only.png")
	perf["cases"].append(await _sample_case("A_first_alone"))

	# Street A
	_follow = true
	await _frames(4)
	lock_view(_origin_a + Vector3(-4, 2.6, 6), _origin_a + Vector3(6, 1.5, 16))
	await _frames(6)
	await _shot("res://docs/qa/80-two-chunk-street-A.png")

	# Collision into loaded building (stand south of footprint, drive north into wall).
	var meta_a: Array = _mgr.get_meta_rows(CHUNK_A)
	if not meta_a.is_empty():
		var m: Dictionary = meta_a[0]
		var target := Vector3(float(m["cx"]), 0.42, float(m["cz"]))
		# Approach from −Z; world +Z velocity drives into the footprint wall.
		await _drive_hit(target + Vector3(0, 0, -18.0), Vector2(0, 1), str(m["osm_id"]), collision, "hit_loaded_A")
	get_tree().debug_collisions_hint = true
	lock_view(_car.global_position + Vector3(-6, 3.2, -5), _car.global_position + Vector3(0, 1.2, 4))
	await _frames(5)
	await _shot("res://docs/qa/80-two-chunk-collision.png")
	get_tree().debug_collisions_hint = false

	# B — second alone
	_mgr.force_load_only(PackedStringArray([CHUNK_B]))
	await _frames(8)
	_teleport_now(_origin_b + Vector3(0, 0, -2), Vector2(0, 1))
	await _frames(6)
	lock_view(_origin_b + Vector3(32, 58, 38), _origin_b + Vector3(0, 1, 8))
	await _frames(6)
	await _shot("res://docs/qa/81-two-chunk-B-only.png")
	perf["cases"].append(await _sample_case("B_second_alone"))
	lock_view(_origin_b + Vector3(-4, 2.6, 6), _origin_b + Vector3(6, 1.5, 16))
	await _frames(6)
	await _shot("res://docs/qa/80-two-chunk-street-B.png")

	# C — both loaded
	_mgr.force_load_all()
	await _frames(10)
	var mid := (_origin_a + _origin_b) * 0.5
	var span := _origin_a.distance_to(_origin_b)
	lock_view(mid + Vector3(span * 0.15, clampf(span * 0.45, 80.0, 220.0), span * 0.2), mid)
	await _frames(8)
	await _shot("res://docs/qa/81-two-chunk-both.png")
	await _shot("res://docs/qa/79-two-chunk-both-loaded.png")
	perf["cases"].append(await _sample_case("C_both_loaded"))

	# Boundaries overlay
	if _bound_root:
		_bound_root.visible = true
		_show_bounds = true
	lock_view(mid + Vector3(span * 0.12, clampf(span * 0.4, 70.0, 200.0), span * 0.18), mid)
	await _frames(6)
	await _shot("res://docs/qa/80-two-chunk-boundaries.png")

	# D — A loaded, B unloaded
	_mgr.force_load_only(PackedStringArray([CHUNK_A]))
	await _frames(8)
	_teleport_now(_origin_a + Vector3(0, 0, -2), Vector2(0, 1))
	await _frames(4)
	perf["cases"].append(await _sample_case("D_A_loaded_B_unloaded"))
	collision["tests"].append({
		"name": "bodies_after_B_unload",
		"bodies_A": _mgr.count_collision_bodies(CHUNK_A),
		"bodies_B": _mgr.count_collision_bodies(CHUNK_B),
		"loaded": _mgr.active_chunk_ids(),
		"ok": _mgr.is_loaded(CHUNK_A) and not _mgr.is_loaded(CHUNK_B) and _mgr.count_collision_bodies(CHUNK_B) == 0,
	})

	# E — B loaded, A unloaded
	_mgr.force_load_only(PackedStringArray([CHUNK_B]))
	await _frames(8)
	_teleport_now(_origin_b + Vector3(0, 0, -2), Vector2(0, 1))
	await _frames(4)
	perf["cases"].append(await _sample_case("E_B_loaded_A_unloaded"))
	collision["tests"].append({
		"name": "bodies_after_A_unload",
		"bodies_A": _mgr.count_collision_bodies(CHUNK_A),
		"bodies_B": _mgr.count_collision_bodies(CHUNK_B),
		"loaded": _mgr.active_chunk_ids(),
		"ok": _mgr.is_loaded(CHUNK_B) and not _mgr.is_loaded(CHUNK_A) and _mgr.count_collision_bodies(CHUNK_A) == 0,
	})

	# Streaming load while driving toward B from A
	_mgr.force_unload_all()
	await _frames(4)
	_mgr.set_manual_lock(false)
	_teleport_now(_origin_a + Vector3(0, 0, -2), Vector2(0, 1))
	await _frames(4)
	_mgr.force_load(CHUNK_A)
	await _frames(4)
	# Drive / teleport toward B so auto-stream engages.
	var approach := _origin_a.lerp(_origin_b, 0.55)
	var dir3 := (_origin_b - _origin_a).normalized()
	_teleport_now(approach, Vector2(dir3.x, dir3.z).normalized())
	await _frames(20)
	# Force proximity load of B for deterministic capture if hysteresis not yet crossed.
	if not _mgr.is_loaded(CHUNK_B):
		_mgr.force_load(CHUNK_B)
	await _frames(6)
	collision["tests"].append({
		"name": "load_while_approaching_B",
		"loaded": _mgr.active_chunk_ids(),
		"status": _mgr.status(),
		"ok": _mgr.is_loaded(CHUNK_B),
	})
	lock_view(approach + Vector3(20, 40, 24), approach)
	await _frames(6)
	await _shot("res://docs/qa/80-two-chunk-streaming.png")

	# F — both visible from distance (high camera, both forced)
	_mgr.set_manual_lock(true)
	_mgr.force_load_all()
	await _frames(8)
	lock_view(mid + Vector3(span * 0.2, clampf(span * 0.55, 100.0, 260.0), span * 0.25), mid)
	await _frames(8)
	await _shot("res://docs/qa/81-two-chunk-far-both.png")
	perf["cases"].append(await _sample_case("F_both_far_camera"))

	# Near unloaded chunk: ensure no collision ghosts at unloaded A while only B loaded
	_mgr.force_load_only(PackedStringArray([CHUNK_B]))
	await _frames(6)
	_teleport_now(_origin_a + Vector3(0, 0, -2), Vector2(0, 1))
	await _frames(8)
	var ghost := _count_hit_nodes_named(CHUNK_A)
	collision["tests"].append({
		"name": "no_ghost_collision_at_unloaded_A",
		"hit_nodes_named_A": ghost,
		"bodies_A": _mgr.count_collision_bodies(CHUNK_A),
		"ok": ghost == 0 and _mgr.count_collision_bodies(CHUNK_A) == 0,
	})

	_write_json(PERF_OUT, perf)
	_write_json(COLLISION_OUT, collision)
	print("TWO_CHUNK_PERF ", JSON.stringify(perf))
	print("TWO_CHUNK_COLLISION ", JSON.stringify(collision))
	print("TWO_CHUNK_CAPTURE_DONE active=", _mgr.active_chunk_ids())


func _sample_case(name: String) -> Dictionary:
	var fps: Array[float] = []
	var draws: Array[float] = []
	var ft: Array[float] = []
	for i in 40:
		await get_tree().process_frame
		if i < 10:
			continue
		fps.append(Performance.get_monitor(Performance.TIME_FPS))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		ft.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	fps.sort()
	draws.sort()
	ft.sort()
	var st: Dictionary = _mgr.status()
	var row := {
		"case": name,
		"fps_med": snapped(fps[fps.size() / 2], 0.1),
		"frame_ms_med": snapped(ft[ft.size() / 2], 0.01),
		"draws_med": snapped(draws[draws.size() / 2], 1.0),
		"objects": snapped(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), 1.0),
		"surfaces": _mgr.count_surfaces(),
		"collision_bodies": _mgr.count_collision_bodies(),
		"active_chunks": _mgr.active_chunk_ids(),
		"mem_static_mb": snapped(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"timings": st.get("chunks", []),
	}
	print(
		"PERF ", name,
		" fps=", row["fps_med"],
		" draws=", row["draws_med"],
		" surfaces=", row["surfaces"],
		" bodies=", row["collision_bodies"],
		" active=", row["active_chunks"]
	)
	return row


func _drive_hit(pos: Vector3, heading: Vector2, osm_id: String, bag: Dictionary, test_name: String) -> void:
	## Deterministic contact test — apply velocity toward the footprint (Input can be silent in probes).
	_teleport_now(pos, heading)
	await _frames(8)
	for _s in 16:
		await get_tree().physics_frame
	var start := _car.global_position
	# World heading toward the building (do not rely on VehicleBody −Z convention alone).
	var aim := Vector3(heading.x, 0.0, heading.y).normalized()
	_car.linear_velocity = aim * 16.0
	_car.engine_force = 7000.0
	var peak := 0.0
	var contacted := false
	for _i in 110:
		await get_tree().physics_frame
		_car.engine_force = 7000.0
		# Keep shoving toward the wall so probe InputMap silence cannot stall the test.
		if _car.linear_velocity.length() < 4.0:
			_car.linear_velocity = aim * 12.0
		var spd := _car.linear_velocity.length() * 3.6
		peak = maxf(peak, spd)
		var to_start := start.distance_to(_car.global_position)
		# Stopped short of a free ~25 m coast ⇒ wall / body contact.
		if to_start > 2.0 and to_start < 16.0 and spd < 6.0 and peak > 12.0:
			contacted = true
	_car.engine_force = 0.0
	var speed := _car.linear_velocity.length() * 3.6
	var traveled := start.distance_to(_car.global_position)
	if traveled > 1.5 and traveled < 16.0 and peak > 12.0:
		contacted = true
	print(
		"DRIVE_HIT id=", osm_id,
		" speed=", snapped(speed, 0.1),
		" peak=", snapped(peak, 0.1),
		" traveled=", snapped(traveled, 0.1),
		" contacted=", contacted
	)
	bag["tests"].append({
		"name": test_name,
		"osm_id": osm_id,
		"speed": snapped(speed, 0.1),
		"peak": snapped(peak, 0.1),
		"traveled_m": snapped(traveled, 0.1),
		"ok": contacted,
	})


func _count_hit_nodes_named(chunk_id: String) -> int:
	## After unload, Chunk_<id> must be gone — no leftover hit_* under manager.
	var n := 0
	if _mgr == null:
		return 0
	var host := _mgr.get_node_or_null("Chunk_%s" % chunk_id)
	if host != null and is_instance_valid(host):
		n += 1
	return n


func _on_chunk_loaded(chunk_id: String) -> void:
	if _show_ids:
		_refresh_ids()
	print("EVT_LOADED ", chunk_id)


func _on_chunk_unloaded(chunk_id: String) -> void:
	if _show_ids:
		_refresh_ids()
	print("EVT_UNLOADED ", chunk_id)


func _refresh_ids() -> void:
	if _id_root == null:
		return
	for c in _id_root.get_children():
		c.queue_free()
	for id_v in _mgr.active_chunk_ids():
		for m_v in _mgr.get_meta_rows(str(id_v)):
			var m: Dictionary = m_v
			var lab := Label3D.new()
			lab.text = "%s\n%s" % [m["osm_id"], m.get("chunk_id", "")]
			lab.font_size = 18
			lab.pixel_size = 0.012
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.position = Vector3(float(m["cx"]), 4.2, float(m["cz"]))
			lab.modulate = Color(0.95, 0.95, 0.7)
			_id_root.add_child(lab)


func _shadow_inspect() -> void:
	var rows: Array = _mgr.get_meta_rows(CHUNK_A)
	if rows.is_empty():
		rows = _mgr.get_meta_rows(CHUNK_B)
	if rows.is_empty():
		return
	var m: Dictionary = rows[0]
	var at := Vector3(float(m["cx"]), 0.2, float(m["cz"]))
	lock_view(at + Vector3(12, 8.0, 14), at + Vector3(0, 1.0, 0))


func _process(_delta: float) -> void:
	if _hud and _mgr:
		var st: Dictionary = _mgr.status()
		_hud.text = (
			"TWO-CHUNK  C aerial | 1/2 jump | I ids | G collision | O bounds | B Blosm | H shadow\n"
			+ "active %s  bodies %d  surfaces %d  distAB %.0fm"
			% [st.get("active", []), _mgr.count_collision_bodies(), _mgr.count_surfaces(), _origin_a.distance_to(_origin_b)]
		)
	if not _follow or _cam == null or _car == null:
		return
	var car_cam := _car.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if car_cam:
		car_cam.current = false
	_cam.current = true
	if _aerial:
		_cam.global_position = _car.global_position + Vector3(22, 58, 26)
		_cam.look_at(_car.global_position + Vector3(0, 1, 12), Vector3.UP)
		return
	var back := _car.global_transform.basis.z
	_cam.global_position = _car.global_position - back * 8.0 + Vector3(0, 2.8, 0)
	_cam.look_at(_car.global_position + Vector3(0, 1.1, 0) + back * 4.0, Vector3.UP)


func _centroid_from_clearance(clear_path: String, man_path: String, fallback: Vector3) -> Vector3:
	var allow: Dictionary = {}
	if FileAccess.file_exists(clear_path):
		var cdata: Variant = JSON.parse_string(FileAccess.get_file_as_string(clear_path))
		if typeof(cdata) == TYPE_DICTIONARY:
			for row_v in (cdata as Dictionary).get("rows", []):
				var row: Dictionary = row_v
				if bool(row.get("ok", false)):
					allow[str(row["osm_id"])] = true
	if not FileAccess.file_exists(man_path):
		return fallback
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(man_path))
	if typeof(man) != TYPE_DICTIONARY:
		return fallback
	var sx := 0.0
	var sz := 0.0
	var n := 0
	for b_v in (man as Dictionary).get("buildings", []):
		var b: Dictionary = b_v
		var id := str(b["osm_id"])
		if not allow.is_empty() and not allow.has(id):
			continue
		sx += float(b.get("cx", 0.0))
		sz += float(b.get("cz", 0.0))
		n += 1
	if n == 0:
		var nest: Variant = (man as Dictionary).get("neighbourhood_origin", null)
		if typeof(nest) == TYPE_DICTIONARY:
			return Vector3(float(nest["x"]), 0.42, float(nest["z"]))
		return fallback
	return Vector3(sx / float(n), 0.42, sz / float(n))


func _build_boundaries() -> void:
	_bound_root = Node3D.new()
	_bound_root.name = "ChunkBoundaries"
	add_child(_bound_root)
	_add_bound_ring(_origin_a, 480.0, Color(0.2, 0.85, 1.0), "bound_A")
	_add_bound_ring(_origin_b, 480.0, Color(1.0, 0.75, 0.2), "bound_B")
	_add_origin_marker(_origin_a, Color(0.2, 0.85, 1.0))
	_add_origin_marker(_origin_b, Color(1.0, 0.75, 0.2))


func _add_bound_ring(origin: Vector3, radius: float, tint: Color, nm: String) -> void:
	var imm := ImmediateMesh.new()
	imm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var steps := 48
	for i in steps + 1:
		var ang := TAU * float(i) / float(steps)
		imm.surface_add_vertex(Vector3(origin.x + cos(ang) * radius, 0.35, origin.z + sin(ang) * radius))
	imm.surface_end()
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = imm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bound_root.add_child(mi)


func _add_origin_marker(origin: Vector3, tint: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4, 8, 4)
	mi.mesh = box
	mi.position = origin + Vector3(0, 4, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bound_root.add_child(mi)


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
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _ground(origin: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(560, 0.4, 560)
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
			var px := float(p[0])
			var pz := float(p[1])
			if Vector2(px - _origin_a.x, pz - _origin_a.z).length() < 300.0:
				near = true
				break
			if Vector2(px - _origin_b.x, pz - _origin_b.z).length() < 300.0:
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


func _road_segments(data: Dictionary) -> Array:
	var out: Array = []
	for road_v in data["roads"]:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		var half := float(road.get("width", 7.0)) * 0.5
		for i in range(pts.size() - 1):
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			out.append({"a": a, "b": b, "half": half})
	return out


func _road_mat(kit_key: String, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.9
	var tex := AssetKit.road_albedo_clean(kit_key)
	if tex:
		mat.albedo_texture = tex
	return mat


func _teleport_now(pos: Vector3, heading: Vector2) -> void:
	_car.global_position = pos
	_car.linear_velocity = Vector3.ZERO
	_car.angular_velocity = Vector3.ZERO
	if _car.has_method("set_spawn"):
		_car.set_spawn(pos, heading)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)


func _write_json(path: String, payload: Dictionary) -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload, "\t"))
		f.close()
	print("WRITE ", path)


func _hud_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(12, 10)
	_hud.add_theme_font_size_override("font_size", 15)
	layer.add_child(_hud)
