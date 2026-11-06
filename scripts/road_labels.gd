extends RefCounted
## Roadside name signs. Text is an OSM name, or a verified ref when the name
## is empty. Signs stand on the ground beside the carriageway. A small pool
## follows the camera, so the first roads in the JSON do not use up the cap.

const SPACING_M := 170.0
const SHOW_M := 78.0
const SEPARATION_M := 34.0
const POOL := 8

static var _parent: Node3D
static var _candidates: Array = []
static var _pool: Array[Node3D] = []
static var _shown: Array[int] = []
static var _wait := 0.0


static func add_names(parent: Node3D, roads: Array, _ignored_cap: int = 8) -> int:
	return bind(parent, roads, [])


static func bind(parent: Node3D, roads: Array, buildings: Array) -> int:
	_parent = parent
	_candidates = []
	_shown = []
	_wait = 0.0
	for road_v in roads:
		var road: Dictionary = road_v
		var text := str(road.get("name", "")).strip_edges()
		if text.is_empty():
			text = str(road.get("ref", "")).strip_edges()
		if text.is_empty():
			continue
		var pts: Array = road.get("points", [])
		if pts.size() < 2:
			continue
		var width := float(road.get("width", 7.0))
		var length := _length(pts)
		var steps := maxi(1, int(length / SPACING_M))
		for step in steps:
			var t := (float(step) + 0.5) / float(steps)
			var sample := _sample(pts, t)
			if sample.is_empty():
				continue
			var centre: Vector3 = sample[0]
			var along: Vector3 = sample[1]
			var side := Vector3(-along.z, 0, along.x)
			if side.length() < 0.5:
				continue
			var offset := side * (width * 0.5 + 2.6)
			var pos := centre + offset
			if _blocked(Vector2(pos.x, pos.z), roads, road, buildings):
				pos = centre - offset
				if _blocked(Vector2(pos.x, pos.z), roads, road, buildings):
					continue
			var inward := centre - pos
			inward.y = 0
			_candidates.append({
				"text": text,
				"pos": Vector3(pos.x, 0.0, pos.z),
				"yaw": atan2(inward.x, inward.z),
			})
	_ensure_pool()
	return _candidates.size()


static func nearest_sign_pose(to: Vector3) -> Dictionary:
	var best := {"pos": Vector3.ZERO, "yaw": 0.0}
	var best_d := 1.0e12
	for cand_v in _candidates:
		var cand: Dictionary = cand_v
		var pos: Vector3 = cand["pos"]
		var dist := pos.distance_to(to)
		if dist < best_d:
			best_d = dist
			best = {"pos": pos, "yaw": float(cand["yaw"])}
	return best


static func update(camera_pos: Vector3, delta: float) -> int:
	_wait -= delta
	if _wait > 0.0:
		return _shown.size()
	_wait = 0.35
	var ranked: Array[Dictionary] = []
	for i in _candidates.size():
		var pos: Vector3 = _candidates[i]["pos"]
		var dist := Vector2(camera_pos.x, camera_pos.z).distance_to(Vector2(pos.x, pos.z))
		if dist > SHOW_M:
			continue
		ranked.append({"i": i, "d": dist})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d"]) < float(b["d"]))
	var pick: Array[int] = []
	for item in ranked:
		var idx := int(item["i"])
		var pos: Vector3 = _candidates[idx]["pos"]
		var close := false
		for other in pick:
			var opos: Vector3 = _candidates[other]["pos"]
			if pos.distance_to(opos) < SEPARATION_M:
				close = true
				break
		if close:
			continue
		pick.append(idx)
		if pick.size() >= POOL:
			break
	_shown = pick
	for slot in _pool.size():
		var sign := _pool[slot]
		if slot >= pick.size():
			sign.visible = false
			continue
		var cand: Dictionary = _candidates[pick[slot]]
		sign.visible = true
		sign.position = cand["pos"]
		sign.rotation = Vector3(0, float(cand["yaw"]), 0)
		var label := sign.get_node("Label") as Label3D
		var board := sign.get_node("Board") as MeshInstance3D
		if label.text != str(cand["text"]):
			label.text = str(cand["text"])
			var board_w := clampf(label.text.length() * 0.095, 1.4, 5.2)
			var box := board.mesh as BoxMesh
			box.size.x = board_w
			label.pixel_size = (board_w * 0.86) / (float(maxi(label.text.length(), 1)) * 18.0)
			label.width = 0.0
	return pick.size()


static func update_fade(_tree: SceneTree, camera_pos: Vector3) -> void:
	update(camera_pos, 0.4)


static func _ensure_pool() -> void:
	while _pool.size() < POOL and _parent != null:
		_pool.append(_make_sign(_parent))


static func _make_sign(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "RoadSign"
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.32, 0.33, 0.35)
	steel.roughness = 0.62
	var post := MeshInstance3D.new()
	post.name = "Post"
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.11, 1.7, 0.11)
	post.mesh = post_mesh
	post.position = Vector3(0, 0.85, 0)
	post.material_override = steel
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(post)
	var board := MeshInstance3D.new()
	board.name = "Board"
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(1.8, 0.42, 0.05)
	board.mesh = board_mesh
	board.position = Vector3(0, 1.62, 0.02)
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.09, 0.24, 0.48)
	blue.roughness = 0.55
	board.material_override = blue
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(board)
	var label := Label3D.new()
	label.name = "Label"
	label.font_size = 32
	label.pixel_size = 0.01
	label.width = 0.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector3(0, 1.62, 0.09)
	label.modulate = Color(0.96, 0.96, 0.94)
	label.outline_size = 6
	label.outline_modulate = Color(0.02, 0.05, 0.1)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	root.add_child(label)
	root.visible = false
	parent.add_child(root)
	return root


static func _blocked(pos: Vector2, roads: Array, own: Dictionary, buildings: Array) -> bool:
	var own_id := str(own.get("id", ""))
	for road_v in roads:
		var road: Dictionary = road_v
		if str(road.get("id", "")) == own_id:
			continue
		var width := float(road.get("width", 7.0))
		var pts: Array = road.get("points", [])
		for i in pts.size() - 1:
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			if _point_segment(pos, a, b) < width * 0.5 + 0.45:
				return true
	for b_v in buildings:
		if typeof(b_v) != TYPE_DICTIONARY:
			continue
		var b: Dictionary = b_v
		var hx := float(b.get("w", 0.0)) * 0.5 + 1.0
		var hz := float(b.get("d", 0.0)) * 0.5 + 1.0
		if hx < 1.0 or hz < 1.0:
			continue
		if absf(pos.x - float(b.get("x", 0.0))) < hx and absf(pos.y - float(b.get("z", 0.0))) < hz:
			return true
	return false


static func _point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var den := ab.length_squared()
	var t := 0.0 if den == 0.0 else clampf((p - a).dot(ab) / den, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _length(pts: Array) -> float:
	var total := 0.0
	for i in pts.size() - 1:
		total += Vector2(float(pts[i + 1][0]) - float(pts[i][0]), float(pts[i + 1][1]) - float(pts[i][1])).length()
	return total


static func _sample(pts: Array, t: float) -> Array:
	var target := _length(pts) * clampf(t, 0.08, 0.92)
	var walked := 0.0
	for i in pts.size() - 1:
		var a := Vector3(float(pts[i][0]), 0.0, float(pts[i][1]))
		var b := Vector3(float(pts[i + 1][0]), 0.0, float(pts[i + 1][1]))
		var span := a.distance_to(b)
		if walked + span >= target and span > 0.2:
			return [a.lerp(b, (target - walked) / span), (b - a).normalized()]
		walked += span
	return []
