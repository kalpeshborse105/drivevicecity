extends RefCounted
## Road-name labels from a verified name string already stored on the way.
## Callers must not pass a highway class or a guessed name.

const SPACING_M := 220.0
const MIN_GAP_M := 46.0


static func add_names(parent: Node3D, roads: Array, max_labels: int = 48) -> int:
	var placed: Array[Vector3] = []
	var count := 0
	for road_v in roads:
		var road: Dictionary = road_v
		var road_name := str(road.get("name", "")).strip_edges()
		var ref_name := str(road.get("ref", "")).strip_edges()
		var text := road_name
		if text.is_empty():
			text = ref_name
		if text.is_empty():
			continue
		var pts: Array = road.get("points", [])
		if pts.size() < 2:
			continue
		var length := _length(pts)
		var steps := maxi(1, int(length / SPACING_M))
		for step in steps:
			var t := (float(step) + 0.5) / float(steps)
			var sample := _sample(pts, t)
			if sample.is_empty():
				continue
			var pos: Vector3 = sample[0]
			var along: Vector3 = sample[1]
			if _too_close(placed, pos):
				continue
			_label(parent, text, pos, along)
			placed.append(pos)
			count += 1
			if count >= max_labels:
				return count
	return count


static func _label(parent: Node3D, text: String, pos: Vector3, along: Vector3) -> void:
	var side := Vector3(-along.z, 0, along.x)
	var label := Label3D.new()
	label.text = text
	label.font_size = 42
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.fixed_size = false
	label.modulate = Color(0.96, 0.94, 0.88, 0.0)
	label.outline_modulate = Color(0.08, 0.08, 0.08, 0.9)
	label.outline_size = 6
	label.position = pos + side * 0.2 + Vector3(0, 2.6, 0)
	label.rotation.y = atan2(along.x, along.z)
	label.set_meta("road_name", text)
	label.set_meta("fade_anchor", pos)
	label.add_to_group("dhule_road_label")
	parent.add_child(label)


static func update_fade(tree: SceneTree, camera_pos: Vector3) -> void:
	for node in tree.get_nodes_in_group("dhule_road_label"):
		var label := node as Label3D
		if label == null or not label.has_meta("fade_anchor"):
			continue
		var anchor: Vector3 = label.get_meta("fade_anchor")
		var dist := camera_pos.distance_to(anchor)
		var alpha := clampf(1.0 - (dist - 18.0) / 70.0, 0.0, 1.0)
		if dist < 8.0:
			alpha = clampf((dist - 3.0) / 5.0, 0.0, 1.0)
		var color := label.modulate
		color.a = alpha
		label.modulate = color
		label.visible = alpha > 0.04


static func _too_close(placed: Array[Vector3], pos: Vector3) -> bool:
	for other in placed:
		if other.distance_to(pos) < MIN_GAP_M:
			return true
	return false


static func _length(pts: Array) -> float:
	var total := 0.0
	for i in pts.size() - 1:
		total += Vector2(float(pts[i + 1][0]) - float(pts[i][0]), float(pts[i + 1][1]) - float(pts[i][1])).length()
	return total


static func _sample(pts: Array, t: float) -> Array:
	var target := _length(pts) * clampf(t, 0.05, 0.95)
	var walked := 0.0
	for i in pts.size() - 1:
		var a := Vector3(float(pts[i][0]), 0.0, float(pts[i][1]))
		var b := Vector3(float(pts[i + 1][0]), 0.0, float(pts[i + 1][1]))
		var span := a.distance_to(b)
		if walked + span >= target and span > 0.2:
			var along := (b - a).normalized()
			return [a.lerp(b, (target - walked) / span), along]
		walked += span
	return []
