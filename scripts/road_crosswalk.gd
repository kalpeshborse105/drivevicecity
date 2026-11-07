extends RefCounted
## Gameplay/environment zebra + stop-line markings at OSM junctions.
## Not verified OSM pedestrian_crossing tags — procedural geometry only.

const RoadJunctions = preload("res://scripts/road_junctions.gd")

const ROAD_CROSSING_GLB := "res://assets/kit/props/road_crossing.glb"
## Pedestrian_crossing.glb is Sketchfab-scale hundreds of metres — do not place raw.


static var placed := 0
static var skipped := 0


static func reset_stats() -> void:
	placed = 0
	skipped = 0


static func in_junction_clear(xz: Vector2, margin: float = 1.25) -> bool:
	## True when a paint sample sits inside a prepared junction pad (+ margin).
	for jv in RoadJunctions.clips:
		var j: Dictionary = jv
		if not bool(j.get("disc", true)):
			continue
		var c: Vector2 = j["c"]
		var r := float(j.get("r", 0.0)) + margin
		if xz.distance_to(c) <= r + float(j.get("arms", []).size()) * 0.15:
			# Prefer arm pull tips for a tighter clip than the disc alone.
			if j.has("arms"):
				var hit := false
				for arm_v in j["arms"]:
					var arm: Dictionary = arm_v
					var tip: Vector2 = arm["p"] + arm["dir"] * float(arm["pull"])
					var half := float(arm["w"]) * 0.55 + margin
					if xz.distance_to(tip) <= half or xz.distance_to(arm["p"]) <= half:
						hit = true
						break
				if hit or xz.distance_to(c) <= r + 0.85:
					return true
			elif xz.distance_to(c) <= r:
				return true
	return false


static func add_crosswalk(
	st: SurfaceTool,
	centre: Vector3,
	across: Vector3,
	along: Vector3,
	road_half_m: float,
	stripe_count: int = 6
) -> void:
	## Rectangular zebra across the carriageway. `across` = road-left unit XZ, `along` = travel unit XZ.
	var half := clampf(road_half_m * 0.92, 1.6, 7.5)
	var stripe_w := 0.48
	var gap := 0.42
	var depth := 0.55
	var lift := Vector3(0, 0.055, 0)
	var a_u := across.normalized()
	var d_u := along.normalized()
	var mid0 := -(float(stripe_count - 1) * 0.5) * (stripe_w + gap)
	for i in stripe_count:
		var mid := centre + d_u * (mid0 + float(i) * (stripe_w + gap)) + lift
		var a := mid - a_u * half - d_u * (stripe_w * 0.5)
		var b := mid + a_u * half - d_u * (stripe_w * 0.5)
		var c := mid + a_u * half + d_u * (stripe_w * 0.5)
		var d := mid - a_u * half + d_u * (stripe_w * 0.5)
		_quad(st, a, b, c, d)
	placed += 1


static func add_stop_line(st: SurfaceTool, tip: Vector3, across: Vector3, along: Vector3, road_half_m: float) -> void:
	var half := clampf(road_half_m * 0.9, 1.4, 7.0)
	var lift := Vector3(0, 0.05, 0)
	var a_u := across.normalized()
	var d_u := along.normalized()
	var mid := tip + lift
	var deep := d_u * 0.32
	var a := mid - a_u * half
	var b := mid + a_u * half
	_quad(st, a, b, b + deep, a + deep)


static func should_mark_arm(arm: Dictionary, arms: Array, highway_hint: String = "") -> bool:
	## Selective: local 3+/4-way arms on non-trunk roads, skip the widest major-only approaches.
	var w := float(arm.get("w", 7.0))
	if w < 4.2 or w > 16.0:
		skipped += 1
		return false
	if highway_hint in ["trunk", "motorway", "trunk_link", "motorway_link"]:
		skipped += 1
		return false
	if arms.size() < 3:
		skipped += 1
		return false
	# Prefer the two narrowest arms so the major through-route stays clearer.
	var widths: Array = []
	for a_v in arms:
		widths.append(float(a_v["w"]))
	widths.sort()
	var cutoff := float(widths[mini(1, widths.size() - 1)])
	if w > cutoff + 0.35 and arms.size() >= 4:
		skipped += 1
		return false
	return true


static func try_place_kit_crossing(parent: Node3D, centre: Vector3, yaw: float, road_width: float) -> bool:
	## Optional kit mesh (road_crossing.glb is ~5×5 m flat). Scaled to road width.
	if parent == null or not ResourceLoader.exists(ROAD_CROSSING_GLB):
		return false
	var packed := load(ROAD_CROSSING_GLB) as PackedScene
	if packed == null:
		return false
	var node := packed.instantiate() as Node3D
	if node == null:
		return false
	var wrap := Node3D.new()
	wrap.name = "kit_road_crossing"
	wrap.add_child(node)
	# Raw mesh spans X 0..5, Z ~0..-5. Centre and flatten.
	var s := clampf(road_width / 5.0, 0.55, 1.35)
	wrap.scale = Vector3(s, 1.0, s)
	wrap.rotation.y = yaw
	wrap.position = centre + Vector3(0, 0.048, 0)
	_disable_shadows(wrap)
	parent.add_child(wrap)
	placed += 1
	return true


static func _disable_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_disable_shadows(c)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(b)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(d)
