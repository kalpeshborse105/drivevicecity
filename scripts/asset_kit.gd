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
	## Street-food cart (small) — sidewalk prop, not a full footprint.
	"bhelpuri": "res://assets/kit/buildings/bhelpuri_shop.glb",
	"indian_house": "res://assets/kit/buildings/indian_house.glb",
	## Optional OSM commercial shopfront (same mesh, footprint-scaled). Prefer models/ path.
	"shop": "res://assets/models/buildings/shops/bhelpuri_shop.glb",
	"shop_kit": "res://assets/kit/buildings/bhelpuri_shop.glb",
}
const PROPS := {
	## Original modular MH props (preferred) + kit fallbacks
	"barrier": "res://assets/models/props/traffic_barrier_mh.glb",
	"barrier_kit": "res://assets/kit/props/barriers.glb",
	"street_light": "res://assets/models/props/street_light_mh.glb",
	"street_light_kit": "res://assets/kit/props/street_light.fbx",
	"street_light_b": "res://assets/kit/props/street_light_b.fbx",
	"bus_stop": "res://assets/models/props/bus_stop_shelter_mh.glb",
	"planter": "res://assets/models/props/concrete_planter_mh.glb",
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
	"camry": "res://assets/kit/vehicles/camry.glb",
	## Original MH premium sedan (hero car)
	"premium_sedan": "res://assets/models/vehicles/premium_sedan_mh.glb",
}
const ENVIRONMENTS := {
	"dhule_junction": "res://assets/models/environments/dhule_junction_streetscape.glb",
	"dhule_blosm_city": "res://assets/models/environments/dhule_blosm_city.glb",
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
	# Cart prop (~2.6 m). Full shop footprints use place_shop_footprint() instead.
	"res://assets/kit/buildings/bhelpuri_shop.glb": {"len": 2.6, "yaw": 0.0},
	"res://assets/kit/buildings/indian_house.glb": {"len": 8.0, "yaw": 0.0},
	"res://assets/models/buildings/shops/bhelpuri_shop.glb": {"len": 10.0, "yaw": 0.0},
	# VehicleBody3D / glTF front = MODEL_FRONT (+Z). Longest axis → Z, then yaw PI
	# turns kit noses to +Z so the chase camera sees the rear, matching travel.
	# Chase cam sits on −Z so you see the rear (truck_town / GTA-style).
	"res://assets/kit/vehicles/carnival.glb": {"len": 5.1, "yaw": 3.14159265},
	"res://assets/kit/vehicles/tata_safari.glb": {"len": 4.7, "yaw": 3.14159265},
	"res://assets/kit/vehicles/autorickshaw.glb": {"len": 2.9, "yaw": 3.14159265},
	"res://assets/kit/vehicles/bus.glb": {"len": 11.0, "yaw": 3.14159265},
	"res://assets/kit/vehicles/tata_truck.glb": {"len": 12.0, "yaw": 3.14159265},
	"res://assets/kit/vehicles/camry.glb": {"len": 4.9, "yaw": 3.14159265},
	"res://assets/models/vehicles/premium_sedan_mh.glb": {"len": 4.65, "yaw": 3.14159265},
	"res://assets/models/environments/dhule_junction_streetscape.glb": {"len": 48.0, "yaw": 0.0},
	# Diorama meshes scaled down to ~12 m tiles for OSM strip overlays.
	"res://assets/kit/roads/avenue_street.glb": {"len": 12.0, "yaw": 0.0},
	"res://assets/kit/roads/avenue_street_b.glb": {"len": 14.0, "yaw": 0.0},
	# 652 m strip — scale by width so lanes match; place only short chops via road builder.
	"res://assets/kit/roads/street_road.glb": {"width": 9.0, "yaw": 0.0},
	"res://assets/kit/roads/india_street.glb": {"len": 8.0, "yaw": 0.0},
	"res://assets/kit/props/bullock_cart.glb": {"len": 4.0, "yaw": 0.0},
	"res://assets/kit/props/barriers.glb": {"len": 5.9, "yaw": 0.0},
	"res://assets/models/props/traffic_barrier_mh.glb": {"len": 1.35, "yaw": 0.0},
	# Poles: scale by HEIGHT (not XZ len — that blew poles to rooftop scale).
	"res://assets/models/props/street_light_mh.glb": {"height": 6.0, "yaw": 0.0},
	"res://assets/kit/props/street_light.fbx": {"height": 6.0, "yaw": 0.0},
	"res://assets/kit/props/street_light_b.fbx": {"height": 6.0, "yaw": 0.0},
	# Sidewalk strips: fixed length/width so raw diorama scale never spans the lane.
	"res://assets/kit/sidewalks/sidewalk_8m.glb": {"len": 8.0, "width": 2.2, "yaw": 0.0},
	"res://assets/kit/sidewalks/sidewalk_8m_hq.glb": {"len": 8.0, "width": 2.2, "yaw": 0.0},
	"res://assets/models/props/bus_stop_shelter_mh.glb": {"len": 3.4, "yaw": 0.0},
	"res://assets/models/props/concrete_planter_mh.glb": {"len": 1.1, "yaw": 0.0},
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
	## Wrapper Node3D: longest horizontal axis along Z, scaled to NORMALIZE.len /
	## width / height, bottom at y=0, origin at footprint centre.
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
	var target_height := float(spec.get("height", 0.0))
	var extra_yaw := float(spec.get("yaw", 0.0))
	# Align longest XZ axis to Z (skip for height-driven poles — keep upright).
	if target_height <= 0.0 and a.size.x > a.size.z * 1.15:
		raw.rotation.y = PI * 0.5
	raw.rotation.y += extra_yaw
	a = mesh_aabb(wrap)
	var longest := maxf(a.size.x, a.size.z)
	var shortest := minf(a.size.x, a.size.z)
	var sc := 1.0
	if target_height > 0.0 and a.size.y > 0.001:
		# Street lights / poles: uniform scale from vertical extent only.
		sc = target_height / a.size.y
	elif target_width > 0.0 and target_len > 0.0 and longest > 0.001 and shortest > 0.001:
		# Sidewalk strips: fit both axes (pick the tighter scale so neither overflows).
		sc = minf(target_len / longest, target_width / shortest)
	elif target_width > 0.0 and shortest > 0.001:
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
	var p := str(BUILDINGS.get(key, BUILDINGS["bhelpuri"]))
	# Fall back to kit if models/shops copy is not imported yet
	if key == "shop" and not exists(p):
		return str(BUILDINGS["shop_kit"])
	return p


static func place_shop_footprint(
	parent: Node3D,
	world_pos: Vector3,
	size_xz: Vector2,
	yaw: float,
	with_collision: bool = false
) -> Node3D:
	## Scale the shop GLB to an OSM footprint (front faces +yaw / toward road). Sparse use only.
	var path := building_path("shop")
	if not exists(path):
		return null
	var n := instance(path)
	if n == null:
		return null
	var wrap := Node3D.new()
	wrap.name = "ShopFootprint"
	wrap.add_child(n)
	var a := mesh_aabb(n)
	if a.size.length() < 0.01:
		wrap.queue_free()
		return null
	# Align longest plan axis to local Z (road-facing depth after yaw)
	if a.size.x > a.size.z * 1.15:
		n.rotation.y = PI * 0.5
		a = mesh_aabb(wrap)
	var target_w := clampf(size_xz.x, 5.5, 14.0)
	var target_d := clampf(size_xz.y, 5.0, 12.0)
	var sx := target_w / maxf(a.size.x, 0.01)
	var sz := target_d / maxf(a.size.z, 0.01)
	var sy := clampf((sx + sz) * 0.5, 0.45, 2.2)
	n.scale = Vector3(sx, sy, sz)
	a = mesh_aabb(wrap)
	var centre := a.position + a.size * 0.5
	n.position -= Vector3(centre.x, a.position.y, centre.z)
	parent.add_child(wrap)
	wrap.rotation.y = yaw
	wrap.position = world_pos
	a = mesh_aabb(wrap)
	wrap.position.y = world_pos.y - a.position.y
	if with_collision:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(a.size.x * 0.92, a.size.y * 0.9, a.size.z * 0.92)
		col.shape = shape
		col.position = Vector3(0, a.size.y * 0.45, 0)
		body.add_child(col)
		wrap.add_child(body)
	else:
		# Visual-only — strip any imported static bodies from the GLB
		_strip_physics_recursive(wrap)
	return wrap


static func _strip_physics_recursive(n: Node) -> void:
	for c in n.get_children():
		_strip_physics_recursive(c)
	if n is StaticBody3D or n is RigidBody3D or n is CollisionShape3D:
		n.queue_free()


static func prop_path(key: String) -> String:
	var p := str(PROPS.get(key, ""))
	if p != "" and exists(p):
		return p
	# Fallbacks when modular GLBs not imported yet
	if key == "barrier":
		return str(PROPS.get("barrier_kit", ""))
	if key == "street_light":
		return str(PROPS.get("street_light_kit", ""))
	return p


static func vehicle_path(key: String) -> String:
	return str(VEHICLES.get(key, ""))


static func scenery_path(key: String) -> String:
	return str(SCENERY.get(key, ""))
