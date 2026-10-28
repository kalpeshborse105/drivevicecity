extends RefCounted
## Loads free kit GLB/FBX from res://assets/kit — ground-snapped instances.


const ROADS := {
	## Indian textured road segments (tiled along OSM centerlines).
	"avenue_street": "res://assets/kit/roads/avenue_street.glb",
	"avenue_street_b": "res://assets/kit/roads/avenue_street_b.glb",
	"street_road": "res://assets/kit/roads/street_road.glb",
	# Legacy dioramas — reference only (km-scale); not used for tiling.
	"avenue": "res://assets/kit/roads/avenue.glb",
	"avenue_hq": "res://assets/kit/roads/avenue_hq.glb",
	"india_street": "res://assets/kit/roads/india_street.glb",
}
const SIDEWALKS := {
	"sidewalk_8m": "res://assets/kit/sidewalks/sidewalk_8m.glb",
	"sidewalk_8m_hq": "res://assets/kit/sidewalks/sidewalk_8m_hq.glb",
	# sidewalk_tiles.glb is a 794 m diorama slab — not a prop; alias to the strip.
	"tiles": "res://assets/kit/sidewalks/sidewalk_8m.glb",
}
const BUILDINGS := {
	"bhelpuri": "res://assets/kit/buildings/bhelpuri_shop.glb",
}
const PROPS := {
	"barrier": "res://assets/kit/props/barriers.glb",
	"street_light": "res://assets/kit/props/street_light.fbx",
	"street_light_b": "res://assets/kit/props/street_light_b.fbx",
	# bullock_cart.glb has a ~95 m skinned-bone AABB spike (see tools/probe_kit.gd);
	# disabled until re-exported without armature. Empty path → exists() is false.
	"bullock": "",
}
const VEHICLES := {
	"carnival": "res://assets/kit/vehicles/carnival.glb",
	"safari": "res://assets/kit/vehicles/tata_safari.glb",
	"autorickshaw": "res://assets/kit/vehicles/autorickshaw.glb",
	"bus": "res://assets/kit/vehicles/bus.glb",
	"truck": "res://assets/kit/vehicles/tata_truck.glb",
}
## Terrain3D demo meshes + kit barriers (road_demos edge CSG needs Path3D — use GLB instead).
const SCENERY := {
	"rock_a": "res://demo/assets/models/RockA.glb",
	"rock_b": "res://demo/assets/models/RockB.glb",
	"rock_c": "res://demo/assets/models/RockC.glb",
	"tunnel": "res://demo/assets/models/Tunnel.glb",
	"edge_barrier": "res://assets/kit/props/barriers.glb",
}

## Real-world size + facing normalization (measured via tools/probe_kit.gd).
## len = target longest horizontal extent in metres; yaw = extra Y rotation after
## aligning the longest axis to Z (glTF fronts are usually +Z; Godot forward is -Z).
const NORMALIZE := {
	"res://assets/kit/buildings/bhelpuri_shop.glb": {"len": 2.6, "yaw": 0.0},
	# yaw π → nose toward Godot −Z (away from chase cam at +Z)
	"res://assets/kit/vehicles/carnival.glb": {"len": 5.1, "yaw": PI},
	"res://assets/kit/vehicles/tata_safari.glb": {"len": 4.7, "yaw": PI},
	"res://assets/kit/vehicles/autorickshaw.glb": {"len": 2.9, "yaw": PI},
	"res://assets/kit/vehicles/bus.glb": {"len": 11.0, "yaw": PI},
	"res://assets/kit/vehicles/tata_truck.glb": {"len": 12.0, "yaw": PI},
	# Diorama meshes scaled down to ~12 m tiles for OSM strip overlays.
	"res://assets/kit/roads/avenue_street.glb": {"len": 12.0, "yaw": 0.0},
	"res://assets/kit/roads/avenue_street_b.glb": {"len": 14.0, "yaw": 0.0},
	# 652 m strip — scale by width so lanes match; place only short chops via road builder.
	"res://assets/kit/roads/street_road.glb": {"width": 9.0, "yaw": 0.0},
	"res://assets/kit/roads/india_street.glb": {"len": 8.0, "yaw": 0.0},
	"res://assets/kit/props/bullock_cart.glb": {"len": 4.0, "yaw": 0.0},
	"res://assets/kit/props/barriers.glb": {"len": 5.9, "yaw": 0.0},
	"res://demo/assets/models/RockA.glb": {"len": 4.5, "yaw": 0.0},
	"res://demo/assets/models/RockB.glb": {"len": 3.8, "yaw": 0.0},
	"res://demo/assets/models/RockC.glb": {"len": 5.0, "yaw": 0.0},
}

static var _cache: Dictionary = {}


static func exists(path: String) -> bool:
	return path != "" and ResourceLoader.exists(path)


static func _packed(path: String) -> PackedScene:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if _cache.has(path):
		return _cache[path]
	var ps: PackedScene = load(path)
	_cache[path] = ps
	return ps


static func instance(path: String) -> Node3D:
	var ps := _packed(path)
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	if n:
		ensure_materials(n)
	return n


static var _fallback_mat: StandardMaterial3D


static func ensure_materials(root: Node) -> void:
	## Kit GLB/FBX often ship surfaces with null materials → Godot ERROR spam + flicker.
	if _fallback_mat == null:
		_fallback_mat = StandardMaterial3D.new()
		_fallback_mat.albedo_color = Color(0.55, 0.52, 0.48)
		_fallback_mat.roughness = 0.9
	_ensure_mats_recursive(root)


static func _ensure_mats_recursive(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for si in mi.mesh.get_surface_count():
				if mi.mesh.surface_get_material(si) == null and mi.get_surface_override_material(si) == null:
					mi.set_surface_override_material(si, _fallback_mat)
		if mi.material_override == null and mi.mesh != null and mi.mesh.get_surface_count() == 0:
			mi.material_override = _fallback_mat
	for c in n.get_children():
		_ensure_mats_recursive(c)


static func normalized(path: String) -> Node3D:
	## Wrapper Node3D: longest horizontal axis along Z, scaled to NORMALIZE.len,
	## bottom at y=0, origin at footprint centre. Falls back to raw instance.
	var raw := instance(path)
	if raw == null:
		return null
	ensure_materials(raw)
	var wrap := Node3D.new()
	wrap.name = path.get_file().get_basename()
	wrap.add_child(raw)
	var a := mesh_aabb(raw)
	if a.size.length() < 0.001:
		return wrap
	var spec: Dictionary = NORMALIZE.get(path, {})
	var target_len := float(spec.get("len", 0.0))
	var target_width := float(spec.get("width", 0.0))
	var extra_yaw := float(spec.get("yaw", 0.0))
	# Align longest XZ axis to Z
	if a.size.x > a.size.z * 1.15:
		raw.rotation.y = PI * 0.5
	raw.rotation.y += extra_yaw
	a = mesh_aabb(wrap)
	var longest := maxf(a.size.x, a.size.z)
	var shortest := minf(a.size.x, a.size.z)
	var sc := 1.0
	if target_width > 0.0 and shortest > 0.001:
		sc = target_width / shortest
	elif target_len > 0.0 and longest > 0.001:
		sc = target_len / longest
	raw.scale = Vector3.ONE * sc
	a = mesh_aabb(wrap)
	var centre := a.position + a.size * 0.5
	raw.position -= Vector3(centre.x, a.position.y, centre.z)
	return wrap


static func road_albedo(key: String = "avenue_street") -> Texture2D:
	## Albedo PNG extracted beside the kit road GLB (Indian asphalt look).
	var candidates := {
		"avenue_street": "res://assets/kit/roads/avenue_street_0.png",
		"avenue_street_b": "res://assets/kit/roads/avenue_street_b_0.png",
		"street_road": "res://assets/kit/roads/street_road_0.png",
		"india_street": "res://assets/kit/roads/india_street_0.png",
	}
	var path := str(candidates.get(key, candidates["avenue_street"]))
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static var _clean_road_cache: Dictionary = {}


static func road_albedo_clean(key: String = "street_road") -> Texture2D:
	## Same kit PNGs, but strip the yellow/black hazard gutter that avenue atlases include
	## (triplanar on road boxes was projecting that gutter as giant yellow glitches).
	if _clean_road_cache.has(key):
		return _clean_road_cache[key]
	var src := road_albedo(key)
	if src == null:
		return null
	var img: Image = src.get_image()
	if img == null:
		_clean_road_cache[key] = src
		return src
	if img.is_compressed():
		img.decompress()
	# Normalize every kit road so dashes run along texture U (left→right).
	# street_road is already U-along; avenue_street is V-along → rotate 90° CW.
	if key != "street_road":
		var w := img.get_width()
		var h := img.get_height()
		# Crop asphalt band (skip left yellow curb + right hazard stripes)
		var x0 := int(float(w) * 0.08)
		var keep_w := maxi(int(float(w) * 0.46), 64)
		if x0 + keep_w > w:
			keep_w = w - x0
		img = img.get_region(Rect2i(x0, 0, keep_w, h))
		img.rotate_90(ClockDirection.CLOCKWISE)
		img.adjust_bcs(0.92, 1.0, 0.45)
	var tex := ImageTexture.create_from_image(img)
	_clean_road_cache[key] = tex
	return tex


static func mesh_aabb(root: Node) -> AABB:
	var state := {"have": false, "aabb": AABB()}
	_collect_aabb(root, Transform3D.IDENTITY, state)
	return state["aabb"]


static func _collect_aabb(n: Node, parent_xf: Transform3D, state: Dictionary) -> void:
	var xf := parent_xf
	if n is Node3D:
		xf = parent_xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			var a: AABB = xf * mi.mesh.get_aabb()
			if not state["have"]:
				state["aabb"] = a
				state["have"] = true
			else:
				state["aabb"] = (state["aabb"] as AABB).merge(a)
	for c in n.get_children():
		_collect_aabb(c, xf if n is Node3D else parent_xf, state)


static func place_at(
	parent: Node3D,
	path: String,
	world_pos: Vector3,
	yaw: float = 0.0,
	uniform_scale: float = 1.0
) -> Node3D:
	var n := normalized(path) if NORMALIZE.has(path) else instance(path)
	if n == null:
		return null
	parent.add_child(n)
	n.rotation.y = yaw
	n.position = world_pos
	# Apply uniform scale on the wrapper after yaw so AABB snap stays correct
	if absf(uniform_scale - 1.0) > 0.001:
		n.scale = Vector3.ONE * uniform_scale
	var aabb := mesh_aabb(n)
	if aabb.size.y > 0.01:
		# Sit the mesh bottom exactly on world_pos.y (kills floating props)
		n.position.y = world_pos.y - aabb.position.y
	else:
		n.position.y = world_pos.y
	return n


static func road_path(key: String = "avenue_street") -> String:
	return str(ROADS.get(key, ROADS["avenue_street"]))


static func sidewalk_path(key: String = "sidewalk_8m") -> String:
	return str(SIDEWALKS.get(key, SIDEWALKS["sidewalk_8m"]))


static func building_path(key: String = "bhelpuri") -> String:
	return str(BUILDINGS.get(key, BUILDINGS["bhelpuri"]))


static func prop_path(key: String) -> String:
	return str(PROPS.get(key, ""))


static func vehicle_path(key: String) -> String:
	return str(VEHICLES.get(key, ""))


static func scenery_path(key: String) -> String:
	return str(SCENERY.get(key, ""))
