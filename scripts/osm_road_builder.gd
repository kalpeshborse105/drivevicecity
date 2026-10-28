extends Node3D
## OSM Dhule roads + S2 dense Indian street kits (own art).

signal map_ready(spawn_position: Vector3, spawn_heading: Vector2, anchors: Array)

const StreetKit = preload("res://scripts/street_kit.gd")
const AssetKit = preload("res://scripts/asset_kit.gd")
const BuildingKit = preload("res://scripts/building_kit.gd")

const GROUND_ALBEDO := "res://demo/assets/textures/ground037_alb_ht.png"
const GROUND_NORMAL := "res://demo/assets/textures/ground037_nrm_rgh.png"
const PARKED_HEAVY_MAX := 14

@export_file("*.json") var map_json_path: String = "res://assets/maps/dhule_roads_game.json"
@export var road_y: float = 0.04
@export var dense_radius: float = 320.0
@export var medium_radius: float = 520.0

var delivery_anchors: Array = []
var spawn_position: Vector3 = Vector3(0, 0.55, 0)
var spawn_heading: Vector2 = Vector2(0, -1)

var _asphalt: StandardMaterial3D
var _major: StandardMaterial3D
var _paint: StandardMaterial3D
var _edge: StandardMaterial3D
var _curb: StandardMaterial3D
var _sidewalk: StandardMaterial3D
var _palette: Array = []
var _road_samples: Array[Vector3] = []
var _parked_heavy := 0


func _ready() -> void:
	if not FileAccess.file_exists(map_json_path):
		push_error("OSM map JSON missing: %s" % map_json_path)
		return
	var file := FileAccess.open(map_json_path, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid OSM game JSON")
		return
	_build(data as Dictionary)
	call_deferred("_emit_map_ready")


func _emit_map_ready() -> void:
	map_ready.emit(spawn_position, spawn_heading, delivery_anchors)


func _mat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	return StreetKit.mat(color, rough)


func _road_mat(color: Color, rough: float, noise_seed: int) -> StandardMaterial3D:
	## Fallback procedural grain when kit textures are missing.
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.0
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.085
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.as_normal_map = false
	m.albedo_texture = tex
	m.uv1_scale = Vector3(4.5, 4.5, 4.5)
	return m


func _kit_road_mat(kit_key: String, tint: Color, rough: float) -> StandardMaterial3D:
	## Indian asphalt from kit PNGs. UVs come from add_road_deck (along-road), not triplanar.
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = 0.0
	var tex := AssetKit.road_albedo_clean(kit_key)
	if tex:
		m.albedo_texture = tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.uv1_triplanar = false
		m.uv1_scale = Vector3(1, 1, 1)
	else:
		return _road_mat(Color(0.18, 0.17, 0.16), rough, hash(kit_key) % 1000)
	return m


func _anchor_from_dict(a: Dictionary) -> Dictionary:
	return {
		"pos": Vector3(float(a.get("x", 0)), 0.12, float(a.get("z", 0))),
		"heading": Vector2(float(a.get("hx", 0)), float(a.get("hz", -1))),
		"road": str(a.get("road", "")),
		"highway": str(a.get("highway", "")),
	}


func _build(data: Dictionary) -> void:
	var clip: float = float(data.get("clip_radius_m", 900.0))
	# Strict 2 kit sources: street_road = sub, avenue_street = main (asphalt crop, no yellow gutter)
	_asphalt = _kit_road_mat("street_road", Color(0.95, 0.95, 0.95), 0.92)
	_major = _kit_road_mat("avenue_street", Color(0.9, 0.9, 0.92), 0.86)
	_paint = _mat(Color(0.92, 0.86, 0.35), 0.65)
	_edge = _mat(Color(0.9, 0.9, 0.88), 0.72)
	_curb = _mat(Color(0.48, 0.46, 0.42), 0.95)
	_sidewalk = _road_mat(Color(0.62, 0.58, 0.5), 0.92, 33)
	_palette = [
		_mat(Color(0.82, 0.7, 0.5)),   # cream / ochre house
		_mat(Color(0.74, 0.74, 0.7)),   # light grey plaster
		_mat(Color(0.58, 0.48, 0.4)),   # brown brick-ish
		_mat(Color(0.68, 0.42, 0.32)),  # terracotta wash
		_mat(Color(0.48, 0.58, 0.5)),   # faded green
		_mat(Color(0.88, 0.82, 0.68)),  # pale yellow
		_mat(Color(0.72, 0.58, 0.58)),  # dusty pink
		_mat(Color(0.5, 0.55, 0.62)),   # blue-grey commercial
	]
	_road_samples.clear()
	_parked_heavy = 0

	_add_ground(clip)

	var roads: Array = data.get("roads", [])
	# Resolve spawn early so density uses it
	_resolve_spawn(data, roads)

	var rng := RandomNumberGenerator.new()
	rng.seed = 742021
	var shops := 0
	var props := 0

	for road_v in roads:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		if pts.size() < 2:
			continue
		var width: float = float(road.get("width", 7.0))
		var hw: String = str(road.get("highway", "residential"))
		var is_major := hw in ["primary", "secondary", "trunk", "motorway", "tertiary"]
		# Strict 2 kit looks only: avenue_street (main) / street_road (sub). No zebra/wear/mesh stack.
		var mat := _major if is_major else _asphalt
		_build_road_strip(pts, width, mat, hw)
		if is_major:
			_build_curbs(pts, width)
		_sample_road(pts, width)

		var dens := _density_for_polyline(pts)
		if dens <= 0.0:
			continue
		shops += _dress_road_sides(pts, width, dens, hw, rng)
		props += _dress_road_props(pts, width, dens, hw, rng)

	delivery_anchors.clear()
	for a_v in data.get("delivery_anchors", []):
		delivery_anchors.append(_anchor_from_dict(a_v))

	var flyovers := _add_flyovers(data)
	var footprints := _add_osm_context(data, rng)
	var lots := _fill_empty_lots(clip, rng)
	var landmarks := _add_landmarks(rng)
	var spawn_dress := _dress_spawn_street(roads, rng)
	landmarks += spawn_dress
	var signs := _add_road_name_signs(roads)
	var demo_scenery := _add_demo_scenery(rng)

	print(
		"PHASE1 map: %d ways, shops~%d props~%d lots~%d landmarks~%d road_signs~%d osm_features~%d flyovers~%d demo_scenery~%d spawn=(%.1f,%.1f)"
		% [roads.size(), shops, props, lots, landmarks, signs, footprints, flyovers, demo_scenery, spawn_position.x, spawn_position.z]
	)


func _resolve_spawn(data: Dictionary, roads: Array) -> void:
	if data.has("spawn"):
		var spawn_data: Dictionary = _anchor_from_dict(data["spawn"])
		spawn_position = spawn_data["pos"] + Vector3(0, 0.43, 0)
		spawn_heading = spawn_data["heading"]
		return
	if not roads.is_empty():
		var p0: Array = (roads[0] as Dictionary)["points"][0]
		spawn_position = Vector3(float(p0[0]), 1.0, float(p0[1]))
		spawn_heading = Vector2(0, -1)


func dens_preview(pts: Array) -> float:
	return _density_for_polyline(pts)


func _density_for_polyline(pts: Array) -> float:
	## 1.0 = dense core, 0.45 = medium, 0 = skip dressing
	var mid: Array = pts[int(pts.size() / 2.0)]
	var d := Vector3(float(mid[0]), 0, float(mid[1])).distance_to(Vector3(spawn_position.x, 0, spawn_position.z))
	if d <= dense_radius:
		return 1.0
	if d <= medium_radius:
		return 0.45
	return 0.0


func _near_spawn(pos: Vector3, clear_m: float) -> bool:
	return pos.distance_to(Vector3(spawn_position.x, 0.0, spawn_position.z)) < clear_m


func _ground_pos(p: Vector3) -> Vector3:
	## Buildings/props sit on world ground — not on car spawn lift (spawn_position.y).
	return Vector3(p.x, 0.0, p.z)


func _dress_road_sides(pts: Array, width: float, dens: float, hw: String, rng: RandomNumberGenerator) -> int:
	var placed := 0
	var step := 2 if dens > 0.8 else 3
	# Wide setback so buildings never eat the lane / camera (screenshot jam fix)
	var setback := 5.5 if hw in ["primary", "secondary", "trunk", "tertiary"] else 4.8
	var commercial := hw in ["primary", "secondary", "tertiary", "unclassified"]
	var cart_path := AssetKit.building_path("bhelpuri") # ~3 m street-food cart GLB
	var has_cart := AssetKit.exists(cart_path)
	for i in range(0, pts.size() - 1, step):
		var a: Array = pts[i]
		var b: Array = pts[mini(i + 1, pts.size() - 1)]
		var p0 := Vector3(float(a[0]), 0, float(a[1]))
		var p1 := Vector3(float(b[0]), 0, float(b[1]))
		var along := p1 - p0
		if along.length() < 4.0:
			continue
		along = along.normalized()
		var outward := Vector3(-along.z, 0, along.x)
		var yaw := atan2(along.x, along.z)
		var seg_len := p0.distance_to(p1)
		var mid_pt := (p0 + p1) * 0.5
		# Solid collision buildings stay off the drive lane; visual kits OK closer in
		var core_clear := _near_spawn(mid_pt, 16.0)
		var near_spawn := _near_spawn(mid_pt, 32.0)
		var side_signs: Array[float] = [-1.0, 1.0]
		for side_sign in side_signs:
			var side: Vector3 = outward * side_sign
			var walk_pos: Vector3 = mid_pt + side * (width * 0.5 + 1.15)
			StreetKit.add_box(
				self,
				Vector3(2.3, 0.1, maxf(seg_len, 3.0)),
				walk_pos + Vector3(0, 0.05, 0),
				_sidewalk,
				false,
				yaw
			)
			# Street-food cart — sidewalk only, rare (never on asphalt)
			if has_cart and dens > 0.75 and rng.randf() < 0.06:
				var cp := _off_carriageway(p0, along, 1.0 if side.dot(Vector3(-along.z, 0, along.x)) > 0.0 else -1.0, 4.0)
				if not _near_spawn(cp, 20.0) and not _near_road(cp, 4.0):
					var cart := AssetKit.place_at(self, cart_path, cp, atan2(-side.x, -side.z), 1.0)
					if cart:
						_strip_physics(cart)
			if core_clear:
				continue
			var chance := dens * (0.55 if commercial else 0.32)
			if near_spawn:
				chance = maxf(chance, 0.75)
			if rng.randf() > chance:
				continue
			var row_origin: Vector3 = p0 + side * (width * 0.5 + setback)
			var count := 1
			if dens > 0.75 and commercial and rng.randf() < 0.5:
				count = 2
			# Own multi-storey facades (BuildingKit); +Z front faces the road (= -side)
			var bkind := "commercial" if commercial else "residential"
			for s in count:
				var bw := rng.randf_range(7.0, 12.0)
				var bd := rng.randf_range(7.0, 10.0)
				var bp := _ground_pos(row_origin + along * float(s) * 10.0 + side * 4.5)
				if _near_spawn(bp, 16.0):
					continue
				if _near_road(bp, 5.5):
					continue
				BuildingKit.footprint(self, bp, Vector2(bw, bd), bkind, _pos_seed(bp), -side)
				placed += 1
			if dens > 0.8 and rng.randf() < 0.12:
				var wall_pos: Vector3 = p0 + side * (width * 0.5 + setback + 7.0) + along * 4.0
				if not _near_spawn(wall_pos, 36.0):
					StreetKit.compound_wall(self, wall_pos, along, rng.randf_range(8.0, 14.0))
	return placed


func _dress_road_props(pts: Array, width: float, dens: float, hw: String, rng: RandomNumberGenerator) -> int:
	var n := 0
	var stride := 3 if dens > 0.8 else 5
	var wide_enough := width >= 7.5
	var light_path := AssetKit.prop_path("street_light")
	var barrier_path := AssetKit.prop_path("barrier")
	var rick_path := AssetKit.vehicle_path("autorickshaw")
	var heavy_ok := hw in ["primary", "secondary", "tertiary"] and dens > 0.55
	var sw_count := 0
	for i in range(0, pts.size() - 1, stride):
		var a: Array = pts[i]
		var b: Array = pts[mini(i + 1, pts.size() - 1)]
		var p0 := Vector3(float(a[0]), 0, float(a[1]))
		var p1 := Vector3(float(b[0]), 0, float(b[1]))
		var along := (p1 - p0)
		if along.length() < 2.0:
			continue
		along = along.normalized()
		var outward := Vector3(-along.z, 0, along.x)
		var yaw := atan2(along.x, along.z)
		var spawn_soft := _near_spawn(p0, 18.0)
		# Sidewalk kit strip (grounded); HQ mesh on densest stretches, tiles every 3rd in core
		if dens > 0.45 and i % (stride * 2) == 0:
			var sw_key := "sidewalk_8m"
			if dens > 0.85 and AssetKit.exists(AssetKit.sidewalk_path("sidewalk_8m_hq")):
				sw_key = "sidewalk_8m_hq"
			if dens > 0.8 and sw_count % 3 == 2 and AssetKit.exists(AssetKit.sidewalk_path("tiles")):
				sw_key = "tiles"
			sw_count += 1
			var sw := AssetKit.sidewalk_path(sw_key)
			if AssetKit.exists(sw):
				var sw_n := AssetKit.place_at(self, sw, _ground_pos(p0 + outward * (width * 0.5 + 2.0)), yaw, 1.0)
				if sw_n and spawn_soft:
					_strip_physics(sw_n)
				n += 1
		# Parked bus / truck (visual only) on major roads in the core
		if heavy_ok and _parked_heavy < PARKED_HEAVY_MAX:
			var roll := rng.randf()
			var heavy_key := ""
			if roll < 0.05:
				heavy_key = "truck"
			elif roll < 0.10:
				heavy_key = "bus"
			if heavy_key != "":
				var heavy_path := AssetKit.vehicle_path(heavy_key)
				var hp := _ground_pos(p0 + outward * (width * 0.5 + 4.2))
				if AssetKit.exists(heavy_path) and not _near_spawn(hp, 16.0):
					var hv := AssetKit.place_at(self, heavy_path, hp, yaw, 1.0)
					if hv:
						_strip_physics(hv)
						_parked_heavy += 1
						n += 1
		if rng.randf() < dens * 0.4 or (spawn_soft and rng.randf() < 0.55):
			var light_use := light_path
			var light_b := AssetKit.prop_path("street_light_b")
			if AssetKit.exists(light_b) and rng.randf() < 0.45:
				light_use = light_b
			if AssetKit.exists(light_use):
				var ln := AssetKit.place_at(self, light_use, _ground_pos(p0 + outward * (width * 0.5 + 1.7)), yaw, 1.0)
				if ln and spawn_soft:
					_strip_physics(ln)
			else:
				StreetKit.lamp(self, p0 + outward * (width * 0.5 + 1.55))
			n += 1
		elif dens > 0.7 and rng.randf() < 0.2 and not spawn_soft:
			StreetKit.utility_pole(self, p0 - outward * (width * 0.5 + 1.6))
			n += 1
		if rng.randf() < dens * 0.3 and not spawn_soft:
			StreetKit.tree(self, p0 - outward * (width * 0.5 + rng.randf_range(4.0, 7.5)), rng)
			n += 1
		if dens > 0.7 and wide_enough and hw in ["primary", "secondary", "tertiary"] and rng.randf() < 0.14:
			var park := p0 + outward * (width * 0.5 + 3.8) + along * rng.randf_range(1.0, 3.0)
			if _near_spawn(park, 14.0):
				continue
			if AssetKit.exists(rick_path) and rng.randf() < 0.7:
				AssetKit.place_at(self, rick_path, _ground_pos(park), yaw, 1.0)
			else:
				StreetKit.parked_stub(self, park, along, rng)
			n += 1
		if dens > 0.8 and AssetKit.exists(barrier_path) and rng.randf() < 0.08 and not spawn_soft:
			var bpos := _ground_pos(p0 + outward * (width * 0.5 + 2.8))
			if not _near_road(bpos, maxf(3.5, width * 0.3)):
				var bn := AssetKit.place_at(self, barrier_path, bpos, yaw, 1.0)
				if bn:
					_strip_physics(bn)
					n += 1
		if dens > 0.85 and rng.randf() < 0.06 and not spawn_soft:
			var bb := _ground_pos(p0 + outward * (width * 0.5 + 11.0))
			if not _near_road(bb, 5.0):
				StreetKit.billboard(self, bb, -outward, rng)
				n += 1
		elif dens > 0.6 and hw in ["primary", "secondary"] and rng.randf() < 0.05 and not spawn_soft:
			var hp2 := _ground_pos(p0 + outward * (width * 0.5 + 9.0))
			if not _near_road(hp2, 5.5):
				StreetKit.hoarding(self, hp2, -outward, rng)
				n += 1
		if dens > 0.5 and rng.randf() < 0.07 and not _near_spawn(p0, 12.0):
			var db := _ground_pos(p0 + outward * (width * 0.5 + 3.2) + along * 1.5)
			if not _near_road(db, maxf(3.5, width * 0.3)):
				StreetKit.dustbin_pair(self, db, yaw)
				n += 1
	return n


func _add_ground(clip: float) -> void:
	var size := clip * 2.2
	# Dusty Maharashtra base — CC0 ground037 (triplanar, ~12 m tiles), collision kept
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.62, 0.56, 0.44)
	ground.roughness = 1.0
	ground.metallic = 0.0
	if ResourceLoader.exists(GROUND_ALBEDO):
		ground.albedo_texture = load(GROUND_ALBEDO) as Texture2D
	if ResourceLoader.exists(GROUND_NORMAL):
		var nrm := load(GROUND_NORMAL) as Texture2D
		if nrm:
			ground.normal_enabled = true
			ground.normal_texture = nrm
			ground.normal_scale = 0.6
	ground.uv1_triplanar = true
	ground.uv1_scale = Vector3(0.08, 0.08, 0.08)
	ground.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	StreetKit.add_box(self, Vector3(size, 1.0, size), Vector3(0, -0.5, 0), ground, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	# Mixed dirt / scrub / packed earth patches (fewer now that the base is textured)
	for _i in 32:
		var px := rng.randf_range(-clip, clip)
		var pz := rng.randf_range(-clip, clip)
		if Vector2(px, pz).length() < 35.0:
			continue
		var tone := rng.randi_range(0, 2)
		var col := Color(0.28, 0.38, 0.22) # scrub
		if tone == 1:
			col = Color(0.45, 0.38, 0.28) # packed earth
		elif tone == 2:
			col = Color(0.32, 0.3, 0.28) # dusty lot
		StreetKit.add_box(
			self,
			Vector3(rng.randf_range(16, 42), 0.07, rng.randf_range(16, 42)),
			Vector3(px, 0.02, pz),
			_mat(col)
		)


func _add_osm_context(data: Dictionary, rng: RandomNumberGenerator) -> int:
	## Real OSM footprints / water / landuse inside the Dhule clip. Not all of India.
	var n := 0
	var water_mat := _mat(Color(0.25, 0.45, 0.55), 0.35)
	var land_cols := {
		"residential": _mat(Color(0.45, 0.4, 0.32)),
		"commercial": _mat(Color(0.5, 0.46, 0.4)),
		"retail": _mat(Color(0.52, 0.44, 0.36)),
		"grass": _mat(Color(0.32, 0.42, 0.26)),
		"farmland": _mat(Color(0.48, 0.42, 0.24)),
	}
	for lu_v in data.get("landuse", []):
		var lu: Dictionary = lu_v
		var pos := Vector3(float(lu.get("x", 0)), 0, float(lu.get("z", 0)))
		if _near_spawn(pos, 28.0):
			continue
		var kind := str(lu.get("kind", "residential"))
		var col: Material = land_cols.get(kind, land_cols["residential"])
		StreetKit.osm_patch(self, pos, Vector2(float(lu.get("w", 20)), float(lu.get("d", 20))), col)
		n += 1
	for w_v in data.get("water", []):
		var w: Dictionary = w_v
		var pos := Vector3(float(w.get("x", 0)), 0, float(w.get("z", 0)))
		StreetKit.osm_patch(self, pos + Vector3(0, 0.01, 0), Vector2(float(w.get("w", 12)), float(w.get("d", 12))), water_mat)
		n += 1
	var cart_path := AssetKit.building_path("bhelpuri") # ~3 m street-food cart GLB
	var has_cart := AssetKit.exists(cart_path)
	for b_v in data.get("buildings", []):
		var b: Dictionary = b_v
		var pos := _ground_pos(Vector3(float(b.get("x", 0)), 0.0, float(b.get("z", 0))))
		if _near_spawn(pos, 26.0):
			continue
		if _near_road(pos, 8.0):
			continue
		# OSM h is a constant 8 in this export — BuildingKit derives floors from plan area.
		var fw := clampf(float(b.get("w", 8)), 4.0, 28.0)
		var fd := clampf(float(b.get("d", 8)), 4.0, 28.0)
		var in_dense := pos.distance_to(Vector3(spawn_position.x, 0.0, spawn_position.z)) <= dense_radius
		var kind := str(b.get("kind", "yes"))
		if kind == "yes" or kind.is_empty():
			kind = "commercial" if (in_dense and rng.randf() < 0.4) else "residential"
		var face_dir := _face_toward_road(pos, 40.0, rng)
		BuildingKit.footprint(self, pos, Vector2(fw, fd), kind, _pos_seed(pos), face_dir)
		n += 1
		# Street-food cart out front of ~1 in 5 commercial buildings (visual only)
		if has_cart and kind == "commercial" and rng.randf() < 0.2:
			var cp := _ground_pos(pos + face_dir * (fd * 0.5 + 3.0))
			if not _near_road(cp, 4.5) and not _near_spawn(cp, 16.0):
				var cart := AssetKit.place_at(self, cart_path, cp, atan2(face_dir.x, face_dir.z), 1.0)
				if cart:
					_strip_physics(cart)
	var poi_n := 0
	for p_v in data.get("pois", []):
		if poi_n >= 12:
			break
		var p: Dictionary = p_v
		var pos := Vector3(float(p.get("x", 0)), 0, float(p.get("z", 0)))
		var poi_name := str(p.get("name", "POI"))
		var poi_kind := str(p.get("kind", ""))
		var label_y := 4.2
		if not _near_road(pos, 10.0) and not _near_spawn(pos, 30.0):
			var face := _face_toward_road(pos, 60.0, rng)
			var bh := BuildingKit.landmark(self, pos, poi_name, poi_kind, _pos_seed(pos), face)
			label_y = bh + 1.5
		var label := Label3D.new()
		label.text = poi_name
		label.font_size = 28
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.95, 0.93, 0.85)
		label.position = pos + Vector3(0, label_y, 0)
		add_child(label)
		poi_n += 1
		n += 1
	return n


func _sample_road(pts: Array, width: float) -> void:
	## Centerline samples only (plus half-width) so sidewalk props are not false-flagged.
	var step := maxi(1, int(pts.size() / 8.0))
	var half := maxf(width * 0.5, 4.0)
	for i in range(0, pts.size(), step):
		var p: Array = pts[i]
		# Encode half-width in Y so _near_road can clear the full carriageway
		_road_samples.append(Vector3(float(p[0]), half, float(p[1])))


func _near_road(pos: Vector3, clear_m: float) -> bool:
	## True if pos is on/near the driveable asphalt (centerline ± half-width + clear_m).
	var flat := Vector3(pos.x, 0.0, pos.z)
	for s in _road_samples:
		var half: float = maxf(s.y, 4.0)
		var center := Vector3(s.x, 0.0, s.z)
		if flat.distance_to(center) < half + clear_m:
			return true
	return false


func _off_carriageway(center: Vector3, along: Vector3, side_sign: float, clear_m: float = 3.5) -> Vector3:
	## Push a prop off the asphalt. Delivery anchors sit on the centerline — side*8 is often still on-road.
	var a := Vector3(along.x, 0.0, along.z)
	if a.length() < 0.01:
		a = Vector3(0, 0, -1)
	a = a.normalized()
	var side := Vector3(-a.z, 0.0, a.x) * side_sign
	for dist in [12.0, 15.0, 18.0, 22.0, 28.0, 36.0]:
		var p := _ground_pos(center + side * dist)
		if not _near_road(p, clear_m):
			return p
	return _ground_pos(center + side * 42.0)


func _pos_seed(pos: Vector3) -> int:
	## Deterministic per-plot seed from integer world XZ.
	return hash(Vector2i(int(round(pos.x)), int(round(pos.z))))


func _face_toward_road(pos: Vector3, max_m: float, rng: RandomNumberGenerator) -> Vector3:
	## Unit XZ direction from pos to the nearest road sample within max_m, else random yaw.
	var best_d := max_m
	var best := Vector3.ZERO
	var found := false
	var flat := Vector3(pos.x, 0.0, pos.z)
	for s in _road_samples:
		var d := flat.distance_to(s)
		if d < best_d and d > 0.01:
			best_d = d
			best = s
			found = true
	if found:
		var dir := Vector3(best.x - flat.x, 0.0, best.z - flat.z)
		if dir.length() > 0.01:
			return dir.normalized()
	var ang := rng.randf() * TAU
	return Vector3(sin(ang), 0.0, cos(ang))


func _strip_physics(root: Node) -> void:
	if root is PhysicsBody3D:
		var body := root as PhysicsBody3D
		body.collision_layer = 0
		body.collision_mask = 0
	if root is CollisionShape3D:
		(root as CollisionShape3D).disabled = true
	for c in root.get_children():
		_strip_physics(c)


func _add_demo_scenery(rng: RandomNumberGenerator) -> int:
	## Terrain3D demo rocks + Road Generator edge barriers (off spawn / off lane).
	var n := 0
	var rock_keys := ["rock_a", "rock_b", "rock_c"]
	var rock_goal := rng.randi_range(8, 15)
	var rock_attempts := rock_goal * 10
	while n < rock_goal and rock_attempts > 0:
		rock_attempts -= 1
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(90.0, mini(medium_radius + 100.0, 500.0))
		var pos := Vector3(
			spawn_position.x + cos(ang) * dist,
			0.0,
			spawn_position.z + sin(ang) * dist
		)
		if _near_spawn(pos, 80.0):
			continue
		if _near_road(pos, 11.0):
			continue
		var key: String = rock_keys[rng.randi() % rock_keys.size()]
		var path := AssetKit.scenery_path(key)
		if not AssetKit.exists(path):
			continue
		if AssetKit.place_at(self, path, pos, rng.randf() * TAU, rng.randf_range(0.65, 1.4)) != null:
			n += 1

	var barrier_path := AssetKit.scenery_path("edge_barrier")
	var barrier_goal := rng.randi_range(1, 2)
	if AssetKit.exists(barrier_path) and not _road_samples.is_empty():
		var placed_barriers := 0
		var tries := 40
		while placed_barriers < barrier_goal and tries > 0:
			tries -= 1
			var base: Vector3 = _road_samples[rng.randi() % _road_samples.size()]
			if _near_spawn(base, 55.0):
				continue
			var off := Vector3(cos(rng.randf() * TAU), 0.0, sin(rng.randf() * TAU))
			var bpos := base + off * rng.randf_range(9.5, 13.5)
			if _near_road(bpos, 6.5):
				continue
			var barrier := AssetKit.place_at(self, barrier_path, bpos, rng.randf() * TAU, 1.0)
			if barrier != null:
				placed_barriers += 1
				n += 1

	# Tunnel mesh is a huge white tube that reads as "flying junk" in screenshots — skip for Phase 1.
	return n


func _near_delivery_anchor(pos: Vector3, clear_m: float) -> bool:
	for a_v in delivery_anchors:
		var a: Dictionary = a_v
		var ap: Vector3 = a.get("pos", Vector3.ZERO)
		if pos.distance_to(Vector3(ap.x, 0.0, ap.z)) < clear_m:
			return true
	return false


func _fill_empty_lots(clip: float, rng: RandomNumberGenerator) -> int:
	## Phase 1C — courtyard plots so empty tan ground between buildings disappears.
	var n := 0
	var attempts := 160
	for _i in attempts:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(28.0, mini(dense_radius + 80.0, clip * 0.75))
		var pos := Vector3(
			spawn_position.x + cos(ang) * dist,
			0.0,
			spawn_position.z + sin(ang) * dist
		)
		if _near_spawn(pos, 40.0):
			continue
		if _near_road(pos, 11.0):
			continue
		if _near_delivery_anchor(pos, 18.0):
			continue
		var with_shed := not _near_spawn(pos, 70.0)
		StreetKit.filled_lot(self, pos, rng, with_shed)
		n += 1
		if n >= 72:
			break
	# Extra ring of scrub + packed-earth patches closer to roads (breaks desert look)
	for _j in 40:
		var ang2 := rng.randf() * TAU
		var dist2 := rng.randf_range(20.0, dense_radius * 0.9)
		var p2 := Vector3(
			spawn_position.x + cos(ang2) * dist2,
			0.0,
			spawn_position.z + sin(ang2) * dist2
		)
		if _near_spawn(p2, 18.0) or _near_road(p2, 6.0):
			continue
		var col := Color(0.3, 0.4, 0.24) if rng.randf() < 0.45 else Color(0.48, 0.4, 0.3)
		StreetKit.add_box(
			self,
			Vector3(rng.randf_range(8.0, 18.0), 0.05, rng.randf_range(8.0, 16.0)),
			p2 + Vector3(0, 0.02, 0),
			_mat(col),
			false
		)
		n += 1
	return n


func _add_road_name_signs(roads: Array) -> int:
	## Real OSM names (not Google). Quieter labels — less debug clutter.
	var placed_names: Dictionary = {}
	var n := 0
	for road_v in roads:
		var road: Dictionary = road_v
		var road_name := str(road.get("name", "")).strip_edges()
		if road_name.is_empty():
			continue
		if placed_names.has(road_name):
			continue
		var dens := _density_for_polyline(road.get("points", []))
		if dens <= 0.0:
			continue
		var pts: Array = road.get("points", [])
		if pts.size() < 2:
			continue
		var mid_i := int(pts.size() / 2.0)
		var p: Array = pts[mid_i]
		var p1: Array = pts[mini(mid_i + 1, pts.size() - 1)]
		var pos := Vector3(float(p[0]), 0.0, float(p[1]))
		var along := Vector3(float(p1[0]) - pos.x, 0.0, float(p1[1]) - pos.z)
		if along.length() < 0.1:
			along = Vector3(0, 0, -1)
		along = along.normalized()
		var side := Vector3(-along.z, 0, along.x) * 7.2
		var label := Label3D.new()
		label.text = road_name
		label.font_size = 36
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 4
		label.modulate = Color(0.95, 0.93, 0.88, 0.92)
		label.position = pos + side + Vector3(0, 2.4, 0)
		add_child(label)
		StreetKit.add_box(self, Vector3(0.1, 2.2, 0.1), pos + side + Vector3(0, 1.1, 0), _mat(Color(0.35, 0.35, 0.38)))
		StreetKit.add_box(self, Vector3(2.2, 0.55, 0.08), pos + side + Vector3(0, 2.4, 0), _mat(Color(0.1, 0.32, 0.18)))
		placed_names[road_name] = true
		n += 1
		var sign_max := 10
		var gs := get_node_or_null("/root/GameSettings")
		if gs and gs.has_method("road_sign_max"):
			sign_max = int(gs.call("road_sign_max"))
		if n >= sign_max:
			break
	return n


func _dress_spawn_street(_roads: Array, rng: RandomNumberGenerator) -> int:
	## First-camera frontage: mixed kit + procedural shops (not one repeated stall).
	var n := 0
	var shop_path := AssetKit.building_path("bhelpuri")
	var sw := AssetKit.sidewalk_path("sidewalk_8m")
	var light := AssetKit.prop_path("street_light")
	var barrier := AssetKit.prop_path("barrier")
	var bullock := AssetKit.prop_path("bullock")
	var forward := Vector3(spawn_heading.x, 0.0, spawn_heading.y).normalized()
	if forward.length() < 0.1:
		forward = Vector3(0, 0, -1)
	var right := Vector3(-forward.z, 0, forward.x)
	for side_sign in [-1.0, 1.0]:
		for i in 5:
			var along_d := 18.0 + float(i) * 12.0
			var toward_road: Vector3 = -right * side_sign
			var row_c := spawn_position + forward * along_d
			# Buildings well off the lane
			var bpos := _off_carriageway(row_c, forward, side_sign, 7.0)
			if _near_spawn(bpos, 16.0):
				continue
			var bkind := "commercial" if i % 2 == 0 else "residential"
			BuildingKit.footprint(self, bpos, Vector2(rng.randf_range(8.0, 11.0), rng.randf_range(7.0, 8.0)), bkind, _pos_seed(bpos), toward_road)
			n += 1
			# Cart / sidewalk / light on footpath only
			var foot := _off_carriageway(row_c, forward, side_sign, 5.5)
			if AssetKit.exists(shop_path) and i % 2 == 0 and not _near_road(foot, 5.0):
				var node := AssetKit.place_at(self, shop_path, foot, atan2(toward_road.x, toward_road.z), 1.0)
				if node:
					_strip_physics(node)
					n += 1
			if AssetKit.exists(sw) and i % 2 == 0 and not _near_road(foot, 4.5):
				var sw_n := AssetKit.place_at(self, sw, foot + toward_road * 1.2, atan2(forward.x, forward.z), 1.0)
				if sw_n:
					_strip_physics(sw_n)
					n += 1
			if AssetKit.exists(light):
				var lp := _off_carriageway(row_c + forward * 2.0, forward, side_sign, 5.0)
				if not _near_road(lp, 4.5):
					var ln := AssetKit.place_at(self, light, lp, atan2(forward.x, forward.z), 1.0)
					if ln:
						_strip_physics(ln)
						n += 1
	if AssetKit.exists(barrier):
		var bpos2 := _off_carriageway(spawn_position + forward * 14.0, forward, 1.0, 5.0)
		if not _near_road(bpos2, 4.5):
			var bn := AssetKit.place_at(self, barrier, bpos2, atan2(forward.x, forward.z), 1.0)
			if bn:
				_strip_physics(bn)
				n += 1
	if AssetKit.exists(bullock):
		var cart := AssetKit.place_at(
			self,
			bullock,
			_ground_pos(spawn_position + forward * 58.0 + right * -14.0),
			atan2(forward.x, forward.z) + PI * 0.5,
			0.55
		)
		if cart:
			_strip_physics(cart)
			n += 1
	var rick := AssetKit.vehicle_path("autorickshaw")
	if AssetKit.exists(rick):
		for i in 2:
			var rp := _ground_pos(spawn_position + forward * (24.0 + float(i) * 18.0) + right * 9.0)
			var rn := AssetKit.place_at(self, rick, rp, atan2(forward.x, forward.z), 1.0)
			if rn:
				_strip_physics(rn)
				n += 1
	return n


func _add_landmarks(rng: RandomNumberGenerator) -> int:
	## Sidewalk scenery only — never on the carriageway (fixes stall/bus-stop-in-road bug).
	var n := 0
	var forward := Vector3(spawn_heading.x, 0.0, spawn_heading.y).normalized()
	if forward.length() < 0.1:
		forward = Vector3(0, 0, -1)
	var right := Vector3(-forward.z, 0, forward.x)
	var shop_path := AssetKit.building_path("bhelpuri")

	var wt := _off_carriageway(spawn_position + forward * 55.0, forward, 1.0, 8.0)
	StreetKit.water_tower(self, wt)
	n += 1

	var bs := _off_carriageway(spawn_position + forward * 28.0, forward, -1.0, 8.0)
	if not _near_spawn(bs, 12.0) and not _near_road(bs, 6.0):
		StreetKit.bus_stop(self, bs, forward)
		n += 1
	var shrine := _off_carriageway(spawn_position + forward * 36.0, forward, 1.0, 8.0)
	if not _near_road(shrine, 6.0):
		StreetKit.roadside_shrine(self, shrine, forward)
		n += 1

	var stall_p := _off_carriageway(spawn_position + forward * 26.0, forward, -1.0, 8.0)
	if AssetKit.exists(shop_path) and not _near_spawn(stall_p, 12.0) and not _near_road(stall_p, 6.0):
		var stall := AssetKit.place_at(self, shop_path, stall_p, atan2(-right.x, -right.z), 0.95)
		if stall:
			_strip_physics(stall)
			n += 1
	elif not _near_spawn(stall_p, 12.0) and not _near_road(stall_p, 6.0):
		StreetKit.chai_stall(self, stall_p, rng)
		n += 1

	for _i in 3:
		var try_c := spawn_position + forward * rng.randf_range(40.0, 90.0)
		var stall_pos := _off_carriageway(try_c, forward, 1.0 if rng.randf() < 0.5 else -1.0, 8.0)
		if _near_spawn(stall_pos, 16.0) or _near_road(stall_pos, 6.5):
			continue
		if AssetKit.exists(shop_path) and rng.randf() < 0.65:
			var sn := AssetKit.place_at(self, shop_path, stall_pos, rng.randf() * TAU, rng.randf_range(0.85, 1.05))
			if sn:
				_strip_physics(sn)
				n += 1
		else:
			StreetKit.market_stall(self, stall_pos, rng)
			n += 1

	var rick_path := AssetKit.vehicle_path("autorickshaw")
	var rpos1 := _off_carriageway(spawn_position + forward * 22.0, forward, 1.0, 5.5)
	var rpos2 := _off_carriageway(spawn_position + forward * 50.0, forward, -1.0, 5.5)
	if AssetKit.exists(rick_path):
		for rp in [rpos1, rpos2]:
			if _near_spawn(rp, 10.0):
				continue
			var rn := AssetKit.place_at(self, rick_path, rp, atan2(forward.x, forward.z), 1.0)
			if rn:
				_strip_physics(rn)
				n += 1
	else:
		StreetKit.auto_rickshaw(self, rpos1, forward, rng)
		StreetKit.auto_rickshaw(self, rpos2, -forward, rng)
		n += 2

	var count := mini(12, delivery_anchors.size())
	for i in count:
		var a: Dictionary = delivery_anchors[i]
		var p: Vector3 = a["pos"]
		var hx: Vector2 = a.get("heading", Vector2(1, 0))
		var along := Vector3(hx.x, 0, hx.y)
		if along.length() < 0.1:
			along = Vector3(1, 0, 0)
		along = along.normalized()
		var sign: float = 1.0 if i % 2 == 0 else -1.0
		var spot := _off_carriageway(p, along, sign, 8.0)
		if _near_road(spot, 6.5):
			continue
		match i % 4:
			0:
				StreetKit.bus_stop(self, spot, along)
				var chai_p := _off_carriageway(p + along * 5.0, along, sign, 8.0)
				if not _near_road(chai_p, 6.5):
					StreetKit.chai_stall(self, chai_p, rng)
			1:
				StreetKit.roadside_shrine(self, spot, along)
				StreetKit.dustbin_pair(self, spot + along * 2.5, atan2(along.x, along.z))
			2:
				StreetKit.market_stall(self, spot, rng)
				var hp := _off_carriageway(p, along, -sign, 8.5)
				if not _near_road(hp, 6.5):
					StreetKit.hoarding(self, hp, -Vector3(-along.z, 0, along.x) * sign, rng)
			_:
				StreetKit.tree(self, spot, rng)
				var park := _off_carriageway(p + along * 3.0, along, sign, 7.0)
				if not _near_road(park, 5.0):
					StreetKit.parked_stub(self, park, along, rng)
		n += 2

	var wt2 := _off_carriageway(spawn_position + forward * 120.0, forward, -1.0, 10.0)
	StreetKit.water_tower(self, wt2)
	n += 1
	var hoard := _off_carriageway(spawn_position + forward * 70.0, forward, 1.0, 8.0)
	StreetKit.hoarding(self, hoard, -right, rng)
	n += 1
	return n


func _build_road_strip(pts: Array, width: float, mat: Material, hw: String = "residential") -> void:
	## Merge near-colinear OSM verts into long decks so center dashes stay along the path
	## and seams read as one continuous strip. avenue → V-along; street_road → U-along.
	var shoulder := _mat(Color(0.42, 0.4, 0.36), 0.95)
	var is_major := hw in ["primary", "secondary", "trunk", "motorway", "tertiary"]
	# Both kit albedos normalized to U-along in AssetKit.road_albedo_clean
	var along_u := true
	var tile_m := 12.0 if is_major else 10.0
	var barrier_path := AssetKit.prop_path("barrier")
	var has_barrier := AssetKit.exists(barrier_path)
	var i := 0
	var run_i := 0
	while i < pts.size() - 1:
		var a0: Array = pts[i]
		var b0: Array = pts[i + 1]
		var p_start := Vector3(float(a0[0]), 0.0, float(a0[1]))
		var p_next := Vector3(float(b0[0]), 0.0, float(b0[1]))
		var d0 := p_next - p_start
		var len0 := d0.length()
		if len0 < 0.5:
			i += 1
			continue
		var dir0 := d0 / len0
		var p_end := p_next
		var total_len := len0
		var j := i + 1
		# Extend while the polyline stays roughly straight (auto-connect)
		while j < pts.size() - 1 and total_len < 48.0:
			var aj: Array = pts[j]
			var bj: Array = pts[j + 1]
			var pj0 := Vector3(float(aj[0]), 0.0, float(aj[1]))
			var pj1 := Vector3(float(bj[0]), 0.0, float(bj[1]))
			var dj := pj1 - pj0
			var lj := dj.length()
			if lj < 0.5:
				j += 1
				continue
			var dirj := dj / lj
			if dir0.dot(dirj) < 0.965:  # ~15° break → new deck
				break
			total_len += lj
			p_end = pj1
			j += 1
		var delta := p_end - p_start
		var length := delta.length()
		if length < 0.5:
			i = maxi(j, i + 1)
			continue
		var along := delta / length
		var side := Vector3(-along.z, 0, along.x)
		var mid := (p_start + p_end) * 0.5
		var yaw := atan2(delta.x, delta.z)
		var deck_len := length + 1.2  # slight overlap into next run
		var deck_pos := Vector3(mid.x, road_y + 0.01, mid.z)
		StreetKit.add_road_deck(self, width, deck_len, deck_pos, yaw, mat, tile_m, along_u)
		if width >= 7.0:
			var sh_y := road_y - 0.02
			StreetKit.add_box(
				self,
				Vector3(0.55, 0.06, length + 0.5),
				Vector3(mid.x, sh_y, mid.z) + side * (width * 0.5 + 0.25),
				shoulder,
				false,
				yaw
			)
			StreetKit.add_box(
				self,
				Vector3(0.55, 0.06, length + 0.5),
				Vector3(mid.x, sh_y, mid.z) - side * (width * 0.5 + 0.25),
				shoulder,
				false,
				yaw
			)
		# Metal/concrete barriers as kerbside dividers (never on centerline / drive lane)
		if has_barrier and is_major and width >= 8.0 and length > 6.0 and not _near_spawn(mid, 22.0):
			var kerb_off := width * 0.5 + 1.65
			var side_s := 1.0 if (run_i % 2 == 0) else -1.0
			var bp := _ground_pos(mid + side * (kerb_off * side_s))
			var bn := AssetKit.place_at(self, barrier_path, bp, yaw, 1.0)
			if bn:
				_strip_physics(bn)
			# Extra pieces along long wide straights (road-break / divider rhythm)
			if width >= 10.0 and length > 20.0:
				for k in range(1, 3):
					var along_p: Vector3 = p_start.lerp(p_end, float(k) / 3.0)
					var bp2 := _ground_pos(along_p + side * (kerb_off * side_s))
					var bn2 := AssetKit.place_at(self, barrier_path, bp2, yaw, 1.0)
					if bn2:
						_strip_physics(bn2)
		run_i += 1
		i = maxi(j, i + 1)


func _add_flyovers(data: Dictionary) -> int:
	## OSM bridge=yes centerlines from the Dhule tile clip. Deck + ramps, pillars visual.
	var n := 0
	var deck_y := 6.2
	var concrete := _mat(Color(0.55, 0.53, 0.5), 0.9)
	for fo_v in data.get("flyovers", []):
		var fo: Dictionary = fo_v
		var pts: Array = fo.get("points", [])
		if pts.size() < 2:
			continue
		var width := float(fo.get("width", 9.0))
		var count := pts.size() - 1
		for i in count:
			var a: Array = pts[i]
			var b: Array = pts[i + 1]
			var p0 := Vector3(float(a[0]), 0.0, float(a[1]))
			var p1 := Vector3(float(b[0]), 0.0, float(b[1]))
			var delta := p1 - p0
			var length := delta.length()
			if length < 0.8:
				continue
			var t := float(i) / float(maxi(count - 1, 1))
			var y := deck_y
			if t < 0.18:
				y = lerpf(0.35, deck_y, t / 0.18)
			elif t > 0.82:
				y = lerpf(deck_y, 0.35, (t - 0.82) / 0.18)
			# Visual only. Solid decks were pinning the car on the ground road.
			if y < 2.2:
				continue
			if _near_spawn((p0 + p1) * 0.5, 30.0):
				continue
			var mid := (p0 + p1) * 0.5 + Vector3(0, y, 0)
			var yaw := atan2(delta.x, delta.z)
			StreetKit.add_box(self, Vector3(width, 0.28, length + 0.4), mid, _major, false, yaw)
			StreetKit.add_box(self, Vector3(width + 0.35, 0.12, length + 0.3), mid + Vector3(0, -0.16, 0), concrete, false, yaw)
			if i % 4 == 0:
				StreetKit.add_box(self, Vector3(0.55, y - 0.4, 0.55), Vector3(mid.x, (y - 0.4) * 0.5, mid.z), concrete, false)
		n += 1
	return n


func _build_wear_patches(pts: Array, width: float, rng: RandomNumberGenerator) -> void:
	## Subtle darker asphalt patches — restrained, aligned to road.
	var patch := _mat(Color(0.11, 0.11, 0.12), 0.98)
	for i in range(0, pts.size() - 1, 3):
		if rng.randf() > 0.35:
			continue
		var a: Array = pts[i]
		var b: Array = pts[mini(i + 1, pts.size() - 1)]
		var p0 := Vector3(float(a[0]), road_y + 0.015, float(a[1]))
		var p1 := Vector3(float(b[0]), road_y + 0.015, float(b[1]))
		var delta := p1 - p0
		if delta.length() < 3.0:
			continue
		var mid := (p0 + p1) * 0.5
		var yaw := atan2(delta.x, delta.z)
		StreetKit.add_box(
			self,
			Vector3(width * rng.randf_range(0.25, 0.45), 0.02, rng.randf_range(2.2, 4.5)),
			mid,
			patch,
			false,
			yaw
		)


func _build_zebra_and_breakers(pts: Array, width: float, rng: RandomNumberGenerator) -> void:
	## Occasional zebra stripes + speed breakers on busy core majors.
	if pts.size() < 4:
		return
	var mid_i := int(pts.size() / 2.0)
	var a: Array = pts[mid_i]
	var b: Array = pts[mini(mid_i + 1, pts.size() - 1)]
	var p0 := Vector3(float(a[0]), road_y + 0.02, float(a[1]))
	var p1 := Vector3(float(b[0]), road_y + 0.02, float(b[1]))
	var delta := p1 - p0
	if delta.length() < 2.0:
		return
	var dir := delta.normalized()
	var yaw := atan2(delta.x, delta.z)
	var white := _mat(Color(0.92, 0.92, 0.9), 0.7)
	if rng.randf() < 0.55:
		for s in range(-3, 4):
			var stripe_mid := p0 + dir * (float(s) * 0.55)
			StreetKit.add_box(self, Vector3(width * 0.72, 0.025, 0.35), stripe_mid, white, false, yaw)
	if rng.randf() < 0.4:
		var yellow := _mat(Color(0.85, 0.55, 0.1), 0.75)
		StreetKit.add_box(self, Vector3(width * 0.85, 0.12, 0.55), p0 + dir * 6.0 + Vector3(0, 0.04, 0), yellow, false, yaw)


func _build_edge_lines(pts: Array, width: float) -> void:
	for i in range(pts.size() - 1):
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		var p0 := Vector3(float(a[0]), road_y + 0.03, float(a[1]))
		var p1 := Vector3(float(b[0]), road_y + 0.03, float(b[1]))
		var delta := p1 - p0
		if delta.length() < 1.2:
			continue
		var dir := delta.normalized()
		var mid := (p0 + p1) * 0.5
		var yaw := atan2(delta.x, delta.z)
		var side := Vector3(-dir.z, 0, dir.x) * (width * 0.5 - 0.25)
		StreetKit.add_box(self, Vector3(0.18, 0.03, delta.length()), mid + side, _edge, false, yaw)
		StreetKit.add_box(self, Vector3(0.18, 0.03, delta.length()), mid - side, _edge, false, yaw)


func _build_curbs(pts: Array, width: float) -> void:
	for i in range(0, pts.size() - 1, 2):
		var a: Array = pts[i]
		var b: Array = pts[mini(i + 1, pts.size() - 1)]
		var p0 := Vector3(float(a[0]), road_y, float(a[1]))
		var p1 := Vector3(float(b[0]), road_y, float(b[1]))
		var delta := p1 - p0
		if delta.length() < 1.0:
			continue
		var dir := delta.normalized()
		var side := Vector3(-dir.z, 0, dir.x) * (width * 0.5 + 0.28)
		var mid := (p0 + p1) * 0.5
		var yaw := atan2(delta.x, delta.z)
		StreetKit.add_box(self, Vector3(0.32, 0.2, minf(delta.length(), 9.0)), mid + side + Vector3(0, 0.06, 0), _curb, false, yaw)
		StreetKit.add_box(self, Vector3(0.32, 0.2, minf(delta.length(), 9.0)), mid - side + Vector3(0, 0.06, 0), _curb, false, yaw)


func _build_center_dashes(pts: Array) -> void:
	var i := 0
	while i < pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[mini(i + 1, pts.size() - 1)]
		var p0 := Vector3(float(a[0]), road_y + 0.025, float(a[1]))
		var p1 := Vector3(float(b[0]), road_y + 0.025, float(b[1]))
		var mid := (p0 + p1) * 0.5
		var delta := p1 - p0
		if delta.length() < 2.0:
			i += 1
			continue
		StreetKit.add_box(self, Vector3(0.22, 0.035, 2.6), mid, _paint, false, atan2(delta.x, delta.z))
		i += 2
