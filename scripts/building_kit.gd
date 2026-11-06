extends RefCounted
## Own Indian multi-storey facades — one ArrayMesh per OSM footprint (Phase 1B).
## Floors derive from plan area; shutters, signboards, balconies, bands, parapet, roof tanks.

const StreetKit = preload("res://scripts/street_kit.gd")

const WALLS: Array[Color] = [
	Color(0.93, 0.89, 0.80), # cream
	Color(0.88, 0.76, 0.52), # ochre
	Color(0.80, 0.86, 0.78), # mint
	Color(0.74, 0.82, 0.90), # sky
	Color(0.90, 0.78, 0.76), # rose
	Color(0.92, 0.92, 0.90), # white
	Color(0.78, 0.70, 0.60), # weathered tan
	Color(0.62, 0.68, 0.74), # grey-blue commercial
	Color(0.86, 0.80, 0.62), # pale yellow
]
const ACCENTS: Array[Color] = [
	Color(0.80, 0.22, 0.16),
	Color(0.12, 0.38, 0.62),
	Color(0.14, 0.50, 0.32),
	Color(0.90, 0.56, 0.12),
	Color(0.55, 0.20, 0.50),
	Color(0.20, 0.20, 0.22),
]
const GLASS := Color(0.26, 0.36, 0.46)
const DARK := Color(0.13, 0.13, 0.14)
const ROOF := Color(0.46, 0.44, 0.42)

## Dhule / Maharashtra shopfront signage bank (authentic Dhule business names
## in Roman script — renders on default Godot font, exactly how real Maharashtra signs appear).
const SIGN_WORDS: Array[String] = [
	"SHREE GANESH KIRANA",
	"OM SAI MEDICAL & MEDICO",
	"MAHESH CLOTH & SAREES",
	"DHULE AGRI SEVA KENDRA",
	"HOTEL SURUCHI PURE VEG",
	"LAXMI SARAF JEWELLERS",
	"BHARAT SWEET MART",
	"NEW BOMBAY HAIR SALOON",
	"KHANDESH MOTOR GARAGE",
	"DEOPUR BAKERY & CAFE",
	"SAI ELECTRONICS & MOBILE",
	"PHOOLWALA CHOWK HARDWARE",
	"SWAMI PHOTO STUDIO",
	"PANCHAVATI TAILORS",
	"AMUL MILK & ICE CREAM",
	"JAI BHAVANI CHAI & SNACKS",
	"VIVEKANAND OPTICALS",
	"SANCHETI BOOK DEPOT",
	"POOJA BARTAN BHANDAR",
	"APNA BAZAR SUPER MARKET",
	"EXIDE BATTERY HOUSE",
	"AMIT TYRES & ALIGNMENT",
	"MAHARASHTRA FERTILIZERS",
	"SHREEJI PLASTIC STORES",
	"TULSI AYURVEDIC AUSHADHI",
	"HOTEL ANNAPURNA THALI",
	"GANPATI JEWELLERS",
	"BALAJI ELECTRICALS",
	"KRISHNA GENERAL STORES",
	"SHREE RAM AUTOMOBILES",
	"ANAND SWEETS & FARSAN",
	"VISHAL FOOTWEAR",
	"KHANDESH TEA HOUSE",
	"SHIVAJI CHOWK MEDICAL",
	"ROYAL MENS WEAR",
	"MOHADI AGRI KENDRA",
	"DHULE COLD DRINKS",
	"SHRINATHJI DRY FRUITS",
	"MAULI HARDWARE & PAINTS",
	"JAI HIND BOOK CENTRE",
	"PATIL WATCH & EYEWEAR",
	"SAI KRUPA FRUIT STALL",
	"SHREE RADHE DAIRY",
	"VIJAY PAAN BHANDAR",
]
## Signboard fascia background colors (vibrant enamel tones: red, royal blue, emerald green, saffron orange, marigold yellow).
const SIGN_COLORS: Array[Color] = [
	Color(0.82, 0.14, 0.12), # vibrant red
	Color(0.12, 0.35, 0.75), # royal blue
	Color(0.12, 0.56, 0.28), # emerald green
	Color(0.92, 0.52, 0.08), # saffron orange
	Color(0.94, 0.78, 0.12), # marigold yellow
	Color(0.55, 0.14, 0.45), # deep magenta
	Color(0.18, 0.48, 0.58), # teal
]
## How many shopfront name labels the current map build may still place.
static var signature_budget: int = 0


class _Surf:
	var st := SurfaceTool.new()
	var count := 0
	var mat: Material

	func _init(m: Material) -> void:
		mat = m
		st.begin(Mesh.PRIMITIVE_TRIANGLES)


static func footprint(
	parent: Node3D,
	pos: Vector3,
	size_xz: Vector2,
	kind: String,
	seed: int,
	face_dir: Vector3 = Vector3(0, 0, 1),
	with_collision: bool = true
) -> float:
	## Builds a building at pos (bottom on pos.y) whose +Z front faces face_dir. Returns height.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var w := clampf(size_xz.x, 5.0, 32.0)
	var d := clampf(size_xz.y, 5.0, 32.0)
	var area := w * d
	var floors := 1
	if area < 70.0:
		floors = rng.randi_range(1, 2)
	elif area < 160.0:
		floors = rng.randi_range(2, 3)
	elif area < 400.0:
		floors = rng.randi_range(2, 4)
	else:
		floors = rng.randi_range(3, 5)
	var commercial := kind in ["commercial", "retail", "shop"] or rng.randf() < 0.32
	if commercial and floors < 4 and rng.randf() < 0.5:
		floors += 1
	var ground_h := 3.6 if commercial else 3.1
	var floor_h := 3.0
	var h := ground_h + float(floors - 1) * floor_h

	var wall_c: Color = WALLS[rng.randi_range(0, WALLS.size() - 1)]
	var accent_c: Color = ACCENTS[rng.randi_range(0, ACCENTS.size() - 1)]
	# A shopfront name on some commercial fronts — reads as a real Dhule high-street.
	var sign_text := ""
	if commercial and signature_budget > 0 and rng.randf() < 0.88:
		signature_budget -= 1
		sign_text = SIGN_WORDS[rng.randi() % SIGN_WORDS.size()]
	_build(parent, pos, face_dir, w, d, h, floors, ground_h, floor_h, commercial, wall_c, accent_c, rng, sign_text, with_collision)
	return h


static func landmark(parent: Node3D, pos: Vector3, poi_name: String, kind: String, seed: int, face_dir: Vector3 = Vector3(0, 0, 1)) -> float:
	## Named civic building (hospital / school / temple / bank / default). Returns height.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var w := rng.randf_range(16.0, 24.0)
	var d := rng.randf_range(12.0, 18.0)
	var floors := 4
	var wall_c := Color(0.94, 0.94, 0.92)
	var accent_c := Color(0.82, 0.16, 0.14)
	match kind:
		"hospital", "clinic", "doctors":
			wall_c = Color(0.95, 0.96, 0.95)
			accent_c = Color(0.85, 0.15, 0.15)
			floors = rng.randi_range(4, 5)
		"school", "college", "university":
			wall_c = Color(0.92, 0.84, 0.56)
			accent_c = Color(0.45, 0.28, 0.16)
			floors = 3
			w = rng.randf_range(26.0, 34.0)
		"place_of_worship", "temple":
			wall_c = Color(0.95, 0.90, 0.78)
			accent_c = Color(0.92, 0.55, 0.12)
			floors = 2
			w = 14.0
			d = 14.0
		"bank", "atm":
			wall_c = Color(0.68, 0.72, 0.78)
			accent_c = Color(0.12, 0.30, 0.55)
			floors = 3
		"government", "courthouse":
			wall_c = Color(0.90, 0.88, 0.82)
			accent_c = Color(0.16, 0.28, 0.44)
			floors = 3
			w = rng.randf_range(26.0, 34.0)
		_:
			floors = rng.randi_range(3, 4)
	var ground_h := 3.8
	var floor_h := 3.2
	var h := ground_h + float(floors - 1) * floor_h
	var node := _build(parent, pos, face_dir, w, d, h, floors, ground_h, floor_h, true, wall_c, accent_c, rng, poi_name, true)
	if kind in ["place_of_worship", "temple"] and node:
		# Stacked shikhara on roof (stylized)
		var tiers := [Vector3(5.0, 2.2, 5.0), Vector3(3.6, 2.0, 3.6), Vector3(2.2, 1.8, 2.2), Vector3(1.0, 1.4, 1.0)]
		var y := h
		for t in tiers:
			var ts: Vector3 = t
			StreetKit.add_box(node, ts, Vector3(0, y + ts.y * 0.5, 0), StreetKit.mat(accent_c, 0.8), false)
			y += ts.y
	if node == null:
		return h
	# Per-kind civic detailing — reads as Dhule's real hospitals, bus stand, market, colleges.
	match kind:
		"hospital", "clinic", "doctors":
			var cross := StreetKit.mat(Color(0.88, 0.12, 0.12), 0.7)
			var cy := h + 1.3
			var cf := d * 0.5 + 0.08
			StreetKit.add_box(node, Vector3(1.9, 0.55, 0.14), Vector3(0, cy, cf), cross, false)
			StreetKit.add_box(node, Vector3(0.55, 1.9, 0.14), Vector3(0, cy, cf), cross, false)
		"bus_station":
			var canopy := StreetKit.mat(Color(0.86, 0.76, 0.36), 0.8)
			StreetKit.add_box(node, Vector3(w + 3.0, 0.22, 4.6), Vector3(0, 3.7, d * 0.5 + 2.4), canopy, false)
			for sx in [-1.0, 1.0]:
				StreetKit.add_box(node, Vector3(0.26, 3.7, 0.26), Vector3(sx * (w * 0.5), 1.85, d * 0.5 + 4.3), canopy, false)
		"marketplace", "retail":
			var canopy2 := StreetKit.mat(Color(0.72, 0.2, 0.18), 0.8)
			StreetKit.add_box(node, Vector3(w + 4.0, 0.18, 5.0), Vector3(0, 3.5, d * 0.5 + 2.6), canopy2, false)
			for sx in [-1.0, 1.0]:
				StreetKit.add_box(node, Vector3(0.24, 3.5, 0.24), Vector3(sx * (w * 0.5 + 1.6), 1.75, d * 0.5 + 4.6), canopy2, false)
		"school", "college", "university":
			var gate := StreetKit.mat(Color(0.55, 0.35, 0.2), 0.85)
			for sx in [-1.0, 1.0]:
				StreetKit.add_box(node, Vector3(0.8, 4.2, 0.8), Vector3(sx * 3.2, 2.1, d * 0.5 + 3.0), gate, false)
			StreetKit.add_box(node, Vector3(7.2, 0.7, 0.7), Vector3(0, 4.2, d * 0.5 + 3.0), gate, false)
		"government", "courthouse":
			var portico := StreetKit.mat(Color(0.88, 0.86, 0.82), 0.85)
			StreetKit.add_box(node, Vector3(10.0, 0.35, 3.8), Vector3(0, 4.2, d * 0.5 + 2.0), portico, false)
			for col_x in [-4.0, -1.33, 1.33, 4.0]:
				StreetKit.add_box(node, Vector3(0.45, 4.2, 0.45), Vector3(col_x, 2.1, d * 0.5 + 3.6), portico, false)
	return h


static func _build(
	parent: Node3D,
	pos: Vector3,
	face_dir: Vector3,
	w: float,
	d: float,
	h: float,
	floors: int,
	ground_h: float,
	floor_h: float,
	commercial: bool,
	wall_c: Color,
	accent_c: Color,
	rng: RandomNumberGenerator,
	sign_text: String,
	with_collision: bool = true
) -> MeshInstance3D:
	var wall := _Surf.new(StreetKit.mat(wall_c, 0.92))
	var trim := _Surf.new(StreetKit.mat(wall_c.darkened(0.28), 0.9))
	# Glass tint drifts toward the wall tone so no two facades read identical.
	var glass_c := GLASS.lerp(wall_c.darkened(0.15), rng.randf_range(0.0, 0.3))
	var glass := _Surf.new(StreetKit.mat(glass_c, 0.18, 0.35))
	var accent := _Surf.new(StreetKit.mat(accent_c, 0.75))
	var dark := _Surf.new(StreetKit.mat(DARK, 0.85))
	var roof := _Surf.new(StreetKit.mat(ROOF, 0.95))
	# Vibrant Dhule enamel signboard background
	var sign_col: Color = SIGN_COLORS[rng.randi() % SIGN_COLORS.size()]
	var sign_surf := _Surf.new(StreetKit.mat(sign_col, 0.42, 0.1))
	# Metallic rolling shutter material
	var shutter_c := Color(0.46, 0.52, 0.56) if rng.randf() < 0.6 else accent_c.darkened(0.35)
	var shutter := _Surf.new(StreetKit.mat(shutter_c, 0.52, 0.35))

	# Body (bottom at y=0)
	_box(wall, Vector3(0, h * 0.5, 0), Vector3(w, h, d))
	# Plinth
	_box(trim, Vector3(0, 0.22, 0), Vector3(w + 0.16, 0.44, d + 0.16))
	# Floor bands
	for f in range(1, floors):
		var y := ground_h + float(f - 1) * floor_h
		_box(trim, Vector3(0, y, 0), Vector3(w + 0.14, 0.2, d + 0.14))
	# Roof slab + parapet ring
	_box(roof, Vector3(0, h + 0.04, 0), Vector3(w - 0.3, 0.08, d - 0.3))
	# Projecting concrete cornice just below the parapet — reads as a real slab edge.
	_box(trim, Vector3(0, h + 0.24, 0), Vector3(w + 0.22, 0.4, d + 0.22))
	var par_h := 0.75
	_box(trim, Vector3(0, h + par_h * 0.5, d * 0.5 - 0.1), Vector3(w + 0.1, par_h, 0.2))
	_box(trim, Vector3(0, h + par_h * 0.5, -d * 0.5 + 0.1), Vector3(w + 0.1, par_h, 0.2))
	_box(trim, Vector3(w * 0.5 - 0.1, h + par_h * 0.5, 0), Vector3(0.2, par_h, d - 0.2))
	_box(trim, Vector3(-w * 0.5 + 0.1, h + par_h * 0.5, 0), Vector3(0.2, par_h, d - 0.2))
	# Roof props: Sintex-style cylindrical water tank(s), stair head
	var tank_x := rng.randf_range(-w * 0.32, w * 0.32)
	var tank_z := rng.randf_range(-d * 0.32, d * 0.32)
	_box(dark, Vector3(tank_x, h + 0.7, tank_z), Vector3(1.2, 1.4, 1.2))
	_box(dark, Vector3(tank_x, h + 1.45, tank_z), Vector3(0.7, 0.12, 0.7))
	if rng.randf() < 0.5:
		_box(dark, Vector3(-tank_x * 0.8, h + 0.6, -tank_z * 0.8), Vector3(1.0, 1.2, 1.0))
	if w > 8.0 and d > 8.0 and rng.randf() < 0.7:
		_box(wall, Vector3(-w * 0.5 + 1.6, h + 1.15, -d * 0.5 + 1.6), Vector3(2.4, 2.3, 2.4))

	# Windows on 4 faces
	var faces := [
		[Vector3(0, 0, 1), w],
		[Vector3(0, 0, -1), w],
		[Vector3(1, 0, 0), d],
		[Vector3(-1, 0, 0), d],
	]
	var residential := not commercial
	for fi in faces.size():
		var fn: Vector3 = faces[fi][0]
		var face_len: float = faces[fi][1]
		var is_front := fi == 0
		var cols := maxi(1, int(face_len / 3.1))
		var spacing := face_len / float(cols)
		var start_floor := 1 if (is_front and commercial) else 0
		for f in range(start_floor, floors):
			var yc := (ground_h * 0.5 + 0.2) if f == 0 else (ground_h + (float(f - 1) + 0.5) * floor_h)
			for c in cols:
				var along := -face_len * 0.5 + spacing * (float(c) + 0.5)
				if is_front and f == 0 and c == int(cols / 2.0):
					continue # door slot
				var along_v := Vector3(along, 0, 0) if absf(fn.z) > 0.5 else Vector3(0, 0, along)
				var half := (d * 0.5) if absf(fn.z) > 0.5 else (w * 0.5)
				var center := along_v + fn * (half + 0.03) + Vector3(0, yc, 0)
				var win_size := Vector3(1.15, 1.35, 0.06) if absf(fn.z) > 0.5 else Vector3(0.06, 1.35, 1.15)
				var frame_size := win_size + (Vector3(0.22, 0.22, 0.0) if absf(fn.z) > 0.5 else Vector3(0.0, 0.22, 0.22))
				_box(trim, center - fn * 0.015, frame_size)
				_box(glass, center, win_size)
				# Projecting window sill (chhajja-style ledge) under every window.
				var sill_size := Vector3(win_size.x + 0.3, 0.09, 0.22) if absf(fn.z) > 0.5 else Vector3(0.22, 0.09, win_size.z + 0.3)
				_box(trim, center + fn * 0.06 + Vector3(0, -win_size.y * 0.5 - 0.05, 0), sill_size)
				# Balcony on front/back for upper floors, every other column
				if f >= 1 and absf(fn.z) > 0.5 and c % 2 == 0 and rng.randf() < 0.65:
					var by := yc - 0.75
					var slab_c := along_v + fn * (half + 0.55) + Vector3(0, by, 0)
					_box(wall, slab_c, Vector3(spacing * 0.86, 0.14, 1.1))
					_box(accent, slab_c + fn * 0.5 + Vector3(0, 0.5, 0), Vector3(spacing * 0.86, 0.9, 0.08))
				# Desert air cooler (iconic Khandesh/Dhule house cooling box)
				elif f >= 1 and rng.randf() < 0.25:
					var cooler_s := Vector3(0.75, 0.75, 0.65) if absf(fn.z) > 0.5 else Vector3(0.65, 0.75, 0.75)
					_box(trim, center + fn * 0.38 + Vector3(0, -win_size.y * 0.25, 0), cooler_s)
					var grill_s := Vector3(0.62, 0.62, 0.03) if absf(fn.z) > 0.5 else Vector3(0.03, 0.62, 0.62)
					_box(dark, center + fn * 0.72 + Vector3(0, -win_size.y * 0.25, 0), grill_s)
				# AC outdoor unit occasionally
				elif f >= 1 and rng.randf() < 0.12:
					_box(dark, center + fn * 0.3 + Vector3(0, -0.95, 0), Vector3(0.6, 0.45, 0.5) if absf(fn.z) > 0.5 else Vector3(0.5, 0.45, 0.6))

	# Ground floor front: shutters + signboard (commercial) or door + porch (residential)
	var front_half := d * 0.5
	if commercial:
		var cols := maxi(2, int(w / 3.4))
		var spacing := w / float(cols)
		# Plinth step in front of shops
		_box(trim, Vector3(0, 0.12, front_half + 0.42), Vector3(w * 0.94, 0.24, 0.84))
		for c in cols:
			var x := -w * 0.5 + spacing * (float(c) + 0.5)
			var open := rng.randf() < 0.45
			var sh_h := 1.2 if open else 2.7
			var sh_y := (ground_h - 0.6) - sh_h * 0.5 if open else 1.45
			_box(shutter, Vector3(x, sh_y, front_half + 0.05), Vector3(spacing * 0.84, sh_h, 0.08))
			# Shutter horizontal corrugation ribs
			for rib in range(1, 4):
				var ry := sh_y - sh_h * 0.5 + float(rib) * (sh_h / 4.0)
				_box(trim, Vector3(x, ry, front_half + 0.095), Vector3(spacing * 0.85, 0.04, 0.02))
			if open:
				# Dark interior opening below rolled shutter
				_box(dark, Vector3(x, (ground_h - 0.6 - sh_h) * 0.5, front_half + 0.01), Vector3(spacing * 0.78, ground_h - 0.6 - sh_h, 0.02))
		# Vibrant Dhule Signboard strip above shutters
		var sign_h := 0.82
		var sign_y := ground_h - 0.42
		_box(sign_surf, Vector3(0, sign_y, front_half + 0.14), Vector3(w * 0.96, sign_h, 0.12))
		# Inner trim border around signboard
		_box(trim, Vector3(0, sign_y, front_half + 0.21), Vector3(w * 0.93, sign_h * 0.88, 0.02))
		# Awning (slanted shop sunshade canopy)
		if rng.randf() < 0.65:
			_box(accent, Vector3(0, ground_h - 0.86, front_half + 0.82), Vector3(w * 0.94, 0.06, 1.45))
			_box(trim, Vector3(-w * 0.45, (ground_h - 0.86) * 0.5, front_half + 1.42), Vector3(0.06, ground_h - 0.86, 0.06))
			_box(trim, Vector3(w * 0.45, (ground_h - 0.86) * 0.5, front_half + 1.42), Vector3(0.06, ground_h - 0.86, 0.06))
	else:
		_box(dark, Vector3(0, 1.05, front_half + 0.03), Vector3(1.0, 2.1, 0.06))
		_box(trim, Vector3(0, 0.08, front_half + 0.9), Vector3(2.6, 0.16, 1.8))
		if rng.randf() < 0.5:
			_box(accent, Vector3(0, 2.45, front_half + 0.55), Vector3(2.4, 0.08, 1.1))

	# Compose mesh
	var mesh := ArrayMesh.new()
	var idx := 0
	for s in [wall, trim, glass, accent, dark, roof, sign_surf, shutter]:
		var surf: _Surf = s
		if surf.count == 0:
			continue
		surf.st.generate_normals()
		surf.st.commit(mesh)
		mesh.surface_set_material(idx, surf.mat)
		idx += 1

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	# Mesh local bottom is y=0 — pin to ground (pos.y), never float
	mi.position = Vector3(pos.x, pos.y, pos.z)
	mi.rotation.y = atan2(face_dir.x, face_dir.z)
	parent.add_child(mi)

	# Outer Ring 1 footprints stay visual-only to keep StaticBody count down
	if with_collision:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(w, h, d)
		col.shape = shape
		col.position = Vector3(0, h * 0.5, 0)
		body.add_child(col)
		mi.add_child(body)

	if sign_text != "":
		var label := Label3D.new()
		label.text = sign_text
		label.font_size = 46
		label.pixel_size = 0.012
		label.modulate = Color(1.0, 0.98, 0.88)
		label.outline_modulate = Color(0.05, 0.05, 0.05)
		label.outline_size = 10
		label.position = Vector3(0, ground_h - 0.42, front_half + 0.28)
		mi.add_child(label)
	return mi


static func _box(s: _Surf, c: Vector3, size: Vector3) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var p0 := c + Vector3(-hx, -hy, -hz)
	var p1 := c + Vector3(hx, -hy, -hz)
	var p2 := c + Vector3(hx, hy, -hz)
	var p3 := c + Vector3(-hx, hy, -hz)
	var p4 := c + Vector3(-hx, -hy, hz)
	var p5 := c + Vector3(hx, -hy, hz)
	var p6 := c + Vector3(hx, hy, hz)
	var p7 := c + Vector3(-hx, hy, hz)
	_quad(s, p4, p5, p6, p7, Vector3(0, 0, 1))
	_quad(s, p1, p0, p3, p2, Vector3(0, 0, -1))
	_quad(s, p5, p1, p2, p6, Vector3(1, 0, 0))
	_quad(s, p0, p4, p7, p3, Vector3(-1, 0, 0))
	_quad(s, p7, p6, p2, p3, Vector3(0, 1, 0))
	_quad(s, p0, p1, p5, p4, Vector3(0, -1, 0))


static func _quad(s: _Surf, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	var cross := (b - a).cross(c - a)
	if cross.dot(n) < 0.0:
		var tmp := b
		b = d
		d = tmp
	var st := s.st
	st.set_normal(n)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(b)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(d)
	s.count += 6
