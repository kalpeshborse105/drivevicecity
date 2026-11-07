extends RefCounted
## Verified kit asset sizes and placement rules. No universal scale.


const AssetKit = preload("res://scripts/asset_kit.gd")

## category, expected plan/height in metres, scale rule, collision, placement, forward note
const ENTRIES := {
	"res://assets/kit/buildings/indian_house.glb": {
		"category": "house",
		"raw_size": Vector3(5.0, 5.0, 5.16),
		"expected": {"len": 5.0, "height": 5.0},
		"scale_rule": "uniform_fit_polygon",
		"forward": "textured_facade_toward_road_estimate",
		"ground": "mesh_bottom",
		"collision": "box_solid",
		"placement": "osm_footprint_only",
		"blocks_vehicle": true,
	},
	"res://assets/kit/buildings/bhelpuri_shop.glb": {
		"category": "cart",
		"raw_size": Vector3(4.95, 5.70, 3.57),
		"expected": {"len": 2.6, "height": 3.0},
		"scale_rule": "normalize_len",
		"forward": "kit_normalize",
		"ground": "mesh_bottom",
		"collision": "box_solid",
		"placement": "approved_verge_only",
		"blocks_vehicle": true,
	},
	"res://assets/kit/props/barriers.glb": {
		"category": "barrier",
		"expected": {"len": 5.9, "height": 1.1},
		"scale_rule": "normalize_len",
		"forward": "longest_axis_z",
		"ground": "mesh_bottom",
		"collision": "box_solid",
		"placement": "approved_verge_only",
		"blocks_vehicle": true,
	},
	"res://assets/models/props/traffic_barrier_mh.glb": {
		"category": "barrier",
		"expected": {"len": 1.35, "height": 1.0},
		"scale_rule": "normalize_len",
		"forward": "longest_axis_z",
		"ground": "mesh_bottom",
		"collision": "box_solid",
		"placement": "approved_verge_only",
		"blocks_vehicle": true,
	},
	"res://assets/models/props/street_light_mh.glb": {
		"category": "streetlight",
		"expected": {"height": 6.0, "width": 0.35},
		"scale_rule": "normalize_height",
		"forward": "upright",
		"ground": "mesh_bottom",
		"collision": "capsule_pole",
		"placement": "approved_verge_only",
		"blocks_vehicle": true,
	},
	"street_pack:concrete_barrier": {
		"category": "barrier",
		"source": "res://assets/kit/props/street_asset_pack.glb",
		"node": "concrete_barrier",
		"raw_size": Vector3(3.60, 1.06, 1.82),
		"expected": {"len": 3.6, "height": 1.06, "depth": 1.82},
		"scale_rule": "uniform_match_height",
		"forward": "longest_horizontal",
		"ground": "mesh_bottom",
		"collision": "box_solid",
		"placement": "approved_verge_only",
		"blocks_vehicle": true,
	},
	"street_pack:cone": {
		"category": "cone",
		"source": "res://assets/kit/props/street_asset_pack.glb",
		"node": "Cone",
		"raw_size": Vector3(0.88, 0.88, 1.53),
		"expected": {"height": 0.72, "width": 0.4},
		"scale_rule": "uniform_match_height_after_upright",
		"forward": "upright_y",
		"ground": "mesh_bottom",
		"collision": "none_decorative",
		"placement": "approved_verge_only",
		"blocks_vehicle": false,
	},
	"street_pack:give_way": {
		"category": "sign",
		"source": "res://assets/kit/props/street_asset_pack.glb",
		"node": "give_way",
		"raw_size": Vector3(1.49, 0.32, 5.99),
		"expected": {"height": 3.4, "width": 1.0},
		"scale_rule": "uniform_match_longest_then_upright",
		"forward": "sign_face_road",
		"ground": "mesh_bottom",
		"collision": "capsule_pole",
		"placement": "approved_verge_only",
		"blocks_vehicle": true,
		"note": "Raw pole length is on local Z. Height-only scale without uprighting produced giant props.",
	},
}


static func entry(path_or_key: String) -> Dictionary:
	return ENTRIES.get(path_or_key, {})


static func blocks_vehicle(path_or_key: String) -> bool:
	return bool(entry(path_or_key).get("blocks_vehicle", false))


static func add_collision(node: Node3D, path_or_key: String) -> void:
	var spec := entry(path_or_key)
	var kind := str(spec.get("collision", "box_solid"))
	if kind == "none_decorative" or kind == "":
		return
	var aabb := AssetKit.mesh_aabb(node)
	if aabb.size.length() < 0.05:
		return
	_enable_or_clear_imported(node)
	# World-space sibling body — avoids scaled/rotated wrapper skewing the shape.
	var parent := node.get_parent()
	if parent == null:
		return
	var body := StaticBody3D.new()
	body.name = "Solid_%s" % node.name
	body.collision_layer = 1
	body.collision_mask = 1
	var col := CollisionShape3D.new()
	if kind == "capsule_pole":
		var cap := CapsuleShape3D.new()
		cap.radius = clampf(minf(aabb.size.x, aabb.size.z) * 0.35, 0.08, 0.28)
		cap.height = maxf(aabb.size.y - cap.radius * 2.0, 0.4)
		col.shape = cap
	else:
		var box := BoxShape3D.new()
		box.size = Vector3(maxf(aabb.size.x * 0.9, 0.3), maxf(aabb.size.y * 0.92, 0.4), maxf(aabb.size.z * 0.9, 0.3))
		col.shape = box
	var centre := aabb.position + aabb.size * 0.5
	body.position = centre
	body.add_child(col)
	parent.add_child(body)
	node.set_meta("solid_body", body.get_path())


static func _enable_or_clear_imported(n: Node) -> void:
	for c in n.get_children():
		_enable_or_clear_imported(c)
	if n is CollisionShape3D:
		(n as CollisionShape3D).disabled = true
	if n is PhysicsBody3D:
		(n as PhysicsBody3D).collision_layer = 0
		(n as PhysicsBody3D).collision_mask = 0
