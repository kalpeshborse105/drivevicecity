extends Node3D
## OSM Dhule roads + S2 dense Indian street kits (own art).

signal map_ready(spawn_position: Vector3, spawn_heading: Vector2, anchors: Array)

const RoadSurface = preload("res://scripts/road_surface.gd")
const RoadLabels = preload("res://scripts/road_labels.gd")
const RoadJunctions = preload("res://scripts/road_junctions.gd")
const StreetKit = preload("res://scripts/street_kit.gd")
const AssetKit = preload("res://scripts/asset_kit.gd")
const BuildingKit = preload("res://scripts/building_kit.gd")

const GROUND_ALBEDO := "res://demo/assets/textures/ground037_alb_ht.png"
const GROUND_NORMAL := "res://demo/assets/textures/ground037_nrm_rgh.png"
const PARKED_HEAVY_MAX := 14
const NAMED_LABEL_CAP := 40  ## max real OSM building-name labels (perf guard)

@export_file("*.json") var map_json_path: String = "res://assets/maps/dhule_roads_game.json"
@export var road_y: float = 0.04
@export var dense_radius: float = 420.0
@export var medium_radius: float = 720.0

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
var _named_roads: Array = []
var _buildings: Array = []
var _parked_heavy := 0
var _named_labels := 0  ## real OSM building names drawn this map build
var _has_blosm := false


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


func _kit_road_mat(kit_key: String, tint: Color, rough: float, priority: int = 0) -> StandardMaterial3D:
	## Indian asphalt from kit PNGs. UVs come from add_road_deck (along-road), not triplanar.
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = 0.0
	m.render_priority = priority
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
	_buildings = data.get("buildings", [])
	var clip: float = float(data.get("clip_radius_m", 900.0))
	# Strict 2 kit sources: street_road = sub, avenue_street = main (asphalt crop, no yellow gutter)
	_asphalt = _kit_road_mat("street_road", Color(0.86, 0.86, 0.89), 0.9, 0)
	_major = _kit_road_mat("avenue_street", Color(0.83, 0.83, 0.87), 0.84, 1)
	_paint = _mat(Color(0.93, 0.93, 0.9), 0.55)
	_paint.render_priority = 3
	_paint.grow = true
	_paint.grow_amount = 0.012
	_edge = _paint
	_curb = _mat(Color(0.6, 0.58, 0.54), 0.95)
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
	# Shopfront nameplate budget (Dhule high-street feel); lighter when quieted.
	var sign_budget := 140
	var gs := get_node_or_null("/root/GameSettings")
	if gs and gs.get("road_sign_density") != null and int(gs.get("road_sign_density")) == 0:
		sign_budget = 48
	BuildingKit.signature_budget = sign_budget

	_add_ground(clip)
	# Batch the thousands of visual-only lane-marking / kerb / paint boxes.
	StreetKit.begin_box_batch(self)
	RoadSurface.begin_batch(self)

	var roads: Array = data.get("roads", [])
	# Resolve spawn early so density uses it
	_resolve_spawn(data, roads)
	var junction_n := RoadSurface.prepare_junctions(roads)
	print("ROAD junction prepare ", junction_n)
	var blosm_path := str(AssetKit.ENVIRONMENTS.get("dhule_blosm_city", ""))
	_has_blosm = AssetKit.exists(blosm_path)

	var rng := RandomNumberGenerator.new()
	rng.seed = 742021
	var shops := 0
	var props := 0
	var dress: Array = []

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
		# Major decks sit a hair higher so they do not z-fight residential joins.
		_build_road_strip(pts, width, mat, hw, str(road.get("id", "")), 0.014 if is_major else 0.0)
		if is_major and not _has_blosm:
			_build_curbs(pts, width)
		_sample_road(pts, width)
		var dens := _density_for_polyline(pts)
		if dens <= 0.0:
			continue
		dress.append([pts, width, dens, hw])

	var drawn := RoadSurface.draw_prepared_junctions(self, road_y, _asphalt, _major, _paint)
	var road_batches := RoadSurface.flush_batch()
	print("ROAD batches ", road_batches, " junctions ", drawn, " ", RoadJunctions.summary)
	print("ROAD join fix: pad +0.07 · major +0.014 · paint grow · stronger tip pull")

	# Props run after every road is sampled, so a tree beside one way cannot sit on another.
	for job in dress:
		var dress_pts: Array = job[0]
		var dress_width: float = job[1]
		var dress_dens: float = job[2]
		var dress_hw: String = job[3]
		if not _has_blosm:
			shops += _dress_road_sides(dress_pts, dress_width, dress_dens, dress_hw, rng)
		props += _dress_road_props(dress_pts, dress_width, dress_dens, dress_hw, rng)

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
	_add_junctions(roads)
	_add_roundabouts(roads)
	var demo_scenery := _add_demo_scenery(rng)
	# Commit every queued roadside tree as 2 MultiMesh batches (Android node-count win).
	StreetKit.flush_trees(self)
	# Commit queued visual boxes as a few MultiMesh batches (was ~13k MeshInstance3D).
	var batched_boxes := StreetKit.flush_box_batch()
	print("StreetKit box batch: %d boxes -> MultiMesh" % batched_boxes)

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
	if _has_blosm:
		return 0
	var placed := 0
	var step := 2 if dens > 0.8 else 3
	# Wide setback so buildings never eat the lane / camera (screenshot jam fix)
	var setback := 7.5 if hw in ["primary", "secondary", "trunk", "tertiary"] else 6.5
	var commercial := hw in ["primary", "secondary", "tertiary", "unclassified"]
	var cart_path := AssetKit.building_path("bhelpuri") # ~3 m street-food cart GLB
	var has_cart := AssetKit.exists(cart_path)
	# Dense GTA-style street wall: more buildings per segment in core
	step = 1 if dens > 0.85 else step
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
			# Cap strip length + reject junction crossings (brown slab across asphalt).
			var strip_len := clampf(seg_len, 3.0, 12.0)
			var walk_pos: Vector3 = mid_pt + side * (width * 0.5 + 1.35)
			if _sidewalk_strip_clear(walk_pos, along, strip_len):
				StreetKit.add_box(
					self,
					Vector3(2.0, 0.1, strip_len),
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
			if _has_blosm or core_clear:
				continue
			var chance := dens * (0.78 if commercial else 0.48)
			if near_spawn:
				chance = maxf(chance, 0.88)
			if rng.randf() > chance:
				continue
			var row_origin: Vector3 = p0 + side * (width * 0.5 + setback)
			var count := 1
			if dens > 0.55 and commercial and rng.randf() < 0.72:
				count = 2
			if dens > 0.85 and commercial and rng.randf() < 0.4:
				count = 3
			# Own multi-storey facades (BuildingKit); +Z front faces the road (= -side)
			var bkind := "commercial" if commercial else "residential"
			for s in count:
				var bw := rng.randf_range(6.5, 11.5)
				var bd := rng.randf_range(6.5, 10.0)
				var bp := _ground_pos(row_origin + along * float(s) * 9.0 + side * 4.5)
				if _near_spawn(bp, 16.0):
					continue
				if _near_road(bp, 11.0):
					continue
				# Reject if footprint corners still kiss the lane
				if _near_road(bp + side * (bd * 0.45), 9.0) or _near_road(bp - side * (bd * 0.45), 9.0):
					continue
				BuildingKit.footprint(self, bp, Vector2(bw, bd), bkind, _pos_seed(bp), -side)
				placed += 1
				# Occasional chai / fruit stall on the pavement edge (never on asphalt)
				if dens > 0.7 and rng.randf() < 0.18:
					var stall_p := _ground_pos(bp - side * (bd * 0.5 + 2.8))
					if not _near_road(stall_p, 6.5) and not _near_spawn(stall_p, 14.0):
						if rng.randf() < 0.45:
							StreetKit.chai_stall(self, stall_p, rng)
						else:
							StreetKit.market_stall(self, stall_p, rng)
						placed += 1
			if dens > 0.75 and rng.randf() < 0.16:
				var wall_pos: Vector3 = p0 + side * (width * 0.5 + setback + 7.0) + along * 4.0
				if not _near_spawn(wall_pos, 36.0):
					StreetKit.compound_wall(self, wall_pos, along, rng.randf_range(8.0, 14.0))
	return placed


func _dress_road_props(pts: Array, width: float, dens: float, hw: String, rng: RandomNumberGenerator) -> int:
	var n := 0
	var stride := 3 if dens > 0.8 else 5
	var wide_enough := width >= 7.5
	var barrier_path := AssetKit.prop_path("barrier")
	var rick_path := AssetKit.vehicle_path("autorickshaw")
	var heavy_ok := hw in ["primary", "secondary", "tertiary"] and dens > 0.55
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
		# Parked bus / truck (visual only) on major roads in the core
		if not _has_blosm and heavy_ok and _parked_heavy < PARKED_HEAVY_MAX:
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
		if rng.randf() < dens * 0.25 or (spawn_soft and not _has_blosm and rng.randf() < 0.55):
			# Procedural 6 m lamp on kerb — never GLB (overscale / rooftop look).
			var lp := _ground_pos(p0 + outward * (width * 0.5 + 2.4))
			var lamp_clear := -1.6 if _has_blosm else -0.4
			if _asphalt_depth(lp) < lamp_clear:
				StreetKit.lamp(self, lp)
				n += 1
		elif not _has_blosm and dens > 0.7 and rng.randf() < 0.2 and not spawn_soft:
			var up := _ground_pos(p0 - outward * (width * 0.5 + 1.6))
			if _asphalt_depth(up) < -0.4:
				StreetKit.utility_pole(self, up)
				n += 1
		if rng.randf() < dens * 0.22 and not spawn_soft:
			# One verge tree, 9 m past the road edge, and only if every sampled road is clear.
			var t1 := _ground_pos(p0 - outward * (width * 0.5 + 9.0))
			if _tree_site_ok(t1):
				StreetKit.tree(self, t1, rng)
				n += 1
		if not _has_blosm and dens > 0.7 and wide_enough and hw in ["primary", "secondary", "tertiary"] and rng.randf() < 0.14:
			var park := p0 + outward * (width * 0.5 + 3.8) + along * rng.randf_range(1.0, 3.0)
			if _near_spawn(park, 14.0):
				continue
			if AssetKit.exists(rick_path) and rng.randf() < 0.7:
				AssetKit.place_at(self, rick_path, _ground_pos(park), yaw, 1.0)
			else:
				StreetKit.parked_stub(self, park, along, rng)
			n += 1
		# Roadside barriers / breakers — kerb line only, never mid-lane
		if not _has_blosm and dens > 0.65 and AssetKit.exists(barrier_path) and rng.randf() < 0.16 and not spawn_soft:
			var bpos := _ground_pos(p0 + outward * (width * 0.5 + 2.6))
			if not _near_road(bpos, maxf(4.0, width * 0.35)):
				var bn := AssetKit.place_at(self, barrier_path, bpos, yaw, 1.0)
				if bn:
					_strip_physics(bn)
					n += 1
		if not _has_blosm and dens > 0.85 and rng.randf() < 0.06 and not spawn_soft:
			var bb := _ground_pos(p0 + outward * (width * 0.5 + 11.0))
			if not _near_road(bb, 5.0):
				StreetKit.billboard(self, bb, -outward, rng)
				n += 1
		elif not _has_blosm and dens > 0.6 and hw in ["primary", "secondary"] and rng.randf() < 0.05 and not spawn_soft:
			var hp2 := _ground_pos(p0 + outward * (width * 0.5 + 9.0))
			if not _near_road(hp2, 5.5):
				StreetKit.hoarding(self, hp2, -outward, rng)
				n += 1
		if not _has_blosm and dens > 0.5 and rng.randf() < 0.07 and not _near_spawn(p0, 12.0):
			var db := _ground_pos(p0 + outward * (width * 0.5 + 3.2) + along * 1.5)
			if not _near_road(db, maxf(3.5, width * 0.3)):
				StreetKit.dustbin_pair(self, db, yaw)
		# Sparse original planter GLB on sidewalks
		if not _has_blosm and dens > 0.75 and rng.randf() < 0.05 and not spawn_soft:
			var planter_path := AssetKit.prop_path("planter")
			if AssetKit.exists(planter_path):
				var pp := _ground_pos(p0 + outward * (width * 0.5 + 3.4))
				if not _near_road(pp, 5.0):
					var pn := AssetKit.place_at(self, planter_path, pp, yaw, 1.0)
					if pn:
						_strip_physics(pn)
						n += 1
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
		var lw := clampf(float(lu.get("w", 20)), 12.0, 120.0)
		var ld := clampf(float(lu.get("d", 20)), 12.0, 120.0)
		StreetKit.osm_patch(self, pos, Vector2(lw, ld), col)
		n += 1
	for w_v in data.get("water", []):
		var w: Dictionary = w_v
		var pos := Vector3(float(w.get("x", 0)), 0, float(w.get("z", 0)))
		if _near_spawn(pos, 40.0) or _near_road(pos, 14.0):
			continue
		# Cap giant Shortbread rectangles so they read as river bends, not blue oceans
		var ww := clampf(float(w.get("w", 12)), 12.0, 72.0)
		var wd := clampf(float(w.get("d", 12)), 12.0, 72.0)
		StreetKit.water_body(self, pos, Vector2(ww, wd))
		n += 1
	# Real Blender Blosm 3D Model:
	var blosm_path := str(AssetKit.ENVIRONMENTS.get("dhule_blosm_city", ""))
	if AssetKit.exists(blosm_path):
		var blosm_scene: PackedScene = load(blosm_path)
		if blosm_scene:
			var blosm_inst: Node3D = blosm_scene.instantiate()
			blosm_inst.name = "DhuleBlosmCity"
			blosm_inst.position = Vector3.ZERO
			add_child(blosm_inst)
			_has_blosm = true
			for child in blosm_inst.get_children():
				var cname := child.name.to_lower()
				if child is GeometryInstance3D:
					# The city is one mesh several kilometres wide. Godot's generated LODs
					# collapse it, so the blocks disappear around the camera.
					(child as GeometryInstance3D).lod_bias = 128.0
				if "roads" in cname or "profile" in cname:
					child.visible = false
				elif "water" in cname:
					if child is MeshInstance3D:
						var mi := child as MeshInstance3D
						var extent := mi.get_aabb().size
						if extent.x > 8000.0 or extent.z > 8000.0:
							mi.visible = false
						else:
							var w_mat := StandardMaterial3D.new()
							w_mat.albedo_color = Color(0.18, 0.42, 0.52, 0.88)
							w_mat.roughness = 0.08
							mi.material_override = w_mat
				elif "buildings" in cname:
					_collide_city_mesh(child)
			n += 1
			n += _place_osm_shops()

	var cart_path := AssetKit.building_path("bhelpuri") # ~3 m street-food cart GLB
	var has_cart := AssetKit.exists(cart_path)
	var has_shop := AssetKit.exists(AssetKit.building_path("shop"))
	var b_placed := 0
	var shop_placed := 0
	var b_cap := 460
	var shop_cap := 22
	var collide_radius := dense_radius * 1.15
	for b_v in data.get("buildings", []):
		if b_placed >= b_cap:
			break
		var b: Dictionary = b_v
		var pos := _ground_pos(Vector3(float(b.get("x", 0)), 0.0, float(b.get("z", 0))))
		if _near_spawn(pos, 26.0):
			continue
		# Never sit OSM footprints on the carriageway
		if _near_road(pos, 11.0):
			continue
		var fw := clampf(float(b.get("w", 8)), 4.0, 28.0)
		var fd := clampf(float(b.get("d", 8)), 4.0, 28.0)
		# Footprint AABB also rejects if corners / edges clip the lane
		var half_w := fw * 0.45
		var half_d := fd * 0.45
		if _near_road(pos + Vector3(half_w, 0, 0), 9.0) or _near_road(pos + Vector3(-half_w, 0, 0), 9.0):
			continue
		if _near_road(pos + Vector3(0, 0, half_d), 9.0) or _near_road(pos + Vector3(0, 0, -half_d), 9.0):
			continue
		if _near_road(pos + Vector3(half_w, 0, half_d), 8.5) or _near_road(pos + Vector3(-half_w, 0, -half_d), 8.5):
			continue
		var dist_spawn := pos.distance_to(Vector3(spawn_position.x, 0.0, spawn_position.z))
		var in_dense := dist_spawn <= dense_radius
		var with_col := dist_spawn <= collide_radius
		var kind := str(b.get("kind", "yes"))
		if kind == "yes" or kind.is_empty():
			kind = "commercial" if (in_dense and rng.randf() < 0.4) else "residential"
		var face_dir := _face_toward_road(pos, 40.0, rng)
		var yaw := atan2(face_dir.x, face_dir.z)
		# Optional shop GLB on a few commercial footprints (materials reused from one PackedScene)
		var used_shop := false
		if (
			not _has_blosm
			and has_shop
			and shop_placed < shop_cap
			and kind in ["commercial", "retail", "shop"]
			and fw >= 6.0
			and fd >= 5.0
			and fw <= 14.0
			and fd <= 12.0
			and rng.randf() < 0.22
		):
			var shop_n := AssetKit.place_shop_footprint(self, pos, Vector2(fw, fd), yaw, with_col)
			if shop_n:
				shop_placed += 1
				used_shop = true
		if not used_shop:
			var bld_name := str(b.get("name", ""))
			if _has_blosm:
				if not bld_name.is_empty() and _named_labels < NAMED_LABEL_CAP:
					_add_name_label(bld_name, pos + Vector3(0, float(b.get("h", 6.0)) + 1.6, 0))
					_named_labels += 1
			else:
				var bld_h := BuildingKit.footprint(self, pos, Vector2(fw, fd), kind, _pos_seed(pos), face_dir, with_col)
				if not bld_name.is_empty() and _named_labels < NAMED_LABEL_CAP:
					_add_name_label(bld_name, pos + Vector3(0, bld_h + 1.6, 0))
					_named_labels += 1
		b_placed += 1
		n += 1
		if not _has_blosm and has_cart and kind == "commercial" and in_dense and rng.randf() < 0.14:
			var cp := _ground_pos(pos + face_dir * (fd * 0.5 + 3.0))
			if not _near_road(cp, 5.5) and not _near_spawn(cp, 16.0):
				var cart := AssetKit.place_at(self, cart_path, cp, yaw, 1.0)
				if cart:
					_strip_physics(cart)
	var poi_n := 0
	# Cap raised to 60 — real Dhule Overpass POIs now populate this list (78 entries)
	for p_v in data.get("pois", []):
		if poi_n >= 60:
			break
		var p: Dictionary = p_v
		var pos := Vector3(float(p.get("x", 0)), 0, float(p.get("z", 0)))
		if _near_road(pos, 10.0) or _near_spawn(pos, 30.0):
			continue
		var poi_name := str(p.get("name", "POI"))
		var poi_kind := str(p.get("kind", ""))
		var face := _face_toward_road(pos, 60.0, rng)
		var bh := 8.0
		if not _has_blosm:
			bh = BuildingKit.landmark(self, pos, poi_name, poi_kind, _pos_seed(pos), face)
		var label := Label3D.new()
		label.text = poi_name
		label.font_size = 28
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.95, 0.93, 0.85)
		label.position = pos + Vector3(0, bh + 1.5, 0)
		add_child(label)
		poi_n += 1
		n += 1
	return n


func _collide_city_mesh(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).create_trimesh_collision()
	for child in node.get_children():
		_collide_city_mesh(child)


func _place_osm_shops() -> int:
	var path := "res://data/dhule/city_shops.json"
	if not FileAccess.file_exists(path):
		return 0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	var shops: Array = (parsed as Dictionary).get("shops", [])
	var placed := 0
	for shop_v in shops:
		var shop: Dictionary = shop_v
		var pos := _ground_pos(Vector3(float(shop.get("x", 0.0)), 0.0, float(shop.get("z", 0.0))))
		var face := _face_toward_road(pos, 80.0, _shop_rng(pos))
		if _asphalt_depth(pos) > -2.0:
			pos = _ground_pos(pos - face * 7.0)
		var yaw := atan2(face.x, face.z)
		var cart := AssetKit.building_path("bhelpuri")
		var node := AssetKit.place_at(self, cart, pos, yaw, 1.0)
		if node == null:
			continue
		_strip_physics(node)
		var shop_name := str(shop.get("name", "")).strip_edges()
		if not shop_name.is_empty() and _named_labels < NAMED_LABEL_CAP:
			_add_name_label(shop_name, pos + Vector3(0.0, 3.2, 0.0))
			_named_labels += 1
		placed += 1
	print("OSM shops placed: %d" % placed)
	return placed


func _shop_rng(pos: Vector3) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _pos_seed(pos)
	return rng


func _add_name_label(text: String, pos: Vector3) -> void:
	## Real OSM building name floating above its footprint (billboard).
	## Data: © OpenStreetMap contributors (ODbL).
	var label := Label3D.new()
	label.text = text
	label.font_size = 26
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 5
	label.modulate = Color(0.96, 0.94, 0.86)
	label.outline_modulate = Color(0.08, 0.08, 0.1)
	label.render_priority = 1
	label.position = pos
	add_child(label)


func _sample_road(pts: Array, width: float) -> void:
	## Dense centerline samples (~10 m) so trees/lots cannot slip onto unsampled asphalt.
	var half := maxf(width * 0.5, 3.5)
	var i := 0
	while i < pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		var p0 := Vector3(float(a[0]), 0.0, float(a[1]))
		var p1 := Vector3(float(b[0]), 0.0, float(b[1]))
		var seg := p1 - p0
		var seg_len := seg.length()
		if seg_len < 0.4:
			i += 1
			continue
		var n_steps := maxi(1, int(ceil(seg_len / 10.0)))
		for s in range(n_steps + 1):
			var p := p0.lerp(p1, float(s) / float(n_steps))
			_road_samples.append(Vector3(p.x, half, p.z))
		i += 1


func _asphalt_depth(pos: Vector3) -> float:
	## Positive = metres inside asphalt (past edge toward center). Negative = clear of roads.
	var flat := Vector3(pos.x, 0.0, pos.z)
	var best := -100000.0
	for s in _road_samples:
		var half: float = maxf(s.y, 3.5)
		var d := flat.distance_to(Vector3(s.x, 0.0, s.z))
		var pen := half - d
		if pen > best:
			best = pen
	return best


func _sidewalk_strip_clear(center: Vector3, along: Vector3, strip_len: float) -> bool:
	## Reject strips that would paint beige onto a crossing carriageway (junction slabs).
	var a := Vector3(along.x, 0.0, along.z)
	if a.length() < 0.01:
		return false
	a = a.normalized()
	var half_l := strip_len * 0.5
	var samples: Array[float] = [-0.9, -0.45, 0.0, 0.45, 0.9]
	for t in samples:
		var p: Vector3 = center + a * (half_l * t)
		if _asphalt_depth(p) > 0.35:
			return false
	return true


func _tree_site_ok(pos: Vector3) -> bool:
	## Trunk clear of asphalt + spawn; canopy (~3 m) must not sit in the drive lane.
	if _near_spawn(pos, 12.0):
		return false
	if _asphalt_depth(pos) > -5.0:
		return false
	if _near_road(pos, 4.5):
		return false
	return true


func _near_road(pos: Vector3, clear_m: float) -> bool:
	## True if pos is on/near the driveable asphalt (centerline ± half-width + clear_m).
	var flat := Vector3(pos.x, 0.0, pos.z)
	for s in _road_samples:
		var half: float = maxf(s.y, 3.5)
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
		var road_xz := Vector3(s.x, 0.0, s.z)
		var d := flat.distance_to(road_xz)
		if d < best_d and d > 0.01:
			best_d = d
			best = road_xz
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
	if _has_blosm:
		return 0
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
	## Ring 1 (≥1.4 km clip): fewer procedurals — OSM landuse/buildings fill more.
	var n := 0
	var lot_cap := 72
	var attempts := 160
	var scrub_n := 40
	if _has_blosm:
		return 0
	elif clip >= 1400.0:
		lot_cap = 36
		attempts = 100
		scrub_n = 24
	for _i in attempts:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(28.0, mini(dense_radius + 80.0, clip * 0.55))
		var pos := Vector3(
			spawn_position.x + cos(ang) * dist,
			0.0,
			spawn_position.z + sin(ang) * dist
		)
		if _near_spawn(pos, 40.0):
			continue
		# Lot floors must never sit on asphalt (brown square across lane).
		if _near_road(pos, 14.0) or _asphalt_depth(pos) > -6.0:
			continue
		if _near_delivery_anchor(pos, 18.0):
			continue
		var with_shed := not _near_spawn(pos, 70.0) and not _has_blosm
		StreetKit.filled_lot(self, pos, rng, with_shed)
		n += 1
		if n >= lot_cap:
			break
	# Extra ring of scrub + packed-earth patches closer to roads (breaks desert look)
	for _j in scrub_n:
		var ang2 := rng.randf() * TAU
		var dist2 := rng.randf_range(20.0, dense_radius * 0.9)
		var p2 := Vector3(
			spawn_position.x + cos(ang2) * dist2,
			0.0,
			spawn_position.z + sin(ang2) * dist2
		)
		if _near_spawn(p2, 18.0) or _near_road(p2, 10.0) or _asphalt_depth(p2) > -5.0:
			continue
		var col := Color(0.3, 0.4, 0.24) if rng.randf() < 0.45 else Color(0.48, 0.4, 0.3)
		var scrub_w := rng.randf_range(6.0, 12.0)
		var scrub_d := rng.randf_range(6.0, 11.0)
		# Corner probes — reject if the patch footprint reaches asphalt.
		var scrub_ok := true
		var corners: Array[Vector3] = [
			Vector3(scrub_w * 0.45, 0, scrub_d * 0.45),
			Vector3(-scrub_w * 0.45, 0, scrub_d * 0.45),
			Vector3(scrub_w * 0.45, 0, -scrub_d * 0.45),
			Vector3(-scrub_w * 0.45, 0, -scrub_d * 0.45),
		]
		for corner in corners:
			if _asphalt_depth(p2 + corner) > -1.5:
				scrub_ok = false
				break
		if not scrub_ok:
			continue
		StreetKit.add_box(
			self,
			Vector3(scrub_w, 0.05, scrub_d),
			p2 + Vector3(0, 0.02, 0),
			_mat(col),
			false
		)
		n += 1
	return n


func _add_road_name_signs(roads: Array) -> int:
	## Verified OSM name or ref only. Highway class is not a name.
	_named_roads = []
	for road_v in roads:
		var road: Dictionary = road_v
		if str(road.get("name", "")).strip_edges().is_empty() and str(road.get("ref", "")).strip_edges().is_empty():
			continue
		_named_roads.append(road)
	add_to_group("dhule_roads")
	var signs := RoadLabels.bind(self, roads, data_buildings())
	var painted := RoadLabels.lay_on_asphalt(self, roads, road_y, spawn_position)
	print("ROAD names signs ", signs, " painted ", painted)
	return signs


func data_buildings() -> Array:
	return _buildings


func nearest_road_name(pos: Vector3) -> String:
	var best := ""
	var best_d := 14.0
	for road_v in _named_roads:
		var road: Dictionary = road_v
		var text := str(road.get("name", "")).strip_edges()
		if text.is_empty():
			text = str(road.get("ref", "")).strip_edges()
		if text.is_empty():
			continue
		var pts: Array = road.get("points", [])
		var half := float(road.get("width", 7.0)) * 0.5 + 3.0
		for i in pts.size() - 1:
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			var dist := _point_segment(Vector2(pos.x, pos.z), a, b)
			if dist < half and dist < best_d:
				best_d = dist
				best = text
	return best


func _point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var den := ab.length_squared()
	var t := 0.0 if den == 0.0 else clampf((p - a).dot(ab) / den, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	RoadLabels.update(cam.global_position, _delta)


func _add_junctions(_roads: Array) -> void:
	pass


func _add_roundabouts(roads: Array) -> void:
	var kerb := _mat(Color(0.72, 0.7, 0.64), 0.9)
	var fill := _mat(Color(0.34, 0.42, 0.28), 0.92)
	var n := RoadSurface.add_verified_roundabouts(self, roads, road_y, fill, kerb)
	print("ROAD roundabouts ", n)


func _build_road_strip(pts: Array, width: float, mat: Material, hw: String = "residential", road_id: String = "", y_lift: float = 0.0) -> void:
	RoadSurface.add_way(self, pts, width, road_y + y_lift, mat, _paint, hw)
	if _has_blosm or road_id.is_empty():
		return
	# Barriers stay off the carriageway. They are not a second road deck.
	var barrier_path := AssetKit.prop_path("barrier")
	if not AssetKit.exists(barrier_path):
		return
	if hw not in ["primary", "secondary", "trunk", "motorway", "tertiary"] or width < 8.0:
		return
	if pts.size() < 2:
		return
	var a: Array = pts[0]
	var b: Array = pts[mini(1, pts.size() - 1)]
	var along := Vector3(float(b[0]) - float(a[0]), 0, float(b[1]) - float(a[1]))
	if along.length() < 1.0:
		return
	along = along.normalized()
	var side := Vector3(-along.z, 0, along.x)
	var mid := Vector3(float(a[0]), 0, float(a[1])) + along * 6.0
	if _near_spawn(mid, 22.0):
		return
	var bn := AssetKit.place_at(self, barrier_path, _ground_pos(mid + side * (width * 0.5 + 1.65)), atan2(along.x, along.z), 1.0)
	if bn:
		_strip_physics(bn)


func _dress_spawn_street(_roads: Array, rng: RandomNumberGenerator) -> int:
	## First-camera frontage: mixed kit + procedural shops (not one repeated stall).
	if _has_blosm:
		return 0
	var n := 0
	var shop_path := AssetKit.building_path("bhelpuri")
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
			# Cart / procedural lamp on footpath only (no sidewalk GLB / no overscale light GLB)
			var foot := _off_carriageway(row_c, forward, side_sign, 5.5)
			if AssetKit.exists(shop_path) and i % 2 == 0 and not _near_road(foot, 5.0):
				var node := AssetKit.place_at(self, shop_path, foot, atan2(toward_road.x, toward_road.z), 1.0)
				if node:
					_strip_physics(node)
					n += 1
			var lp := _off_carriageway(row_c + forward * 2.0, forward, side_sign, 4.5)
			if _asphalt_depth(lp) < -0.4:
				StreetKit.lamp(self, lp)
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
	if _has_blosm:
		return 0
	var n := 0
	var forward := Vector3(spawn_heading.x, 0.0, spawn_heading.y).normalized()
	if forward.length() < 0.1:
		forward = Vector3(0, 0, -1)
	var right := Vector3(-forward.z, 0, forward.x)
	var shop_path := AssetKit.building_path("bhelpuri")

	var wt := _off_carriageway(spawn_position + forward * 55.0, forward, 1.0, 8.0)
	StreetKit.water_tower(self, wt)
	n += 1

	var junction_env := str(AssetKit.ENVIRONMENTS.get("dhule_junction", ""))
	if AssetKit.exists(junction_env):
		var jpos := _off_carriageway(Vector3(-180.0, 0, -95.0), Vector3(1, 0, 0), 1.0, 16.0)
		if not _near_road(jpos, 14.0) and not _near_spawn(jpos, 35.0):
			var jnode := AssetKit.place_at(self, junction_env, jpos, 0.0, 0.85)
			if jnode:
				_strip_physics(jnode)
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
				if _tree_site_ok(spot):
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
	n += _add_real_spots()
	return n


func _latlon_to_xz(lat: float, lon: float) -> Vector3:
	var lat_m := 6371000.0 * deg_to_rad(1.0)
	var lon_m := 6371000.0 * cos(deg_to_rad(20.902)) * deg_to_rad(1.0)
	return Vector3((lon - 74.777) * lon_m, 0.0, -(lat - 20.902) * lat_m)


func _add_real_spots() -> int:
	## Real Dhule places from OpenStreetMap coordinates. The statue mesh is original.
	var spots: Array[Dictionary] = [
		{"name": "Shivaji Maharaj, Fulwala Chowk", "lat": 20.90225, "lon": 74.77485, "kind": "statue"},
		{"name": "Jhansi Rani Chowk", "lat": 20.90615, "lon": 74.77490, "kind": "chowk"},
		{"name": "Panzara River Bridge", "lat": 20.90835, "lon": 74.77492, "kind": "bridge"},
		{"name": "Ekvira Devi Mandir", "lat": 20.90985, "lon": 74.77160, "kind": "temple"},
	]
	var statue_path := "res://assets/models/props/dhule_chowk_statue.glb"
	var n := 0
	for spot in spots:
		var pos := _latlon_to_xz(float(spot["lat"]), float(spot["lon"]))
		if _near_road(pos, 7.0):
			pos += Vector3(12.0, 0.0, 0.0)
			if _near_road(pos, 6.0):
				pos += Vector3(0.0, 0.0, 12.0)
		var kind := str(spot["kind"])
		var h := 6.0
		if kind == "statue" and AssetKit.exists(statue_path):
			var node := AssetKit.place_at(self, statue_path, pos, 0.0, 1.0)
			if node:
				_strip_physics(node)
				h = 11.0
		elif kind == "temple":
			h = BuildingKit.landmark(self, pos, str(spot["name"]), "temple", _pos_seed(pos))
		elif kind == "bridge":
			StreetKit.add_box(self, Vector3(8.0, 0.4, 3.0), pos + Vector3(0, 0.3, 0), StreetKit.mat(Color(0.75, 0.72, 0.62), 0.8), false)
			h = 4.0
		else:
			StreetKit.add_box(self, Vector3(6.0, 1.2, 6.0), pos + Vector3(0, 0.6, 0), StreetKit.mat(Color(0.55, 0.38, 0.22), 0.85), false)
			h = 3.0
		_add_name_label(str(spot["name"]), pos + Vector3(0, h + 1.4, 0))
		n += 1
	return n

func _add_flyovers(data: Dictionary) -> int:
	## Stored flyovers have kind and width only — no bridge tag — so they are not used
	## on the real city mesh. The decks sat 6 m up with no mapped structure.
	if _has_blosm:
		return 0
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


func _build_zebra_and_breakers(_pts: Array, _width: float, _rng: RandomNumberGenerator) -> void:
	## Random speed breakers are disabled. There is no mapped breaker location.
	return


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
