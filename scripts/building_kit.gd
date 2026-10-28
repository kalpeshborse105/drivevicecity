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
	face_dir: Vector3 = Vector3(0, 0, 1)
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
	_build(parent, pos, face_dir, w, d, h, floors, ground_h, floor_h, commercial, wall_c, accent_c, rng, "")
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
		_:
			floors = rng.randi_range(3, 4)
	var ground_h := 3.8
	var floor_h := 3.2
	var h := ground_h + float(floors - 1) * floor_h
	var node := _build(parent, pos, face_dir, w, d, h, floors, ground_h, floor_h, true, wall_c, accent_c, rng, poi_name)
	if kind in ["place_of_worship", "temple"] and node:
		# Stacked shikhara on roof (stylized)
		var tiers := [Vector3(5.0, 2.2, 5.0), Vector3(3.6, 2.0, 3.6), Vector3(2.2, 1.8, 2.2), Vector3(1.0, 1.4, 1.0)]
		var y := h
		for t in tiers:
			var ts: Vector3 = t
			StreetKit.add_box(node, ts, Vector3(0, y + ts.y * 0.5, 0), StreetKit.mat(accent_c, 0.8), false)
			y += ts.y
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
	sign_text: String
) -> MeshInstance3D:
	var wall := _Surf.new(StreetKit.mat(wall_c, 0.92))
	var trim := _Surf.new(StreetKit.mat(wall_c.darkened(0.28), 0.9))
	var glass := _Surf.new(StreetKit.mat(GLASS, 0.18, 0.35))
	var accent := _Surf.new(StreetKit.mat(accent_c, 0.75))
	var dark := _Surf.new(StreetKit.mat(DARK, 0.85))
	var roof := _Surf.new(StreetKit.mat(ROOF, 0.95))

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
	var par_h := 0.75
	_box(trim, Vector3(0, h + par_h * 0.5, d * 0.5 - 0.1), Vector3(w + 0.1, par_h, 0.2))
	_box(trim, Vector3(0, h + par_h * 0.5, -d * 0.5 + 0.1), Vector3(w + 0.1, par_h, 0.2))
	_box(trim, Vector3(w * 0.5 - 0.1, h + par_h * 0.5, 0), Vector3(0.2, par_h, d - 0.2))
	_box(trim, Vector3(-w * 0.5 + 0.1, h + par_h * 0.5, 0), Vector3(0.2, par_h, d - 0.2))
	# Roof props: water tank(s), stair head
	var tank_x := rng.randf_range(-w * 0.35, w * 0.35)
	var tank_z := rng.randf_range(-d * 0.35, d * 0.35)
	_box(dark, Vector3(tank_x, h + 0.65, tank_z), Vector3(1.0, 1.2, 1.0))
	if rng.randf() < 0.5:
		_box(dark, Vector3(-tank_x * 0.8, h + 0.6, -tank_z * 0.8), Vector3(0.9, 1.1, 0.9))
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
				# Balcony on front/back for residential upper floors, every other column
				if residential and f >= 1 and absf(fn.z) > 0.5 and c % 2 == 0 and rng.randf() < 0.7:
					var by := yc - 0.75
					var slab_c := along_v + fn * (half + 0.55) + Vector3(0, by, 0)
					_box(wall, slab_c, Vector3(spacing * 0.86, 0.14, 1.1))
					_box(accent, slab_c + fn * 0.5 + Vector3(0, 0.5, 0), Vector3(spacing * 0.86, 0.9, 0.08))
				# AC unit occasionally
				if f >= 1 and rng.randf() < 0.12:
					_box(dark, center + fn * 0.3 + Vector3(0, -0.95, 0), Vector3(0.6, 0.45, 0.5) if absf(fn.z) > 0.5 else Vector3(0.5, 0.45, 0.6))

	# Ground floor front: shutters + signboard (commercial) or door + porch (residential)
	var front_half := d * 0.5
	if commercial:
		var cols := maxi(2, int(w / 3.4))
		var spacing := w / float(cols)
		for c in cols:
			var x := -w * 0.5 + spacing * (float(c) + 0.5)
			var open := rng.randf() < 0.45
			var sh_h := 1.2 if open else 2.7
			var sh_y := (ground_h - 0.6) - sh_h * 0.5 if open else 1.45
			var surf := accent if (c % 2 == 0) else dark
			_box(surf, Vector3(x, sh_y, front_half + 0.04), Vector3(spacing * 0.82, sh_h, 0.07))
			if open:
				# Dark interior opening below rolled shutter
				_box(dark, Vector3(x, (ground_h - 0.6 - sh_h) * 0.5, front_half + 0.01), Vector3(spacing * 0.78, ground_h - 0.6 - sh_h, 0.02))
		# Signboard strip above shutters
		_box(accent, Vector3(0, ground_h - 0.3, front_half + 0.12), Vector3(w * 0.96, 0.62, 0.12))
		_box(wall, Vector3(0, ground_h - 0.3, front_half + 0.19), Vector3(w * 0.5, 0.26, 0.02))
		# Awning
		if rng.randf() < 0.6:
			_box(accent, Vector3(0, ground_h - 0.72, front_half + 0.7), Vector3(w * 0.9, 0.06, 1.3))
	else:
		_box(dark, Vector3(0, 1.05, front_half + 0.03), Vector3(1.0, 2.1, 0.06))
		_box(trim, Vector3(0, 0.08, front_half + 0.9), Vector3(2.6, 0.16, 1.8))
		if rng.randf() < 0.5:
			_box(accent, Vector3(0, 2.45, front_half + 0.55), Vector3(2.4, 0.08, 1.1))

	# Compose mesh
	var mesh := ArrayMesh.new()
	var idx := 0
	for s in [wall, trim, glass, accent, dark, roof]:
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
		label.font_size = 40
		label.pixel_size = 0.012
		label.modulate = Color(0.98, 0.97, 0.92)
		label.outline_modulate = Color(0.1, 0.1, 0.1)
		label.outline_size = 8
		label.position = Vector3(0, ground_h - 0.3, front_half + 0.26)
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
