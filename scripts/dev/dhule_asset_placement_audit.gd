extends Node3D
## Isolated audit: raw vs normalized shelf, approved solids, clearance debug, collision drive.


const MAP := "res://assets/maps/dhule_roads_game.json"
const HOUSE := "res://assets/kit/buildings/indian_house.glb"
const CART := "res://assets/kit/buildings/bhelpuri_shop.glb"
const BARRIER := "res://assets/kit/props/barriers.glb"
const STREET_PACK := "res://assets/kit/props/street_asset_pack.glb"

const AssetKit = preload("res://scripts/asset_kit.gd")
const DhuleAssetCatalog = preload("res://scripts/dhule_asset_catalog.gd")
const AssetPlacementValidator = preload("res://scripts/asset_placement_validator.gd")
const RoadSurface = preload("res://scripts/road_surface.gd")

var _car: VehicleBody3D
var _cam: Camera3D
var _follow := true
var _origin := Vector3(-636.54, 0.42, 881.83)
var _segments: Array = []
var _targets: Array = []
var _rejected := 0
var _approved := 0


func _ready() -> void:
	_car = $PlayerCar
	_cam = $ChaseCam
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	var spawn: Dictionary = data["spawn"]
	_origin = Vector3(float(spawn["x"]), 0.42, float(spawn["z"]))
	_ground()
	_roads(data)
	_segments = AssetPlacementValidator.segments_from_roads(data["roads"], Vector2(_origin.x, _origin.z), 220.0)
	_shelf()
	_approved_course()
	_car.set_spawn(_origin + Vector3(0, 0, -6), Vector2(float(spawn["hx"]), float(spawn["hz"])))
	print("AUDIT_PLACEMENT approved ", _approved, " rejected ", _rejected)


func lock_view(pos: Vector3, at: Vector3) -> void:
	_follow = false
	var car_cam := _car.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if car_cam:
		car_cam.current = false
	_cam.current = true
	_cam.global_position = pos
	if pos.distance_to(at) > 0.4:
		_cam.look_at(at, Vector3.UP)


func run_capture() -> void:
	_car.visible = false
	lock_view(_origin + Vector3(18, 3.2, -22), _origin + Vector3(18, 1.2, -8))
	await _frames(8)
	await _shot("res://docs/qa/51-shelf.png")
	lock_view(_origin + Vector3(-4, 2.6, 8), _origin + Vector3(6, 1.0, 14))
	await _frames(6)
	await _shot("res://docs/qa/51-approved.png")
	lock_view(_origin + Vector3(10, 28, 10), _origin + Vector3(6, 0, 14))
	await _frames(6)
	await _shot("res://docs/qa/51-clearance.png")
	_car.visible = true
	await _drive_hits()
	await _sample("audit_street")


func _process(_delta: float) -> void:
	if not _follow or _cam == null or _car == null:
		return
	var car_cam := _car.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if car_cam:
		car_cam.current = false
	_cam.current = true
	var back := _car.global_transform.basis.z
	_cam.global_position = _car.global_position - back * 8.0 + Vector3(0, 2.8, 0)
	_cam.look_at(_car.global_position + Vector3(0, 1.1, 0) + back * 4.0, Vector3.UP)


func _shelf() -> void:
	var shelf := Node3D.new()
	shelf.name = "RawNormalizedShelf"
	add_child(shelf)
	var base := _origin + Vector3(18, 0, -10)
	_label(shelf, base + Vector3(0, 4.2, 0), "raw vs normalized")
	_place_raw(shelf, HOUSE, base + Vector3(-8, 0, 0), "house raw")
	_place_norm(shelf, HOUSE, base + Vector3(-2, 0, 0), "house kit 8m")
	_place_norm(shelf, CART, base + Vector3(4, 0, 0), "cart 2.6m")
	if AssetKit.exists(BARRIER):
		_place_norm(shelf, BARRIER, base + Vector3(10, 0, 0), "barrier")
	_place_street_sample(shelf, "give_way", base + Vector3(16, 0, 0), 3.4, "sign upright")
	_place_street_sample(shelf, "concrete_barrier", base + Vector3(22, 0, 0), 1.06, "concrete 1.06m")
	# Rejected example: height-only scale WITHOUT upright (the production bug).
	_place_street_bad_example(shelf, "give_way", base + Vector3(30, 0, 0), 3.4)


func _approved_course() -> void:
	var course := Node3D.new()
	course.name = "ApprovedCourse"
	add_child(course)
	# Keep the course on the grass north of spawn, clear of asphalt.
	var wall_pos := _origin + Vector3(-18, 0, 28)
	_solid_wall(course, wall_pos, Vector3(4.0, 2.2, 0.5), "test_wall")
	_try_place_approved(course, BARRIER, _origin + Vector3(-22, 0, 28), 0.0, "barrier")
	_try_place_street(course, "concrete_barrier", _origin + Vector3(-14, 0, 28), 0.0, 1.06)
	_try_place_street(course, "give_way", _origin + Vector3(-10, 0, 30), PI, 3.4)
	# Deliberate reject: put a barrier on the road centre and mark it.
	_reject_on_road(course)


func _reject_on_road(parent: Node3D) -> void:
	if not AssetKit.exists(BARRIER):
		return
	var n := AssetKit.normalized(BARRIER)
	if n == null:
		return
	n.position = _origin
	parent.add_child(n)
	var report := AssetPlacementValidator.validate_node(n, _segments, {"ground_y": 0.0, "max_plan_m": 8.0})
	if not bool(report["ok"]):
		_rejected += 1
		_mark_reject(parent, n.global_position, str(report["reason"]))
		print("REJECT_DEMO ", report["reason"], " clear ", report["clearance"])
		n.queue_free()
	else:
		n.queue_free()


func _try_place_approved(parent: Node3D, path: String, pos: Vector3, yaw: float, key: String) -> void:
	if not AssetKit.exists(path):
		return
	var n := AssetKit.place_at(parent, path, pos, yaw, 1.0)
	if n == null:
		return
	var report := AssetPlacementValidator.validate_node(n, _segments, {"ground_y": 0.0, "max_plan_m": 8.0})
	_draw_box(parent, report["aabb"], Color(0.2, 0.6, 1.0) if bool(report["ok"]) else Color(1, 0.2, 0.2))
	if not bool(report["ok"]):
		_rejected += 1
		_mark_reject(parent, pos, str(report["reason"]))
		n.queue_free()
		print("REJECT ", key, " ", report["reason"])
		return
	DhuleAssetCatalog.add_collision(n, path)
	_approved += 1
	_targets.append({"pos": pos, "dir": Vector3(0, 0, 1), "name": key})
	print("APPROVED ", key, " clear ", report["clearance"])


func _try_place_street(parent: Node3D, prefix: String, pos: Vector3, yaw: float, target_h: float) -> void:
	var wrap := _make_street_piece(prefix, target_h)
	if wrap == null:
		return
	parent.add_child(wrap)
	wrap.rotation.y = yaw
	wrap.position = pos
	var aabb := AssetKit.mesh_aabb(wrap)
	wrap.position.y = pos.y - aabb.position.y
	aabb = AssetKit.mesh_aabb(wrap)
	var report := AssetPlacementValidator.validate_node(wrap, _segments, {"ground_y": 0.0, "max_height_m": 6.0, "max_plan_m": 8.0})
	print("STREET_CANDIDATE ", prefix, " size ", aabb.size, " clear ", report.get("clearance", 0), " ", report.get("reason", ""))
	_draw_box(parent, aabb, Color(0.2, 0.85, 0.4) if bool(report["ok"]) else Color(1, 0.25, 0.15))
	if not bool(report["ok"]):
		_rejected += 1
		_mark_reject(parent, pos, str(report["reason"]))
		wrap.queue_free()
		print("REJECT street_", prefix, " ", report["reason"])
		return
	var catalog_key := "street_pack:%s" % prefix
	if DhuleAssetCatalog.blocks_vehicle(catalog_key):
		DhuleAssetCatalog.add_collision(wrap, catalog_key)
	_approved += 1
	_targets.append({"pos": pos, "dir": Vector3(0, 0, 1), "name": prefix})
	print("APPROVED street_", prefix, " clear ", report["clearance"], " size ", snapped(aabb.size.x, 0.01), "x", snapped(aabb.size.y, 0.01), "x", snapped(aabb.size.z, 0.01))


func _make_street_piece(prefix: String, target_h: float) -> Node3D:
	## Rebuild from mesh resources only — Sketchfab parent scales made 50 m+ props.
	if not ResourceLoader.exists(STREET_PACK):
		return null
	var packed := load(STREET_PACK) as PackedScene
	var lib := packed.instantiate()
	var src := _find_named(lib, prefix)
	if src == null:
		lib.queue_free()
		return null
	var wrap := Node3D.new()
	wrap.name = "street_" + prefix
	var meshes: Array = []
	_collect_meshes(src, meshes)
	if meshes.is_empty():
		lib.queue_free()
		return null
	for mi_v in meshes:
		var src_mi := mi_v as MeshInstance3D
		var inst := MeshInstance3D.new()
		inst.mesh = src_mi.mesh
		inst.name = src_mi.name
		wrap.add_child(inst)
	var box := AssetKit.mesh_aabb(wrap)
	if box.size.z > box.size.y * 1.4 and box.size.z > box.size.x * 1.4:
		for c in wrap.get_children():
			if c is Node3D:
				(c as Node3D).rotation.x = -PI * 0.5
		box = AssetKit.mesh_aabb(wrap)
	var catalog := DhuleAssetCatalog.entry("street_pack:%s" % prefix)
	var want_h := target_h
	if not catalog.is_empty():
		var exp: Dictionary = catalog.get("expected", {})
		want_h = float(exp.get("height", target_h))
	if box.size.y > 0.05 and want_h > 0.05:
		var plan := maxf(box.size.x, box.size.z)
		var s := want_h / box.size.y
		# Reject extreme aspect blow-ups — never stretch a 0.3 m Y into a 3 m giant width.
		if plan * s > 8.0:
			s = 8.0 / maxf(plan, 0.01)
		wrap.scale = Vector3.ONE * clampf(s, 0.15, 1.25)
	lib.queue_free()
	return wrap


func _collect_meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)


func _place_street_sample(parent: Node3D, prefix: String, at: Vector3, target_h: float, title: String) -> void:
	var wrap := _make_street_piece(prefix, target_h)
	if wrap == null:
		return
	wrap.position = at
	var aabb := AssetKit.mesh_aabb(wrap)
	wrap.position.y = at.y - aabb.position.y
	parent.add_child(wrap)
	_label(parent, at + Vector3(0, AssetKit.mesh_aabb(wrap).size.y + 0.5, 0), title)


func _place_street_bad_example(parent: Node3D, prefix: String, at: Vector3, target_h: float) -> void:
	## Shows the old height-only bug for documentation — not used in the drive course.
	if not ResourceLoader.exists(STREET_PACK):
		return
	var packed := load(STREET_PACK) as PackedScene
	var lib := packed.instantiate()
	var src := _find_named(lib, prefix)
	if src == null:
		lib.queue_free()
		return
	var wrap := Node3D.new()
	wrap.name = "BAD_height_only_" + prefix
	var copy := src.duplicate()
	wrap.add_child(copy)
	if copy is Node3D:
		(copy as Node3D).position = Vector3.ZERO
		(copy as Node3D).rotation = Vector3.ZERO
	var box := AssetKit.mesh_aabb(wrap)
	# Intentionally wrong: scale by Y while the pole is on Z.
	if box.size.y > 0.01:
		wrap.scale = Vector3.ONE * clampf(target_h / box.size.y, 0.2, 40.0)
	wrap.position = at
	var box2 := AssetKit.mesh_aabb(wrap)
	wrap.position.y = at.y - box2.position.y
	parent.add_child(wrap)
	_label(parent, at + Vector3(0, minf(box2.size.y, 8.0) + 0.5, 0), "BAD height-only")
	_draw_box(parent, AssetKit.mesh_aabb(wrap), Color(1.0, 0.15, 0.1))
	lib.queue_free()
	print("BAD_EXAMPLE size ", AssetKit.mesh_aabb(wrap).size)


func _solid_wall(parent: Node3D, pos: Vector3, size: Vector3, id: String) -> void:
	var body := StaticBody3D.new()
	body.name = "hit_" + id
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.7, 0.66)
	mi.material_override = mat
	body.add_child(mi)
	parent.add_child(body)
	_approved += 1
	_targets.append({"pos": pos, "dir": Vector3(0, 0, 1), "name": id})
	_draw_box(parent, AssetKit.mesh_aabb(body), Color(0.9, 0.8, 0.2))


func _drive_hits() -> void:
	## PlayerCar._physics_process forces freeze=false; teleport via PhysicsServer + pause script.
	for t_v in _targets:
		var t: Dictionary = t_v
		var pos: Vector3 = t["pos"]
		var dir: Vector3 = t["dir"]
		var start := pos + Vector3(0, 0.42, -8.0)
		var heading := Vector2(0, 1)
		await _teleport_car(start, heading)
		print("DRIVE_START target=", t["name"], " car=", _car.global_position, " goal=", pos)
		Input.action_press("accelerate")
		var peak := 0.0
		var min_dist := 1.0e9
		var elapsed := 0.0
		while elapsed < 4.0:
			await get_tree().physics_frame
			elapsed += get_physics_process_delta_time()
			peak = maxf(peak, _car.linear_velocity.length() * 3.6)
			min_dist = minf(min_dist, Vector2(_car.global_position.x, _car.global_position.z).distance_to(Vector2(pos.x, pos.z)))
		Input.action_release("accelerate")
		var speed := _car.linear_velocity.length() * 3.6
		var at := _car.global_position
		var hit_name := ""
		var query := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.0, 0), at + Vector3(0, 1.0, 0) + _car.global_transform.basis.z * 4.0)
		query.exclude = [_car.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			hit_name = str(hit["collider"].name)
		var dist := Vector2(at.x, at.z).distance_to(Vector2(pos.x, pos.z))
		var stopped := speed < 2.0 and peak > 5.0 and min_dist < 6.0
		print(
			"DRIVE_HIT target=", t["name"],
			" speed=", snapped(speed, 0.1),
			" peak=", snapped(peak, 0.1),
			" dist=", snapped(dist, 0.1),
			" min_dist=", snapped(min_dist, 0.1),
			" stopped=", stopped,
			" hit=", hit_name,
			" at=", at
		)
		lock_view(at - dir * 6.0 + Vector3(0, 2.4, 0), at + Vector3(0, 1.0, 0))
		await _frames(3)
		await _shot("res://docs/qa/52-hit-%s.png" % str(t["name"]))


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
	_label(parent, at + Vector3(0, a.size.y + 0.5, 0), title)


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
	_label(parent, at + Vector3(0, a.size.y + 0.5, 0), title)


func _find_named(n: Node, want: String) -> Node:
	var w := want.to_lower()
	if str(n.name).to_lower().begins_with(w):
		return n
	for c in n.get_children():
		var hit := _find_named(c, want)
		if hit:
			return hit
	return null


func _label(parent: Node3D, at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 36
	label.pixel_size = 0.02
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)


func _mark_reject(parent: Node3D, at: Vector3, reason: String) -> void:
	_label(parent, at + Vector3(0, 2.5, 0), "REJECT " + reason)
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	mi.mesh = sphere
	mi.position = at + Vector3(0, 0.4, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.15, 0.1)
	mi.material_override = mat
	parent.add_child(mi)


func _draw_box(parent: Node3D, aabb: AABB, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var p := [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0, 0),
		aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
		aabb.position + Vector3(0, 0, aabb.size.z),
	]
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 5:
		var q: Vector3 = p[i % 4] + Vector3(0, 0.12, 0)
		im.surface_set_color(color)
		im.surface_add_vertex(q)
	im.surface_end()
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat
	parent.add_child(mi)
	# Asphalt edge sample near this asset for the clearance view.
	_draw_road_edges(parent)


func _draw_road_edges(parent: Node3D) -> void:
	if parent.has_meta("roads_drawn"):
		return
	parent.set_meta("roads_drawn", true)
	for seg_v in _segments:
		var seg: Dictionary = seg_v
		var a: Vector2 = seg["a"]
		var b: Vector2 = seg["b"]
		var half := float(seg["half"])
		var ab := b - a
		if ab.length() < 0.5:
			continue
		var nrm := Vector2(-ab.y, ab.x).normalized() * half
		var poly := [a + nrm, b + nrm, b - nrm, a - nrm]
		var mi := MeshInstance3D.new()
		var im := ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in 5:
			var p: Vector2 = poly[i % 4]
			im.surface_set_color(Color(1.0, 0.35, 0.1))
			im.surface_add_vertex(Vector3(p.x, 0.06, p.y))
		im.surface_end()
		mi.mesh = im
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mi.material_override = mat
		parent.add_child(mi)


func _sample(tag: String) -> void:
	var fps: Array[float] = []
	var draws: Array[float] = []
	for i in 20:
		await get_tree().process_frame
		if i < 6:
			continue
		fps.append(Performance.get_monitor(Performance.TIME_FPS))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	fps.sort()
	draws.sort()
	print("PERF ", tag, " fps_med ", snapped(fps[fps.size() / 2], 0.1), " draws_med ", snapped(draws[draws.size() / 2], 1.0))


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


func _roads(data: Dictionary) -> void:
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.78, 0.78, 0.8)
	var major := StandardMaterial3D.new()
	major.albedo_color = Color(0.74, 0.74, 0.77)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.93, 0.93, 0.9)
	var shown: Array = []
	for road_v in data["roads"]:
		var road: Dictionary = road_v
		for p in road.get("points", []):
			if Vector2(float(p[0]) - _origin.x, float(p[1]) - _origin.z).length() < 180.0:
				shown.append(road)
				break
	RoadSurface.prepare_junctions(shown)
	RoadSurface.begin_batch(self)
	for road_v in shown:
		var road: Dictionary = road_v
		RoadSurface.add_way(self, road.get("points", []), float(road.get("width", 7.0)), 0.04, asphalt, paint, str(road.get("highway", "residential")))
	RoadSurface.draw_prepared_junctions(self, 0.04, asphalt, major)
	RoadSurface.flush_batch()


func _ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, 0.4, 200)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(_origin.x, -0.2, _origin.z)
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
