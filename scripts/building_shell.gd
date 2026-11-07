extends RefCounted
## Extrudes a real OSM footprint. The ring stays the ground plan.
## Cottage, family, row, shop, commercial and apartment change height,
## openings and roof details. Shop boards stay blank. No name is generated.


const PARTY_M := 2.05
## Restrained Maharashtra residential plaster — not candy pastels.
const PLASTER: Array[Color] = [
	Color(0.94, 0.91, 0.84),
	Color(0.90, 0.84, 0.72),
	Color(0.88, 0.82, 0.64),
	Color(0.91, 0.78, 0.68),
	Color(0.82, 0.72, 0.66),
	Color(0.78, 0.76, 0.72),
	Color(0.70, 0.68, 0.64),
	Color(0.86, 0.80, 0.76),
	Color(0.76, 0.70, 0.62),
	Color(0.84, 0.86, 0.82),
]
const BRICK := Color(0.52, 0.34, 0.28)
const STONE := Color(0.58, 0.54, 0.48)
const CONCRETE := Color(0.62, 0.60, 0.57)


static func add_neighbourhood(parent: Node3D, specs: Array, _party: Array) -> Dictionary:
	## Seven shared mats keep the neighbourhood as one MeshInstance3D.
	var plaster := _mat(Color.WHITE, 0.9, true)
	plaster.metallic = 0.0
	var roof_m := _mat(Color.WHITE, 0.96, true)
	roof_m.metallic = 0.02
	# Opaque glass — alpha glass washed out against plaster in Forward+.
	var glass := _mat(Color.WHITE, 0.32, true)
	glass.metallic = 0.18
	var dark := _mat(Color.WHITE, 0.78, true)
	dark.metallic = 0.05
	var metal := _mat(Color.WHITE, 0.42, true)
	metal.metallic = 0.55
	var brick := _mat(Color.WHITE, 0.94, true)
	var lamp := _mat(Color(1.0, 0.84, 0.55), 0.45, false)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.72, 0.38)
	lamp.emission_energy = 1.15
	var tools := {
		"plaster": _tool(plaster),
		"roof": _tool(roof_m),
		"glass": _tool(glass),
		"dark": _tool(dark),
		"metal": _tool(metal),
		"brick": _tool(brick),
		"lamp": _tool(lamp),
		"col": PackedVector3Array(),
	}
	var root := Node3D.new()
	root.name = "Chunk_spawn"
	parent.add_child(root)
	var bodies := 0
	var ids: Array[String] = []
	for spec_v in specs:
		var spec: Dictionary = spec_v
		var poly: PackedVector2Array = spec["poly"]
		if poly.size() < 3:
			continue
		var id := str(spec["id"])
		var floors: int = int(spec["floors"])
		var style := _style(str(spec.get("style", "family")))
		var front: int = int(spec.get("front", 0))
		var front_clear: float = float(spec.get("front_clear", 4.0))
		var tint: Color = PLASTER[absi(hash(id)) % PLASTER.size()]
		var height := _height(style, floors)
		_extrude(tools, poly, id, style, floors, height, front, front_clear, tint, specs)
		_body(root, id, poly, height)
		ids.append(id)
		bodies += 1
	var walls := _compound(tools, specs)
	var mesh := ArrayMesh.new()
	var surfaces := 0
	for key in ["plaster", "roof", "glass", "dark", "metal", "brick", "lamp"]:
		var pair: Array = tools[key]
		var st: SurfaceTool = pair[0]
		if int(pair[1]) == 0:
			continue
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(surfaces, pair[2])
		surfaces += 1
	var visual := MeshInstance3D.new()
	visual.name = "Shell"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	visual.set_meta("osm_ids", ids)
	root.add_child(visual)
	var col: PackedVector3Array = tools["col"]
	if col.size() >= 12:
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(col)
		var yard := StaticBody3D.new()
		yard.name = "hit_yard"
		var yard_col := CollisionShape3D.new()
		yard_col.shape = shape
		yard.add_child(yard_col)
		root.add_child(yard)
	return {"buildings": bodies, "surfaces": surfaces, "ids": ids, "walls": walls}


static func _style(style: String) -> String:
	## Prototype A/B/C keys map to shell families. Shop/civic only when tags say so.
	if style == "compact" or style == "traditional_compact" or style == "plastered_compact":
		return "cottage"
	if style == "urban" or style == "plastered_house":
		return "family"
	if style == "narrow_urban":
		return "row"
	if style == "mixed":
		return "shop"
	return style


static func _height(style: String, floors: int) -> float:
	var storeys := maxi(floors, 1)
	if style == "cottage" or (style == "row" and storeys <= 1):
		return 3.15
	if style == "shop":
		return 3.45 + float(maxi(storeys - 1, 0)) * 2.85
	if style == "commercial":
		return 3.7 + float(maxi(storeys - 1, 0)) * 3.05
	if style == "apartment":
		return 3.15 * float(storeys)
	if storeys <= 1:
		return 3.15
	return 3.2 + 2.9 * float(storeys - 1)


static func _extrude(
	tools: Dictionary,
	poly: PackedVector2Array,
	id: String,
	style: String,
	floors: int,
	height: float,
	front: int,
	front_clear: float,
	tint: Color,
	specs: Array
) -> void:
	var plaster: Array = tools["plaster"]
	var roof: Array = tools["roof"]
	var glass: Array = tools["glass"]
	var dark: Array = tools["dark"]
	var metal: Array = tools["metal"]
	var brick: Array = tools["brick"]
	var lamp: Array = tools["lamp"]
	## Stable per-OSM variation — same id always same facade recipe.
	var seed := absi(hash(id))
	var variant := seed % 7
	var facade := seed % 4
	var entrance := seed % 3
	var n := poly.size()
	var ground_h := 3.15
	if style == "shop":
		ground_h = 3.45
	elif style == "commercial":
		ground_h = 3.7
	var upper_h := 2.9
	var parapet := 0.36
	if style == "cottage":
		parapet = 0.28 + float(variant % 3) * 0.1
	elif style == "row":
		parapet = 0.38 + float(variant % 2) * 0.12
	elif style == "family":
		parapet = 0.52 + float(variant % 3) * 0.14
	elif style == "apartment":
		parapet = 0.82
	elif style == "commercial":
		parapet = 0.58
	var plinth_h := 0.38 + float(variant % 3) * 0.06
	var stone_plinth := facade != 2
	var lip := height + parapet
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var edge := b - a
		var length := edge.length()
		if length < 0.15:
			continue
		var outward := Vector2(-edge.y, edge.x) / length
		var shared := i != front and _party(a, b, id, specs)
		var trim := tint.darkened(0.14)
		var thick := 0.28
		var ia := a - outward * thick
		var ib := b - outward * thick
		# Plinth / stone course.
		if stone_plinth:
			_wall(brick, a, b, 0.0, plinth_h, outward, STONE if facade == 1 else BRICK)
		else:
			_wall(plaster, a, b, 0.0, plinth_h, outward, trim.darkened(0.08))
		_wall(plaster, a, b, plinth_h, height, outward, tint)
		# Parapet face + coping strip.
		var cap_col := CONCRETE if facade == 0 else trim
		_wall(plaster, a, b, height, lip, outward, cap_col)
		_wall(plaster, a + outward * 0.04, b + outward * 0.04, lip - 0.06, lip + 0.04, outward, CONCRETE)
		_wall(plaster, ib, ia, 0.0, lip, -outward, tint.darkened(0.06))
		_horiz(roof, a, ia, ib, b, lip, Vector3.UP, CONCRETE.darkened(0.05))
		_box(plaster, Vector3(a.x, lip * 0.5, a.y), Vector3(thick, lip, thick), tint)
		if floors >= 2:
			_band(plaster, a, b, ground_h, outward, trim)
			_band(plaster, a, b, ground_h - 0.12, outward, CONCRETE) # floor slab lip
		if style == "apartment" and floors >= 3:
			_band(plaster, a, b, ground_h + upper_h, outward, trim)
		var road_face := i == front
		var shop_front := road_face and style in ["shop", "commercial"]
		# Shell `outward` points into the footprint (CCW left). Facade details must
		# sit on the exterior skin (ia/ib) facing the street (-outward).
		var ext := -outward
		var ea := ia
		var eb := ib
		if shop_front:
			_shutter(metal, plaster, ea, eb, ext, ground_h, tint)
			_awning(plaster, metal, ea, eb, ext, ground_h - 0.2, tint)
			_steps(plaster, tools, ea, eb, ext, front_clear, trim)
			_lamp(lamp, ea, eb, ext)
			if floors >= 2 and not shared:
				_windows(glass, plaster, dark, metal, ea, eb, ext, floors, ground_h, upper_h, false, tint, variant, style, facade, 1)
		elif road_face and length > 1.8:
			_door(dark, plaster, ea, eb, ext, style, variant, entrance)
			_steps(plaster, tools, ea, eb, ext, front_clear, trim)
			_lamp(lamp, ea, eb, ext)
		if not shared and not shop_front and length > 2.2:
			_windows(glass, plaster, dark, metal, ea, eb, ext, floors, ground_h, upper_h, road_face, tint, variant, style, facade, 0)
		# Compact balcony on suitable family / narrow fronts.
		var balcony := (
			not shared
			and floors >= 2
			and length > 3.6
			and front_clear > 1.8
			and road_face
			and (
				(style == "family" and variant % 2 == 0)
				or (style == "row" and facade != 3 and length > 3.8)
				or style == "apartment"
			)
		)
		if balcony:
			_balcony(plaster, metal, dark, ea, eb, ext, ground_h, tint, variant)
		# Front cornice / RCC slab overhang.
		if road_face and not shared and length > 2.0:
			_overhang(plaster, ea, eb, ext, height, tint, style)
		# Parapet posts on longer fronts.
		if road_face and length > 4.0 and style != "cottage":
			_parapet_posts(plaster, ea, eb, ext, lip, CONCRETE, variant)
	_roof(roof, poly, height)
	var want_tank := (
		style in ["family", "commercial", "apartment", "shop"]
		or (style == "row" and floors >= 2 and variant % 2 == 0)
		or (style == "cottage" and variant % 3 == 0 and _area(poly) >= 55.0)
	)
	if want_tank:
		_tank(metal, poly, height, seed, 0.82 if style == "row" or style == "cottage" else 1.02)
	if style == "apartment" or _area(poly) >= 180.0:
		_stair(plaster, poly, height, tint)


static func _wall(pair: Array, a: Vector2, b: Vector2, y0: float, y1: float, outward: Vector2, col: Color) -> void:
	var n := Vector3(outward.x, 0.0, outward.y)
	var a0 := Vector3(a.x, y0, a.y)
	var a1 := Vector3(a.x, y1, a.y)
	var b1 := Vector3(b.x, y1, b.y)
	var b0 := Vector3(b.x, y0, b.y)
	_quad(pair, a0, a1, b1, b0, n, col)


static func _band(pair: Array, a: Vector2, b: Vector2, y: float, outward: Vector2, col: Color) -> void:
	var s: Vector2 = outward * 0.04
	_wall(pair, a + s, b + s, y - 0.07, y + 0.08, outward, col)


static func _door(
	dark: Array,
	plaster: Array,
	a: Vector2,
	b: Vector2,
	outward: Vector2,
	style: String,
	variant: int,
	entrance: int
) -> void:
	var along := (b - a).normalized()
	var mid := (a + b) * 0.5 + outward * 0.04
	var half_w := 0.36 if style == "row" or style == "cottage" else 0.48
	if entrance == 1:
		half_w *= 1.15 # wider family entrance
	var top := 2.0 if style == "cottage" else 2.16
	var wood := Color(0.42, 0.26, 0.16) if variant % 2 == 0 else Color(0.34, 0.20, 0.12)
	var steel := Color(0.28, 0.30, 0.32)
	var leaf := steel if entrance == 2 else wood
	var frame := Color(0.48, 0.46, 0.42)
	# Proud concrete surround, recessed leaf.
	_wall(plaster, mid - along * (half_w + 0.12), mid + along * (half_w + 0.12), 0.02, top + 0.14, outward, frame)
	_wall(dark, mid - along * half_w + outward * 0.03, mid + along * half_w + outward * 0.03, 0.08, top, outward, leaf)
	if entrance == 2:
		# Metal grill door bars.
		for k in 4:
			var t := (float(k) + 0.5) / 4.0
			var p := mid - along * half_w + along * (half_w * 2.0 * t) + outward * 0.05
			_box(dark, Vector3(p.x, top * 0.55, p.y), Vector3(0.04, top - 0.2, 0.04), steel.lightened(0.1))
	elif entrance == 1:
		# Twin leaf seam.
		_box(dark, Vector3(mid.x, top * 0.55, mid.y) + Vector3(outward.x, 0, outward.y) * 0.05, Vector3(0.03, top - 0.18, 0.03), wood.darkened(0.15))
	_wall(plaster, mid - along * (half_w + 0.06), mid + along * (half_w + 0.06), 0.0, 0.1, outward, frame.darkened(0.12))
	# Lintels / sunshade over door.
	var brow := mid + outward * 0.22
	_wall(plaster, brow - along * (half_w + 0.2), brow + along * (half_w + 0.2), top + 0.02, top + 0.14, outward, CONCRETE)


static func _steps(pair: Array, tools: Dictionary, a: Vector2, b: Vector2, outward: Vector2, clear: float, col: Color) -> void:
	if clear < 2.8:
		return
	var along := (b - a).normalized()
	var mid := (a + b) * 0.5
	var side := along * 0.72
	var inner := mid + outward * 0.05
	var tread := mid + outward * 0.58
	if clear < 1.3:
		return
	var tone := col.darkened(0.08)
	_horiz(pair, inner - side, inner + side, tread + side, tread - side, 0.16, Vector3.UP, tone)
	_wall(pair, inner - side, inner + side, 0.0, 0.16, -outward, tone)
	_wall(pair, tread - side, tread + side, 0.0, 0.16, outward, tone)
	var side_n := Vector2(along.y, -along.x)
	_wall(pair, inner - side, tread - side, 0.0, 0.16, -side_n, tone)
	_wall(pair, tread + side, inner + side, 0.0, 0.16, side_n, tone)
	_col_quad(tools, inner - side, inner + side, tread + side, tread - side, 0.16)


static func _lamp(pair: Array, a: Vector2, b: Vector2, outward: Vector2) -> void:
	var along := (b - a).normalized()
	var at := (a + b) * 0.5 + outward * 0.16 + along * 0.78
	_box(pair, Vector3(at.x, 2.15, at.y), Vector3(0.14, 0.18, 0.16), Color(1, 0.9, 0.7))


static func _windows(
	glass: Array,
	trim: Array,
	dark: Array,
	metal: Array,
	a: Vector2,
	b: Vector2,
	outward: Vector2,
	floors: int,
	ground_h: float,
	upper_h: float,
	road_face: bool,
	tint: Color,
	variant: int,
	style: String,
	facade: int,
	first_floor: int
) -> void:
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var spacing: float = [2.85, 2.2, 3.35, 2.55, 3.05, 2.4, 2.75][variant]
	var half_w: float = [0.52, 0.38, 0.62, 0.44, 0.48, 0.4, 0.56][variant]
	var half_h: float = [0.58, 0.72, 0.5, 0.64, 0.56, 0.68, 0.6][variant]
	var shade: float = [0.22, 0.32, 0.16, 0.26, 0.28, 0.24, 0.3][variant]
	if style == "cottage":
		spacing *= 1.12
		half_w *= 0.88
		half_h *= 0.92
		shade *= 0.85
	elif style == "row":
		spacing *= 0.85
		half_w *= 0.95
		half_h *= 1.15
		shade *= 1.25
	elif style == "family":
		half_w *= 1.1
		shade *= 1.12
	# Narrow: tighter vertical stacks; family facade 2 = wider paired panes.
	if style == "row" or facade == 3:
		spacing = minf(spacing, 2.5)
		half_h *= 1.05
	if facade == 2:
		half_w *= 1.12
		shade *= 1.15
	var count := maxi(1, int(length / spacing))
	var glass_col := Color(0.28, 0.42, 0.5) if facade != 1 else Color(0.22, 0.36, 0.44)
	for f in range(first_floor, floors):
		var y := ground_h * 0.55 if f == 0 else ground_h + (float(f - 1) + 0.42) * upper_h
		for c in count:
			var t := (float(c) + 0.5) / float(count)
			if road_face and f == 0 and absf(t - 0.5) < 0.18:
				continue
			var centre := a.lerp(b, t) + outward * 0.02
			var frame_col := tint.darkened(0.28)
			# Dark reveal plate, then glass proud of wall so openings read at street distance.
			_wall(dark, centre - along * (half_w + 0.1), centre + along * (half_w + 0.1), y - half_h - 0.08, y + half_h + 0.08, outward, Color(0.18, 0.17, 0.16))
			_wall(glass, centre - along * half_w + outward * 0.06, centre + along * half_w + outward * 0.06, y - half_h, y + half_h, outward, glass_col)
			# Mullion + sill.
			_box(dark, Vector3(centre.x, y, centre.y) + Vector3(outward.x, 0, outward.y) * 0.07, Vector3(0.04, half_h * 1.7, 0.04), frame_col.darkened(0.1))
			_wall(trim, centre - along * (half_w + 0.05) + outward * 0.05, centre + along * (half_w + 0.05) + outward * 0.05, y - half_h - 0.1, y - half_h, outward, CONCRETE)
			if not (style == "cottage" and facade == 0):
				_grill(metal, centre, along, outward, y, half_w, half_h, facade)
			# Concrete sunshade / chajja — always on road face, often on sides.
			if road_face or facade != 0 or style != "cottage":
				var brow: Vector2 = centre + outward * maxf(shade, 0.2)
				var brow_w: float = half_w + 0.22
				_wall(trim, brow - along * brow_w, brow + along * brow_w, y + half_h, y + half_h + 0.12, outward, CONCRETE)
				_horiz(trim, brow - along * brow_w, brow + along * brow_w, brow + along * brow_w + outward * 0.1, brow - along * brow_w + outward * 0.1, y + half_h + 0.12, Vector3.UP, CONCRETE)

static func _shutter(metal: Array, trim: Array, a: Vector2, b: Vector2, outward: Vector2, ground_h: float, tint: Color) -> void:
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var count := maxi(1, int(length / 2.8))
	for c in count:
		var t := (float(c) + 0.5) / float(count)
		var centre := a.lerp(b, t) + outward * 0.04
		var half := along * (length / float(count) * 0.36)
		_wall(metal, centre - half, centre + half, 0.12, 2.45, outward, Color(0.62, 0.64, 0.66))
	var board := (a + b) * 0.5 + outward * 0.08
	_wall(trim, board - along * (length * 0.42), board + along * (length * 0.42), ground_h - 0.72, ground_h - 0.16, outward, tint.darkened(0.22))


static func _balcony(
	plaster: Array,
	rail: Array,
	dark: Array,
	a: Vector2,
	b: Vector2,
	outward: Vector2,
	y: float,
	tint: Color,
	variant: int
) -> void:
	var along := (b - a).normalized()
	var mid := (a + b) * 0.5
	var reach := 2.6 if variant < 4 else 3.4
	var width := minf(a.distance_to(b) * 0.44, reach)
	var depth := 0.7 if variant % 2 == 0 else 0.95
	var inner := mid + outward * 0.02
	var outer := mid + outward * depth
	var side := along * (width * 0.5)
	var y0 := y - 0.04
	var slab := CONCRETE.darkened(0.04)
	_horiz(plaster, inner - side, inner + side, outer + side, outer - side, y0, Vector3.UP, slab)
	# Slab edge lip.
	_wall(plaster, outer - side, outer + side, y0 - 0.1, y0, outward, slab.darkened(0.08))
	var rail_h := 0.82
	var rail_col := Color(0.45, 0.47, 0.5)
	_wall(rail, outer - side, outer + side, y0, y0 + rail_h, outward, rail_col)
	var side_n := Vector2(along.y, -along.x)
	_wall(rail, inner + side, outer + side, y0, y0 + rail_h, side_n, rail_col)
	_wall(rail, outer - side, inner - side, y0, y0 + rail_h, -side_n, rail_col)
	# Vertical baluster posts (merged into same metal surface).
	var posts := maxi(3, int(width / 0.55))
	for p in posts:
		var t := float(p) / float(posts)
		var at := (outer - side).lerp(outer + side, t)
		_box(dark, Vector3(at.x, y0 + rail_h * 0.5, at.y), Vector3(0.04, rail_h, 0.04), rail_col.darkened(0.1))
	# Handrail cap.
	_box(rail, Vector3(outer.x, y0 + rail_h + 0.03, outer.y), Vector3(width, 0.05, 0.06), rail_col.lightened(0.08))


static func _grill(
	metal: Array,
	centre: Vector2,
	along: Vector2,
	outward: Vector2,
	y: float,
	half_w: float,
	half_h: float,
	facade: int
) -> void:
	var bars := 3 if facade == 0 else 4
	var col := Color(0.32, 0.34, 0.36)
	for i in bars:
		var t := (float(i) + 0.5) / float(bars)
		var p := centre - along * half_w + along * (half_w * 2.0 * t) + outward * 0.06
		_box(metal, Vector3(p.x, y, p.y), Vector3(0.03, half_h * 1.65, 0.03), col)
	# Cross bar.
	var mid := centre + outward * 0.06
	_box(metal, Vector3(mid.x, y, mid.y), Vector3(half_w * 1.7, 0.03, 0.03), col)


static func _overhang(
	plaster: Array,
	a: Vector2,
	b: Vector2,
	outward: Vector2,
	y: float,
	tint: Color,
	style: String
) -> void:
	var along := (b - a).normalized()
	var depth := 0.28 if style == "cottage" else 0.42
	if style == "family":
		depth = 0.5
	var outer_a := a + outward * depth
	var outer_b := b + outward * depth
	_horiz(plaster, a, b, outer_b, outer_a, y + 0.02, Vector3.UP, CONCRETE)
	_wall(plaster, outer_a, outer_b, y - 0.08, y + 0.02, outward, CONCRETE.darkened(0.06))
	# Tiny drip edge at corners.
	_box(plaster, Vector3(outer_a.x, y - 0.02, outer_a.y), Vector3(0.08, 0.1, 0.08), tint.darkened(0.2))
	_box(plaster, Vector3(outer_b.x, y - 0.02, outer_b.y), Vector3(0.08, 0.1, 0.08), tint.darkened(0.2))


static func _parapet_posts(
	plaster: Array,
	a: Vector2,
	b: Vector2,
	outward: Vector2,
	lip: float,
	col: Color,
	variant: int
) -> void:
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var count := clampi(int(length / 2.8), 2, 5)
	for i in count:
		var t := float(i) / float(maxi(count - 1, 1))
		var p := a.lerp(b, t) + outward * 0.06
		var h := 0.22 + float(variant % 3) * 0.04
		_box(plaster, Vector3(p.x, lip + h * 0.5, p.y), Vector3(0.14, h, 0.14), col)


static func _awning(
	plaster: Array,
	metal: Array,
	a: Vector2,
	b: Vector2,
	outward: Vector2,
	y: float,
	tint: Color
) -> void:
	## Neutral shop awning — no text. Only used when style is shop/commercial.
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var half := along * minf(length * 0.42, 3.2)
	var mid := (a + b) * 0.5
	var outer := mid + outward * 0.85
	_horiz(plaster, mid - half, mid + half, outer + half, outer - half, y, Vector3.UP, tint.darkened(0.18))
	_wall(metal, outer - half, outer + half, y - 0.05, y, outward, Color(0.4, 0.42, 0.44))


static func _roof(pair: Array, poly: PackedVector2Array, y: float) -> void:
	var col := CONCRETE
	var index := Geometry2D.triangulate_polygon(poly)
	if index.is_empty():
		var centre := _inside(poly)
		for i in poly.size():
			var p0: Vector2 = poly[i]
			var p1: Vector2 = poly[(i + 1) % poly.size()]
			var a := Vector3(centre.x, y, centre.y)
			var b := Vector3(p0.x, y, p0.y)
			var c := Vector3(p1.x, y, p1.y)
			if (b - a).cross(c - a).y < 0.0:
				var swap := b
				b = c
				c = swap
			_tri(pair, a, b, c, Vector3.UP, col)
		return
	for t in range(0, index.size(), 3):
		var p0: Vector2 = poly[index[t]]
		var p1: Vector2 = poly[index[t + 1]]
		var p2: Vector2 = poly[index[t + 2]]
		var a := Vector3(p0.x, y, p0.y)
		var b := Vector3(p1.x, y, p1.y)
		var c := Vector3(p2.x, y, p2.y)
		if (b - a).cross(c - a).y < 0.0:
			var swap := b
			b = c
			c = swap
		_tri(pair, a, b, c, Vector3.UP, col)


static func _tank(pair: Array, poly: PackedVector2Array, y: float, seed: int, scale: float) -> void:
	var spot := _inside(poly)
	var shift := Vector2(float(seed % 5) - 2.0, float((seed / 5) % 5) - 2.0) * 0.35
	var at := spot + shift
	if not Geometry2D.is_point_in_polygon(at, poly):
		at = spot
	var body := Color(0.22, 0.28, 0.34)
	_box(pair, Vector3(at.x, y + 0.42 * scale, at.y), Vector3(0.9 * scale, 0.84 * scale, 0.9 * scale), body)
	# Rim + short stand pipe read.
	_box(pair, Vector3(at.x, y + 0.88 * scale, at.y), Vector3(0.98 * scale, 0.08 * scale, 0.98 * scale), body.lightened(0.08))
	_box(pair, Vector3(at.x + 0.35 * scale, y + 0.2 * scale, at.y), Vector3(0.08 * scale, 0.4 * scale, 0.08 * scale), body.darkened(0.1))


static func _stair(pair: Array, poly: PackedVector2Array, y: float, tint: Color) -> void:
	var at := _inside(poly) + Vector2(1.6, -1.2)
	if not Geometry2D.is_point_in_polygon(at, poly):
		at = _inside(poly)
	_box(pair, Vector3(at.x, y + 0.55, at.y), Vector3(1.35, 1.1, 1.35), tint.darkened(0.12))


static func _inside(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= float(poly.size())
	if Geometry2D.is_point_in_polygon(c, poly):
		return c
	var index := Geometry2D.triangulate_polygon(poly)
	if index.size() >= 3:
		return (poly[index[0]] + poly[index[1]] + poly[index[2]]) / 3.0
	return poly[0]


static func _body(root: Node3D, id: String, poly: PackedVector2Array, height: float) -> void:
	var faces := PackedVector3Array()
	var n := poly.size()
	for i in n:
		var a := Vector3(poly[i].x, 0.0, poly[i].y)
		var b := Vector3(poly[(i + 1) % n].x, 0.0, poly[(i + 1) % n].y)
		var a1 := Vector3(a.x, height, a.z)
		var b1 := Vector3(b.x, height, b.z)
		faces.append_array([a, b, b1, a, b1, a1])
	var index := Geometry2D.triangulate_polygon(poly)
	for t in range(0, index.size(), 3):
		var p0 := Vector3(poly[index[t]].x, height, poly[index[t]].y)
		var p1 := Vector3(poly[index[t + 1]].x, height, poly[index[t + 1]].y)
		var p2 := Vector3(poly[index[t + 2]].x, height, poly[index[t + 2]].y)
		faces.append_array([p0, p1, p2])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = "hit_%s" % id
	body.set_meta("osm_id", id)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	root.add_child(body)


static func _compound(tools: Dictionary, specs: Array) -> int:
	var walls := 0
	var plaster: Array = tools["plaster"]
	var tone := Color(0.73, 0.71, 0.67)
	for i in specs.size():
		var left: Dictionary = specs[i]
		var pa: PackedVector2Array = left["poly"]
		var fa: int = int(left.get("front", 0))
		for j in range(i + 1, specs.size()):
			var right: Dictionary = specs[j]
			var pb: PackedVector2Array = right["poly"]
			var fb: int = int(right.get("front", 0))
			var built := 0
			for ei in pa.size():
				if ei == fa or pa.size() < 3:
					continue
				var p0: Vector2 = pa[ei]
				var p1: Vector2 = pa[(ei + 1) % pa.size()]
				var elen := p0.distance_to(p1)
				if elen < 2.2:
					continue
				var mid := (p0 + p1) * 0.5
				var best_d := 1.0e9
				var best_mid := Vector2.ZERO
				var best_len := 0.0
				for ej in pb.size():
					if ej == fb:
						continue
					var q0: Vector2 = pb[ej]
					var q1: Vector2 = pb[(ej + 1) % pb.size()]
					var qlen := q0.distance_to(q1)
					if qlen < 2.2:
						continue
					var d := _seg_dist(mid, q0, q1)
					if d < best_d:
						best_d = d
						best_mid = (q0 + q1) * 0.5
						best_len = qlen
				if best_d < 0.45 or best_d > 2.35:
					continue
				var along := (p1 - p0).normalized()
				var centre := (mid + best_mid) * 0.5
				var half := minf(minf(elen, best_len) * 0.34, 4.5)
				var wa := centre - along * half
				var wb := centre + along * half
				var front_a: Vector2 = pa[fa % pa.size()]
				var front_b: Vector2 = pa[(fa + 1) % pa.size()]
				var front_mid := (front_a + front_b) * 0.5
				if wa.distance_to(front_mid) < wb.distance_to(front_mid):
					wa += along * 0.9
				else:
					wb -= along * 0.9
				if wa.distance_to(wb) < 1.25:
					continue
				var gap := best_mid - mid
				if gap.length() < 0.2:
					continue
				var nrm := gap.normalized()
				var h := 1.06
				_wall(plaster, wa, wb, 0.0, h, nrm, tone)
				_wall(plaster, wb, wa, 0.0, h, -nrm, tone)
				_box(plaster, Vector3(wa.x, h * 0.55, wa.y), Vector3(0.2, h + 0.16, 0.2), tone.darkened(0.08))
				_box(plaster, Vector3(wb.x, h * 0.55, wb.y), Vector3(0.2, h + 0.16, 0.2), tone.darkened(0.08))
				_col_wall(tools, wa, wb, h)
				walls += 1
				built += 1
				if built >= 2:
					break
	return walls


static func _party(a: Vector2, b: Vector2, id: String, specs: Array) -> bool:
	var mid := (a + b) * 0.5
	for other_v in specs:
		var other: Dictionary = other_v
		if str(other["id"]) == id:
			continue
		var poly: PackedVector2Array = other["poly"]
		for i in poly.size():
			var c: Vector2 = poly[i]
			var d: Vector2 = poly[(i + 1) % poly.size()]
			if _seg_dist(mid, c, d) < PARTY_M:
				return true
	return false


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var den := ab.length_squared()
	var t := 0.0 if den == 0.0 else clampf((p - a).dot(ab) / den, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


static func _box(pair: Array, c: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var p := [
		c + Vector3(-h.x, -h.y, -h.z),
		c + Vector3(h.x, -h.y, -h.z),
		c + Vector3(h.x, h.y, -h.z),
		c + Vector3(-h.x, h.y, -h.z),
		c + Vector3(-h.x, -h.y, h.z),
		c + Vector3(h.x, -h.y, h.z),
		c + Vector3(h.x, h.y, h.z),
		c + Vector3(-h.x, h.y, h.z),
	]
	_quad(pair, p[4], p[5], p[6], p[7], Vector3(0, 0, 1), col)
	_quad(pair, p[1], p[0], p[3], p[2], Vector3(0, 0, -1), col)
	_quad(pair, p[5], p[1], p[2], p[6], Vector3(1, 0, 0), col)
	_quad(pair, p[0], p[4], p[7], p[3], Vector3(-1, 0, 0), col)
	_quad(pair, p[3], p[2], p[6], p[7], Vector3(0, 1, 0), col)
	_quad(pair, p[0], p[1], p[5], p[4], Vector3(0, -1, 0), col)


static func _horiz(pair: Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2, y: float, n: Vector3, col: Color) -> void:
	_quad(pair, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3(d.x, y, d.y), n, col)


static func _quad(pair: Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	_tri(pair, a, b, c, n, col)
	_tri(pair, a, c, d, n, col)


static func _tri(pair: Array, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	var st: SurfaceTool = pair[0]
	pair[1] = int(pair[1]) + 3
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(a)
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(b)
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(c)


static func _col_wall(tools: Dictionary, a: Vector2, b: Vector2, h: float) -> void:
	var a0 := Vector3(a.x, 0.0, a.y)
	var b0 := Vector3(b.x, 0.0, b.y)
	var a1 := Vector3(a.x, h, a.y)
	var b1 := Vector3(b.x, h, b.y)
	_add_col(tools, PackedVector3Array([a0, b0, b1, a0, b1, a1, a0, b1, b0, a0, a1, b1]))


static func _col_quad(tools: Dictionary, a: Vector2, b: Vector2, c: Vector2, d: Vector2, y: float) -> void:
	var p0 := Vector3(a.x, y, a.y)
	var p1 := Vector3(b.x, y, b.y)
	var p2 := Vector3(c.x, y, c.y)
	var p3 := Vector3(d.x, y, d.y)
	_add_col(tools, PackedVector3Array([p0, p1, p2, p0, p2, p3]))


static func _add_col(tools: Dictionary, pts: PackedVector3Array) -> void:
	var col: PackedVector3Array = tools["col"]
	col.append_array(pts)
	tools["col"] = col


static func _tool(mat: Material) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return [st, 0, mat]


static func _mat(color: Color, rough: float, vertex: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = 0.0
	mat.vertex_color_use_as_albedo = vertex
	if vertex:
		mat.vertex_color_is_srgb = true
	return mat
