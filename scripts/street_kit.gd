extends RefCounted
## Own Indian street props — shared materials, fewer decorative collisions.


static var _mat_cache: Dictionary = {}
static var _unit_cyl: CylinderMesh = null
static var _unit_sphere: SphereMesh = null
static var _unit_box_mesh: BoxMesh = null
## Box batching: many thousands of lane-marking / kerb / paint boxes are visual-only.
## While a batch is open, add_box() records a scaled unit-box transform per material
## instead of creating a MeshInstance3D, and flush_box_batch() commits one
## MultiMeshInstance3D per material. Big Android node-count win.
static var _box_batch_parent: Node3D = null
static var _box_batches: Dictionary = {}
static var _box_batch_count := 0


static func mat(color: Color, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	## Include alpha so transparent colours do not collide with opaque cache entries.
	var key := "%s|%.2f|%.2f" % [color.to_html(true), rough, metal]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m


static func mat_emissive(color: Color, emission: Color, energy: float = 1.4, rough: float = 0.35) -> StandardMaterial3D:
	var key := "E|%s|%s|%.2f|%.2f" % [color.to_html(true), emission.to_html(true), energy, rough]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := mat(color, rough).duplicate() as StandardMaterial3D
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	_mat_cache[key] = m
	return m


static func _center_on_ground(size: Vector3, ground: Vector3) -> Vector3:
	## BoxMesh center so the bottom sits on ground.y.
	return ground + Vector3(0, size.y * 0.5, 0)


static func _rot(offset: Vector3, yaw: float) -> Vector3:
	## Local prop offset -> world offset for a prop rotated by yaw (local +Z = along/face).
	return offset.rotated(Vector3.UP, yaw)


static func _unit_cylinder() -> CylinderMesh:
	## Shared radius-1 / height-1 cylinder; scale the instance to size.
	if _unit_cyl == null:
		_unit_cyl = CylinderMesh.new()
		_unit_cyl.top_radius = 1.0
		_unit_cyl.bottom_radius = 1.0
		_unit_cyl.height = 1.0
		_unit_cyl.radial_segments = 10
		_unit_cyl.rings = 1
	return _unit_cyl


static func _unit_ball() -> SphereMesh:
	## Shared radius-1 sphere; scale the instance to size.
	if _unit_sphere == null:
		_unit_sphere = SphereMesh.new()
		_unit_sphere.radius = 1.0
		_unit_sphere.height = 2.0
		_unit_sphere.radial_segments = 12
		_unit_sphere.rings = 6
	return _unit_sphere


static func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, scale: Vector3 = Vector3.ONE, yaw: float = 0.0) -> void:
	## Visual-only mesh instance (no collision).
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation.y = yaw
	mi.scale = scale
	parent.add_child(mi)


static func _cylinder(parent: Node3D, radius: float, height: float, bottom: Vector3, material: Material) -> void:
	## Upright cylinder whose bottom sits on bottom.y.
	_add_mesh(parent, _unit_cylinder(), bottom + Vector3(0, height * 0.5, 0), material, Vector3(radius, height, radius))


static func begin_box_batch(parent: Node3D) -> void:
	_box_batch_parent = parent
	_box_batches.clear()
	_box_batch_count = 0


static func flush_box_batch() -> int:
	## Commit every queued visual box as one MultiMeshInstance3D per material.
	var committed := _box_batch_count
	if _box_batch_parent != null:
		for material in _box_batches:
			_commit_batch(_box_batch_parent, _unit_box(), _box_batches[material], [], material, false)
	_box_batches.clear()
	_box_batch_parent = null
	_box_batch_count = 0
	return committed


static func _unit_box() -> BoxMesh:
	if _unit_box_mesh == null:
		_unit_box_mesh = BoxMesh.new()
		_unit_box_mesh.size = Vector3.ONE
	return _unit_box_mesh


static func add_box(
	parent: Node3D,
	size: Vector3,
	pos: Vector3,
	material: Material,
	with_collision: bool = false,
	yaw: float = 0.0,
	cast_shadows: bool = true
) -> void:
	if _box_batch_parent != null and not with_collision:
		# Visual-only box → record a scaled unit-box instance; no node per box.
		# Batches always flush with cast off (see flush_box_batch).
		var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(size), pos)
		if not _box_batches.has(material):
			_box_batches[material] = []
		(_box_batches[material] as Array).append(xf)
		_box_batch_count += 1
		return
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation.y = yaw
	mi.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	parent.add_child(mi)
	if with_collision:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		body.position = pos
		body.rotation.y = yaw
		parent.add_child(body)


static func add_road_deck(
	parent: Node3D,
	width: float,
	length: float,
	pos: Vector3,
	yaw: float,
	material: Material,
	tile_m: float = 12.0,
	_along_u: bool = true,
	edge_mat: Material = null,
	sidewalk_mat: Material = null,
	sidewalk_w: float = 0.0,
	kerb_h: float = 0.14,
	center_line: bool = false
) -> void:
	## Flat road slab. Local Z = along road, local X = across width.
	## Kit albedos are normalized so dashes run along U — U maps to length.
	## Never world-triplanar (that put center dashes across the carriageway).
	## edge_mat != null paints crisp lane-edge lines into a second surface.
	## sidewalk_mat + sidewalk_w bake raised kerb + sidewalk strips into the SAME
	## mesh — clear road/pedestrian separation with zero extra MeshInstance3D nodes.
	var hw := width * 0.5
	var hl := length * 0.5
	var span := maxf(length / maxf(tile_m, 1.0), 0.01)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nrm := Vector3.UP
	# CCW from above: back-left, back-right, front-right / front-left
	var v0 := Vector3(-hw, 0, -hl)
	var v1 := Vector3(hw, 0, -hl)
	var v2 := Vector3(hw, 0, hl)
	var v3 := Vector3(-hw, 0, hl)
	# U along Z (travel), V across X (lane width 0..1)
	st.set_normal(nrm)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(v0)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(v1)
	st.set_uv(Vector2(span, 1.0))
	st.add_vertex(v2)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(v0)
	st.set_uv(Vector2(span, 1.0))
	st.add_vertex(v2)
	st.set_uv(Vector2(span, 0.0))
	st.add_vertex(v3)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, material)
	if edge_mat != null and width >= 5.0:
		var es := SurfaceTool.new()
		es.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ew := 0.15
		var inset := hw - 0.45
		for sx in [-1.0, 1.0]:
			var cx: float = sx * inset
			_flat_quad(es, Vector3(cx - ew * 0.5, 0.013, -hl), Vector3(cx + ew * 0.5, 0.013, -hl), Vector3(cx + ew * 0.5, 0.013, hl), Vector3(cx - ew * 0.5, 0.013, hl))
		if center_line:
			# Dashed centre line, baked into the same edge surface (no extra nodes).
			var dash := 2.6
			var gap := 3.6
			var z := -hl + dash
			while z + dash <= hl:
				_flat_quad(es, Vector3(-0.075, 0.014, z), Vector3(0.075, 0.014, z), Vector3(0.075, 0.014, z + dash), Vector3(-0.075, 0.014, z + dash))
				z += dash + gap
		es.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, edge_mat)
	if sidewalk_mat != null and sidewalk_w > 0.05:
		# Both sides: kerb face + kerb coping + sidewalk deck, all one surface.
		var ss := SurfaceTool.new()
		ss.begin(Mesh.PRIMITIVE_TRIANGLES)
		var kerb_w := 0.18
		for sx in [-1.0, 1.0]:
			var xr: float = sx * hw
			var xk: float = sx * (hw + kerb_w)
			var xs: float = sx * (hw + sidewalk_w)
			# Sidewalk deck (raised, flat)
			_quad_n(ss, Vector3(xk, kerb_h, -hl), Vector3(xs, kerb_h, -hl), Vector3(xs, kerb_h, hl), Vector3(xk, kerb_h, hl), Vector3.UP)
			# Kerb coping top (flat strip at road-edge level)
			_quad_n(ss, Vector3(xr, kerb_h, -hl), Vector3(xk, kerb_h, -hl), Vector3(xk, kerb_h, hl), Vector3(xr, kerb_h, hl), Vector3.UP)
			# Kerb vertical face toward the carriageway
			_quad_n(ss, Vector3(xr, 0.0, -hl), Vector3(xr, kerb_h, -hl), Vector3(xr, kerb_h, hl), Vector3(xr, 0.0, hl), Vector3(-sx, 0, 0))
		ss.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, sidewalk_mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)


static func _flat_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	## Upward-facing quad (a-b-c / a-c-d), matching the road-deck winding.
	_quad_n(st, a, b, c, d, Vector3.UP)


static func _quad_n(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	## Quad with explicit outward normal; winding is fixed to match it.
	if (b - a).cross(c - a).dot(n) < 0.0:
		var tmp := b
		b = d
		d = tmp
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


static func shop_row(
	parent: Node3D,
	origin: Vector3,
	along: Vector3,
	outward: Vector3,
	count: int,
	rng: RandomNumberGenerator,
	palette: Array
) -> void:
	## Mixed Maharashtra street frontage: shops + homes (procedural, not real footprints).
	var cursor := origin
	for _i in count:
		var is_shop := rng.randf() < 0.62
		if is_shop:
			_one_shop(parent, cursor, along, outward, rng, palette)
			cursor += along * (rng.randf_range(6.2, 9.5))
		else:
			_one_home(parent, cursor, along, outward, rng, palette)
			cursor += along * (rng.randf_range(7.0, 11.0))


static func _one_shop(
	parent: Node3D,
	origin: Vector3,
	along: Vector3,
	outward: Vector3,
	rng: RandomNumberGenerator,
	palette: Array
) -> void:
	var w := rng.randf_range(5.8, 8.8)
	var d := rng.randf_range(5.8, 8.2)
	var floors := rng.randi_range(1, 3)
	var h := 3.1 + float(floors) * 2.55
	var wall: Material = palette[rng.randi_range(0, palette.size() - 1)]
	var gy := origin.y
	var center := origin + outward * (d * 0.5 + 0.6)
	center.y = gy
	var yaw := atan2(along.x, along.z)
	var glass := mat(Color(0.42, 0.52, 0.62, 0.5), 0.08, 0.05)
	var roof_mat := mat(Color(0.32, 0.3, 0.28), 0.88)
	var wood := mat(Color(0.28, 0.16, 0.1))
	var awning_colors: Array[Color] = [
		Color(0.12, 0.32, 0.55),
		Color(0.7, 0.15, 0.12),
		Color(0.15, 0.45, 0.28),
		Color(0.85, 0.55, 0.1),
	]
	var awning_mat := mat(awning_colors[rng.randi_range(0, awning_colors.size() - 1)])

	add_box(parent, Vector3(w, h, d), _center_on_ground(Vector3(w, h, d), center), wall, true, yaw)
	# Flat parapet roof common in Dhule-style blocks
	add_box(parent, Vector3(w + 0.35, 0.28, d + 0.35), center + Vector3(0, h + 0.1, 0), roof_mat, false, yaw)
	if rng.randf() < 0.45:
		add_box(
			parent,
			Vector3(rng.randf_range(1.2, 1.8), 0.9, rng.randf_range(1.2, 1.8)),
			center + Vector3(rng.randf_range(-1.2, 1.2), h + 0.7, rng.randf_range(-0.8, 0.8)),
			mat(Color(0.55, 0.55, 0.58), 0.55, 0.15),
			false,
			yaw
		)

	var face := center - outward * (d * 0.5 + 0.02)
	for fy in range(floors):
		var wy := gy + 1.5 + float(fy) * 2.55
		add_box(parent, Vector3(1.15, 1.05, 0.06), face + along * (-w * 0.22) + Vector3(0, wy, 0), glass, false, yaw)
		add_box(parent, Vector3(1.15, 1.05, 0.06), face + along * (w * 0.22) + Vector3(0, wy, 0), glass, false, yaw)
		if floors > 1 and fy > 0 and rng.randf() < 0.55:
			# Small balcony slab
			add_box(
				parent,
				Vector3(w * 0.55, 0.1, 0.85),
				face - outward * 0.35 + Vector3(0, wy - 0.55, 0),
				mat(Color(0.62, 0.6, 0.55)),
				false,
				yaw
			)

	add_box(
		parent,
		Vector3(w + 0.35, 0.1, 1.6),
		origin + outward * 0.95 + Vector3(0, gy + 0.05, 0),
		mat(Color(0.56, 0.54, 0.48)),
		false,
		yaw
	)
	var board := mat(Color(rng.randf_range(0.65, 1.0), rng.randf_range(0.12, 0.45), rng.randf_range(0.05, 0.22)))
	add_box(parent, Vector3(w * 0.9, 0.58, 0.16), origin + outward * 0.14 + Vector3(0, gy + 2.5, 0), board, false, yaw)
	add_box(parent, Vector3(w * 0.88, 0.07, 1.15), origin + outward * 0.75 + Vector3(0, gy + 2.05, 0), awning_mat, false, yaw)
	add_box(parent, Vector3(1.15, 2.0, 0.08), origin + outward * 0.06 + Vector3(0, gy + 1.0, 0), wood, false, yaw)


static func _one_home(
	parent: Node3D,
	origin: Vector3,
	along: Vector3,
	outward: Vector3,
	rng: RandomNumberGenerator,
	palette: Array
) -> void:
	var w := rng.randf_range(6.5, 10.0)
	var d := rng.randf_range(6.0, 9.0)
	var floors := rng.randi_range(1, 2)
	var h := 3.0 + float(floors) * 2.7
	var wall: Material = palette[rng.randi_range(0, palette.size() - 1)]
	var gy := origin.y
	var center := origin + outward * (d * 0.5 + 1.0)
	center.y = gy
	var yaw := atan2(along.x, along.z)
	var glass := mat(Color(0.35, 0.45, 0.55, 0.55), 0.1, 0.04)
	var roof_mat := mat(Color(0.45, 0.28, 0.18), 0.9) # terracotta / tiled feel
	var plaster := mat(Color(0.78, 0.74, 0.66))

	add_box(parent, Vector3(w, h, d), _center_on_ground(Vector3(w, h, d), center), wall, true, yaw)
	if rng.randf() < 0.55:
		# Pitched-ish roof slab (stylized)
		add_box(parent, Vector3(w + 0.5, 0.35, d + 0.5), center + Vector3(0, h + 0.15, 0), roof_mat, false, yaw)
	else:
		add_box(parent, Vector3(w + 0.25, 0.22, d + 0.25), center + Vector3(0, h + 0.08, 0), mat(Color(0.5, 0.48, 0.44)), false, yaw)

	var face := center - outward * (d * 0.5 + 0.02)
	for fy in range(floors):
		var wy := gy + 1.6 + float(fy) * 2.7
		add_box(parent, Vector3(1.0, 1.15, 0.05), face + along * (-w * 0.25) + Vector3(0, wy, 0), glass, false, yaw)
		add_box(parent, Vector3(1.0, 1.15, 0.05), face + along * (w * 0.25) + Vector3(0, wy, 0), glass, false, yaw)
	# Door + porch (visual only — no wall collision into the road)
	add_box(parent, Vector3(1.0, 2.1, 0.08), face + Vector3(0, gy + 1.05, 0), mat(Color(0.35, 0.2, 0.12)), false, yaw)
	add_box(parent, Vector3(w * 0.7, 0.12, 1.4), origin + outward * 0.7 + Vector3(0, gy + 0.06, 0), plaster, false, yaw)
	if rng.randf() < 0.55:
		add_box(
			parent,
			Vector3(w * 0.9, 1.05, 0.16),
			origin + outward * 1.8 + Vector3(0, gy + 0.52, 0),
			mat(Color(0.7, 0.66, 0.56)),
			false,
			yaw
		)


static func lamp(parent: Node3D, pos: Vector3) -> void:
	## Slim 6 m street light: pole + collar + arm + warm emissive head. No collision.
	var steel := mat(Color(0.42, 0.43, 0.46), 0.5, 0.3)
	_cylinder(parent, 0.08, 6.0, pos, steel)
	_cylinder(parent, 0.15, 0.6, pos, steel)
	add_box(parent, Vector3(1.3, 0.08, 0.08), pos + Vector3(0.6, 5.95, 0), steel, false)
	add_box(parent, Vector3(0.62, 0.14, 0.28), pos + Vector3(1.2, 5.88, 0), mat(Color(0.28, 0.28, 0.3), 0.5), false)
	add_box(
		parent,
		Vector3(0.5, 0.06, 0.2),
		pos + Vector3(1.2, 5.78, 0),
		mat_emissive(Color(0.98, 0.94, 0.78), Color(1.0, 0.92, 0.68), 1.6, 0.3),
		false
	)


## Trees are batched into two MultiMeshInstance3D (trunk + canopy) — hundreds of
## trees cost 2 draw calls instead of thousands of MeshInstance3D nodes (Android win).
static var _tree_trunks: Array[Transform3D] = []
static var _tree_canopies: Array[Transform3D] = []
static var _tree_canopy_cols: Array[Color] = []
static var _tree_cols: Array[Transform3D] = [] ## trunk collision capsules (sparse)
static var _tree_trunk_mat: StandardMaterial3D
static var _tree_canopy_mat: StandardMaterial3D
const TREE_COL_CAP := 96


static func tree(_parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	## Neem / peepal / dusty roadside tree, or a tall slim ashoka (25%).
	## Queued for batching — call StreetKit.flush_trees(map) after the map build.
	_queue_tree(pos, rng)


static func _queue_tree(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf() * TAU
	var greens: Array[Color] = [
		Color(0.11, 0.3, 0.13), # neem — dark green
		Color(0.27, 0.5, 0.2), # peepal — lighter green
		Color(0.4, 0.43, 0.22), # dusty olive
	]
	if rng.randf() < 0.25:
		var ashoka_h := rng.randf_range(3.8, 4.4)
		var atr := rng.randf_range(0.14, 0.2)
		_tree_trunks.append(Transform3D(Basis().scaled(Vector3(atr, ashoka_h, atr)), pos + Vector3(0, ashoka_h * 0.5, 0)))
		if _tree_cols.size() < TREE_COL_CAP:
			_tree_cols.append(Transform3D(Basis().scaled(Vector3(atr * 1.15, ashoka_h * 0.85, atr * 1.15)), pos + Vector3(0, ashoka_h * 0.42, 0)))
		var ar := rng.randf_range(1.0, 1.35)
		var asc := Vector3(ar, ar * 2.2, ar)
		_tree_canopies.append(Transform3D(Basis(Vector3.UP, yaw).scaled(asc), pos + Vector3(0, ashoka_h * 0.7 + ar * 1.1, 0)))
		_tree_canopy_cols.append(greens[rng.randi_range(0, 1)])
		return
	var trunk_h := rng.randf_range(2.4, 3.6)
	var trr := rng.randf_range(0.18, 0.28)
	_tree_trunks.append(Transform3D(Basis().scaled(Vector3(trr, trunk_h, trr)), pos + Vector3(0, trunk_h * 0.5, 0)))
	if _tree_cols.size() < TREE_COL_CAP:
		_tree_cols.append(Transform3D(Basis().scaled(Vector3(trr * 1.2, trunk_h * 0.9, trr * 1.2)), pos + Vector3(0, trunk_h * 0.45, 0)))
	var canopy_c: Color = greens[rng.randi_range(0, greens.size() - 1)]
	var base_r := rng.randf_range(1.6, 2.7)
	var blobs := rng.randi_range(2, 3)
	for i in blobs:
		var r := minf(base_r * rng.randf_range(0.75, 1.15), 3.2)
		var off := Vector3.ZERO
		if i > 0:
			off = Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.3, 0.5), rng.randf_range(-0.9, 0.9))
		var sc := Vector3(r * rng.randf_range(0.9, 1.1), r * rng.randf_range(0.7, 0.9), r * rng.randf_range(0.9, 1.1))
		_tree_canopies.append(Transform3D(Basis(Vector3.UP, yaw).scaled(sc), pos + off + Vector3(0, trunk_h + sc.y * 0.55, 0)))
		_tree_canopy_cols.append(canopy_c)


static func flush_trees(parent: Node3D) -> void:
	## Commit every queued tree as two multi-mesh batches (trunk + canopy) + trunk colliders.
	if _tree_trunks.is_empty() and _tree_canopies.is_empty():
		_tree_cols.clear()
		return
	if _tree_trunk_mat == null:
		_tree_trunk_mat = mat(Color(0.36, 0.24, 0.14), 0.95)
	if _tree_canopy_mat == null:
		_tree_canopy_mat = StandardMaterial3D.new()
		_tree_canopy_mat.albedo_color = Color.WHITE
		_tree_canopy_mat.roughness = 0.95
		_tree_canopy_mat.vertex_color_use_as_albedo = true
	_commit_batch(parent, _unit_cylinder(), _tree_trunks, [], _tree_trunk_mat, true)
	_commit_batch(parent, _unit_ball(), _tree_canopies, _tree_canopy_cols, _tree_canopy_mat, true)
	# Thin trunk StaticBodies so cars bump trees (capped for Android).
	if not _tree_cols.is_empty():
		var holder := Node3D.new()
		holder.name = "TreeColliders"
		parent.add_child(holder)
		for xf in _tree_cols:
			var sc := xf.basis.get_scale()
			var body := StaticBody3D.new()
			body.position = xf.origin
			var col := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = maxf(sc.x, 0.22)
			shape.height = maxf(sc.y, 1.6)
			col.shape = shape
			body.add_child(col)
			holder.add_child(body)
	_tree_trunks.clear()
	_tree_canopies.clear()
	_tree_canopy_cols.clear()
	_tree_cols.clear()


static func _commit_batch(
	parent: Node3D,
	mesh: Mesh,
	xforms: Array,
	cols: Array,
	material: Material,
	cast_shadows: bool = true
) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.use_colors = not cols.is_empty()
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	# Paint/curb boxes stay shadowless; trees keep attached shadows.
	mmi.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	parent.add_child(mmi)


static func parked_stub(parent: Node3D, pos: Vector3, along: Vector3, rng: RandomNumberGenerator) -> void:
	## Parked hatchback / van / scooter silhouette. No collision.
	var yaw := atan2(along.x, along.z)
	var colors: Array[Color] = [
		Color(0.75, 0.2, 0.15),
		Color(0.15, 0.25, 0.55),
		Color(0.85, 0.85, 0.82),
		Color(0.2, 0.2, 0.22),
		Color(0.8, 0.55, 0.1),
	]
	var c: Color = colors[rng.randi_range(0, colors.size() - 1)]
	var paint := mat(c, 0.45, 0.1)
	var glass := mat(Color(0.3, 0.4, 0.5, 0.55), 0.1, 0.05)
	var rubber := mat(Color(0.08, 0.08, 0.09), 0.95)
	var kind := rng.randi_range(0, 2)
	if kind == 0:
		# Hatchback
		add_box(parent, Vector3(1.65, 0.5, 3.4), pos + Vector3(0, 0.42, 0), paint, false, yaw)
		add_box(parent, Vector3(1.45, 0.42, 1.55), pos + _rot(Vector3(0, 0.88, -0.15), yaw), glass, false, yaw)
		add_box(parent, Vector3(1.5, 0.08, 1.6), pos + _rot(Vector3(0, 1.12, -0.15), yaw), paint, false, yaw)
		for wz in [-1.1, 1.1]:
			add_box(parent, Vector3(1.72, 0.3, 0.6), pos + _rot(Vector3(0, 0.3, wz), yaw), rubber, false, yaw)
	elif kind == 1:
		# Van / tempo
		add_box(parent, Vector3(1.8, 1.0, 4.2), pos + Vector3(0, 0.75, 0), paint, false, yaw)
		add_box(parent, Vector3(1.78, 0.75, 4.1), pos + Vector3(0, 1.62, 0), paint, false, yaw)
		add_box(parent, Vector3(1.6, 0.55, 0.12), pos + _rot(Vector3(0, 1.55, 2.1), yaw), glass, false, yaw)
		add_box(parent, Vector3(0.1, 0.5, 2.2), pos + _rot(Vector3(0.9, 1.55, -0.6), yaw), glass, false, yaw)
		add_box(parent, Vector3(0.1, 0.5, 2.2), pos + _rot(Vector3(-0.9, 1.55, -0.6), yaw), glass, false, yaw)
		for wz in [-1.35, 1.35]:
			add_box(parent, Vector3(1.86, 0.32, 0.65), pos + _rot(Vector3(0, 0.32, wz), yaw), rubber, false, yaw)
	else:
		# Scooter
		add_box(parent, Vector3(0.45, 0.35, 1.0), pos + Vector3(0, 0.55, 0), paint, false, yaw)
		add_box(parent, Vector3(0.5, 0.08, 0.7), pos + _rot(Vector3(0, 0.78, -0.1), yaw), rubber, false, yaw)
		add_box(parent, Vector3(0.4, 0.5, 0.25), pos + _rot(Vector3(0, 0.75, 0.75), yaw), paint, false, yaw)
		add_box(parent, Vector3(0.55, 0.06, 0.06), pos + _rot(Vector3(0, 0.98, 0.7), yaw), rubber, false, yaw)
		for wz in [-0.6, 0.6]:
			add_box(parent, Vector3(0.12, 0.44, 0.44), pos + _rot(Vector3(0, 0.22, wz), yaw), rubber, false, yaw)


static func billboard(parent: Node3D, pos: Vector3, face: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := atan2(face.x, face.z)
	add_box(parent, Vector3(0.16, 4.0, 0.16), pos + Vector3(0, 2.0, 0), mat(Color(0.3, 0.3, 0.32)), false)
	var board := mat(Color(rng.randf_range(0.6, 1.0), rng.randf_range(0.2, 0.7), rng.randf_range(0.1, 0.4)))
	add_box(parent, Vector3(2.8, 1.5, 0.12), pos + Vector3(0, 3.8, 0), board, false, yaw)


static func compound_wall(parent: Node3D, pos: Vector3, along: Vector3, length: float) -> void:
	## Plastered compound wall; walls longer than 10 m get a central gate between two pillars.
	var yaw := atan2(along.x, along.z)
	var plaster := mat(Color(0.72, 0.68, 0.58))
	var coping := mat(Color(0.45, 0.42, 0.38))
	if length <= 10.0:
		add_box(parent, Vector3(0.22, 1.45, length), pos + Vector3(0, 0.72, 0), plaster, true, yaw)
		add_box(parent, Vector3(0.3, 0.18, length + 0.08), pos + Vector3(0, 1.5, 0), coping, false, yaw)
		return
	var gap := 2.6
	var seg := (length - gap) * 0.5
	for side in [-1.0, 1.0]:
		var seg_center := pos + _rot(Vector3(0, 0, side * (gap * 0.5 + seg * 0.5)), yaw)
		add_box(parent, Vector3(0.22, 1.45, seg), seg_center + Vector3(0, 0.72, 0), plaster, true, yaw)
		add_box(parent, Vector3(0.3, 0.18, seg + 0.08), seg_center + Vector3(0, 1.5, 0), coping, false, yaw)
		# Gate pillar (1.2 m clear of the wall top, square plan) with a small cap
		var pillar_pos := pos + _rot(Vector3(0, 0, side * (gap * 0.5 + 0.2)), yaw)
		add_box(parent, Vector3(0.4, 1.9, 0.4), pillar_pos + Vector3(0, 0.95, 0), plaster, true, yaw)
		add_box(parent, Vector3(0.5, 0.12, 0.5), pillar_pos + Vector3(0, 1.96, 0), coping, false, yaw)
	# Dark steel gate panel (visual only — lets jobs path through later if needed)
	add_box(parent, Vector3(0.08, 1.6, gap - 0.5), pos + Vector3(0, 0.82, 0), mat(Color(0.16, 0.17, 0.19), 0.55, 0.4), false, yaw)
	add_box(parent, Vector3(0.1, 0.08, gap - 0.5), pos + Vector3(0, 1.58, 0), mat(Color(0.12, 0.12, 0.14), 0.5, 0.4), false, yaw)


static func filled_lot(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator, with_shed: bool = true) -> void:
	## Courtyard plot: packed earth, 3–4 compound walls, optional shed/tree/parked stub.
	var ground := Vector3(pos.x, pos.y, pos.z)
	var w := rng.randf_range(12.0, 22.0)
	var d := rng.randf_range(10.0, 18.0)
	var floor_colors: Array[Color] = [
		Color(0.42, 0.4, 0.36),
		Color(0.35, 0.42, 0.28),
		Color(0.5, 0.45, 0.35),
		Color(0.38, 0.36, 0.32),
	]
	var floor_c: Color = floor_colors[rng.randi_range(0, floor_colors.size() - 1)]
	var plaster := mat(Color(0.72, 0.68, 0.58))
	var coping := mat(Color(0.45, 0.42, 0.38))
	add_box(parent, Vector3(w, 0.06, d), ground + Vector3(0, 0.03, 0), mat(floor_c), false)
	# Four sides — leave a gate gap on +Z (street-facing) for longer plots
	var wall_h := 1.4
	add_box(parent, Vector3(0.22, wall_h, d), ground + Vector3(-w * 0.48, wall_h * 0.5, 0), plaster, true)
	add_box(parent, Vector3(0.22, wall_h, d), ground + Vector3(w * 0.48, wall_h * 0.5, 0), plaster, true)
	add_box(parent, Vector3(w, wall_h, 0.22), ground + Vector3(0, wall_h * 0.5, -d * 0.48), plaster, true)
	add_box(parent, Vector3(0.28, 0.16, d + 0.1), ground + Vector3(-w * 0.48, wall_h + 0.05, 0), coping, false)
	add_box(parent, Vector3(0.28, 0.16, d + 0.1), ground + Vector3(w * 0.48, wall_h + 0.05, 0), coping, false)
	add_box(parent, Vector3(w + 0.1, 0.16, 0.28), ground + Vector3(0, wall_h + 0.05, -d * 0.48), coping, false)
	# Front wall with gate
	var gap := 2.8
	var seg := (w - gap) * 0.5
	for side_i in 2:
		var side: float = -1.0 if side_i == 0 else 1.0
		var cx: float = side * (gap * 0.5 + seg * 0.5)
		add_box(parent, Vector3(seg, wall_h, 0.22), ground + Vector3(cx, wall_h * 0.5, d * 0.48), plaster, true)
		add_box(parent, Vector3(0.4, 1.85, 0.4), ground + Vector3(side * (gap * 0.5 + 0.15), 0.92, d * 0.48), plaster, true)
	add_box(parent, Vector3(gap - 0.4, 1.55, 0.08), ground + Vector3(0, 0.8, d * 0.48), mat(Color(0.16, 0.17, 0.19), 0.55, 0.4), false)
	if with_shed and rng.randf() < 0.55:
		var shed_h := rng.randf_range(2.6, 3.8)
		var shed_size := Vector3(rng.randf_range(3.5, 6.0), shed_h, rng.randf_range(3.5, 5.5))
		var shed_ground := ground + Vector3(rng.randf_range(-w * 0.25, w * 0.25), 0.0, rng.randf_range(-d * 0.25, 0.0))
		add_box(parent, shed_size, _center_on_ground(shed_size, shed_ground), mat(Color(0.65, 0.5, 0.35)), true)
	if rng.randf() < 0.55:
		tree(parent, ground + Vector3(rng.randf_range(-w * 0.3, w * 0.3), 0.0, rng.randf_range(-d * 0.3, d * 0.1)), rng)
	if rng.randf() < 0.35:
		parked_stub(parent, ground + Vector3(rng.randf_range(-2.0, 2.0), 0.0, d * 0.15), Vector3(0, 0, 1), rng)
	if rng.randf() < 0.4:
		dustbin_pair(parent, ground + Vector3(w * 0.35, 0.0, d * 0.35), rng.randf() * TAU)


static func water_tower(parent: Node3D, pos: Vector3) -> void:
	## Overhead tank: central concrete column (only collider), 4 thin legs, cylindrical tank.
	var concrete := mat(Color(0.55, 0.55, 0.58), 0.6, 0.2)
	var tank := mat(Color(0.42, 0.5, 0.58), 0.45, 0.15)
	add_box(parent, Vector3(1.1, 9.0, 1.1), pos + Vector3(0, 4.5, 0), concrete, true)
	for lx in [-1.6, 1.6]:
		for lz in [-1.6, 1.6]:
			_cylinder(parent, 0.14, 9.2, pos + Vector3(lx, 0, lz), concrete)
	add_box(parent, Vector3(3.6, 0.2, 3.6), pos + Vector3(0, 9.1, 0), concrete, false)
	_cylinder(parent, 2.2, 2.6, pos + Vector3(0, 9.2, 0), tank)
	_cylinder(parent, 2.3, 0.25, pos + Vector3(0, 11.8, 0), mat(Color(0.2, 0.2, 0.22)))
	_cylinder(parent, 0.12, 1.2, pos + Vector3(0, 12.0, 0), concrete)


static func bus_stop(parent: Node3D, pos: Vector3, along: Vector3) -> void:
	## Steel-frame shelter with bench and MSRTC-style blue signboard. No collision.
	var yaw := atan2(along.x, along.z)
	var steel := mat(Color(0.3, 0.3, 0.32), 0.5, 0.3)
	var blue := mat(Color(0.1, 0.35, 0.75), 0.6)
	add_box(parent, Vector3(0.12, 2.4, 0.12), pos + _rot(Vector3(0, 1.2, 1.5), yaw), steel, false, yaw)
	add_box(parent, Vector3(0.12, 2.4, 0.12), pos + _rot(Vector3(0, 1.2, -1.5), yaw), steel, false, yaw)
	add_box(parent, Vector3(1.3, 0.1, 3.3), pos + _rot(Vector3(0.15, 2.45, 0), yaw), mat(Color(0.15, 0.45, 0.75)), false, yaw)
	add_box(parent, Vector3(0.1, 1.1, 3.3), pos + _rot(Vector3(-0.6, 1.85, 0), yaw), mat(Color(0.75, 0.75, 0.78, 0.45), 0.1, 0.05), false, yaw)
	# Bench slab on two legs
	add_box(parent, Vector3(0.45, 0.08, 2.4), pos + _rot(Vector3(-0.2, 0.48, 0), yaw), mat(Color(0.55, 0.42, 0.25), 0.85), false, yaw)
	for bz in [-1.0, 1.0]:
		add_box(parent, Vector3(0.4, 0.44, 0.08), pos + _rot(Vector3(-0.2, 0.22, bz), yaw), steel, false, yaw)
	# Signboard on the shelter end: blue with a yellow stripe
	add_box(parent, Vector3(0.06, 0.55, 1.6), pos + _rot(Vector3(0.1, 2.95, 0), yaw), blue, false, yaw)
	add_box(parent, Vector3(0.07, 0.1, 1.5), pos + _rot(Vector3(0.1, 2.78, 0), yaw), mat(Color(0.95, 0.8, 0.15), 0.6), false, yaw)
	add_box(parent, Vector3(0.1, 0.5, 0.1), pos + _rot(Vector3(0.1, 2.5, 0), yaw), steel, false, yaw)


static func market_stall(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	## Wooden counter, striped cloth canopy on 4 posts, produce crates. No collision.
	var yaw := rng.randf() * TAU
	add_box(parent, Vector3(2.2, 0.65, 1.3), pos + Vector3(0, 0.5, 0), mat(Color(0.55, 0.35, 0.2)), false, yaw)
	var cloth_a := mat(Color(rng.randf_range(0.7, 1.0), rng.randf_range(0.2, 0.6), 0.15))
	var cloth_b := mat(Color(0.95, 0.93, 0.86))
	var stripes := 6
	var stripe_w := 2.4 / float(stripes)
	for s in stripes:
		var sx := -1.2 + stripe_w * (float(s) + 0.5)
		var cm := cloth_a if s % 2 == 0 else cloth_b
		add_box(parent, Vector3(stripe_w, 0.06, 1.6), pos + _rot(Vector3(sx, 1.95, 0), yaw), cm, false, yaw)
	for ox in [-1.0, 1.0]:
		for oz in [-0.6, 0.6]:
			add_box(parent, Vector3(0.08, 1.85, 0.08), pos + _rot(Vector3(ox, 0.9, oz), yaw), mat(Color(0.4, 0.3, 0.2)), false, yaw)
	var produce: Array[Color] = [
		Color(0.85, 0.2, 0.12), # tomato
		Color(0.25, 0.55, 0.2), # bhindi / greens
		Color(0.95, 0.65, 0.1), # mango / lemon
		Color(0.55, 0.25, 0.45), # brinjal
		Color(0.9, 0.85, 0.5), # onion / banana
	]
	var crates := rng.randi_range(3, 4)
	for i in crates:
		var cx := -0.75 + float(i) * (1.5 / float(crates - 1))
		var cz := rng.randf_range(-0.3, 0.3)
		var crate_size := Vector3(rng.randf_range(0.38, 0.5), rng.randf_range(0.22, 0.32), rng.randf_range(0.38, 0.5))
		add_box(parent, crate_size, pos + _rot(Vector3(cx, 0.825 + crate_size.y * 0.5, cz), yaw), mat(Color(0.6, 0.45, 0.25), 0.9), false, yaw)
		var pc: Color = produce[rng.randi_range(0, produce.size() - 1)]
		add_box(parent, crate_size * Vector3(0.85, 0.5, 0.85), pos + _rot(Vector3(cx, 0.825 + crate_size.y + 0.05, cz), yaw), mat(pc, 0.75), false, yaw)


static func osm_footprint(parent: Node3D, pos: Vector3, size_xz: Vector2, height: float, wall: Material) -> void:
	## Axis-aligned OSM building footprint (designed height, real plan size).
	var ground := Vector3(pos.x, pos.y, pos.z)
	var h := clampf(height, 4.0, 22.0)
	var body := Vector3(size_xz.x, h, size_xz.y)
	add_box(parent, body, _center_on_ground(body, ground), wall, true)
	add_box(
		parent,
		Vector3(size_xz.x + 0.2, 0.18, size_xz.y + 0.2),
		ground + Vector3(0, h + 0.08, 0),
		mat(Color(0.42, 0.38, 0.34)),
		false
	)
	if h > 6.0:
		var glass := mat(Color(0.4, 0.5, 0.6, 0.45), 0.08, 0.04)
		add_box(
			parent,
			Vector3(size_xz.x * 0.7, 0.9, 0.06),
			ground + Vector3(0, 2.2, size_xz.y * 0.5),
			glass,
			false
		)


static func osm_patch(parent: Node3D, pos: Vector3, size_xz: Vector2, surface: Material) -> void:
	add_box(parent, Vector3(size_xz.x, 0.05, size_xz.y), pos + Vector3(0, 0.02, 0), surface, false)


static func water_body(parent: Node3D, pos: Vector3, size_xz: Vector2) -> void:
	## River/pond with soft shore — not a bright blue floating slab.
	var w := clampf(size_xz.x, 10.0, 96.0)
	var d := clampf(size_xz.y, 10.0, 96.0)
	var water := mat(Color(0.18, 0.32, 0.38, 0.88), 0.22, 0.15)
	var deep := mat(Color(0.12, 0.24, 0.3, 0.92), 0.18, 0.2)
	var mud := mat(Color(0.38, 0.34, 0.26), 0.92)
	var reed := mat(Color(0.28, 0.38, 0.2), 0.9)
	# Slightly sunk so wheels don't look like they float on paint
	add_box(parent, Vector3(w + 4.0, 0.06, d + 4.0), pos + Vector3(0, -0.02, 0), mud, false)
	add_box(parent, Vector3(w, 0.04, d), pos + Vector3(0, 0.01, 0), water, false)
	add_box(parent, Vector3(w * 0.72, 0.03, d * 0.72), pos + Vector3(0, 0.02, 0), deep, false)
	# Sparse reed clumps on shore (visual only)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(pos.x * 17.0 + pos.z * 31.0)) % 999983
	for i in rng.randi_range(2, 5):
		var ang := rng.randf() * TAU
		var r := maxf(w, d) * 0.48
		var rp := pos + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		add_box(parent, Vector3(0.35, 0.55, 0.35), rp + Vector3(0, 0.28, 0), reed, false)


static func utility_pole(parent: Node3D, pos: Vector3) -> void:
	## Short concrete pole — grounded, no floating tip.
	add_box(parent, Vector3(0.18, 5.2, 0.18), pos + Vector3(0, 2.6, 0), mat(Color(0.55, 0.52, 0.48), 0.85), false)
	add_box(parent, Vector3(1.4, 0.08, 0.08), pos + Vector3(0.5, 5.0, 0), mat(Color(0.25, 0.25, 0.26), 0.5), false)


static func roadside_shrine(parent: Node3D, pos: Vector3, along: Vector3) -> void:
	## Small roadside shrine (designed scenery).
	var yaw := atan2(along.x, along.z)
	var saffron := mat(Color(0.9, 0.55, 0.12))
	var white := mat(Color(0.9, 0.88, 0.82))
	add_box(parent, Vector3(1.4, 0.2, 1.1), pos + Vector3(0, 0.1, 0), mat(Color(0.55, 0.5, 0.42)), false, yaw)
	add_box(parent, Vector3(1.1, 1.3, 0.85), pos + Vector3(0, 0.85, 0), white, false, yaw)
	add_box(parent, Vector3(1.25, 0.15, 1.0), pos + Vector3(0, 1.55, 0), saffron, false, yaw)
	add_box(parent, Vector3(0.35, 0.45, 0.2), pos + Vector3(0, 1.9, 0), saffron, false, yaw)
	add_box(parent, Vector3(0.08, 0.9, 0.08), pos + Vector3(0.55, 0.55, 0.35), mat(Color(0.75, 0.15, 0.1)), false, yaw)


static func chai_stall(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf() * TAU
	add_box(parent, Vector3(1.8, 0.9, 1.1), pos + Vector3(0, 0.55, 0), mat(Color(0.35, 0.22, 0.12)), false, yaw)
	add_box(parent, Vector3(2.0, 0.06, 1.3), pos + Vector3(0, 1.85, 0), mat(Color(0.15, 0.45, 0.35)), false, yaw)
	add_box(parent, Vector3(0.55, 0.45, 0.45), pos + Vector3(0.4, 1.15, 0), mat(Color(0.7, 0.7, 0.72), 0.4, 0.3), false, yaw)
	add_box(parent, Vector3(0.08, 1.75, 0.08), pos + Vector3(-0.85, 0.9, -0.5), mat(Color(0.4, 0.3, 0.2)), false, yaw)
	add_box(parent, Vector3(0.08, 1.75, 0.08), pos + Vector3(0.85, 0.9, -0.5), mat(Color(0.4, 0.3, 0.2)), false, yaw)
	add_box(parent, Vector3(0.08, 1.75, 0.08), pos + Vector3(-0.85, 0.9, 0.5), mat(Color(0.4, 0.3, 0.2)), false, yaw)
	add_box(parent, Vector3(0.08, 1.75, 0.08), pos + Vector3(0.85, 0.9, 0.5), mat(Color(0.4, 0.3, 0.2)), false, yaw)


static func auto_rickshaw(parent: Node3D, pos: Vector3, along: Vector3, rng: RandomNumberGenerator) -> void:
	## Blocky auto silhouette for street colour (Phase 1 prop — not Phase 2 hero).
	var yaw := atan2(along.x, along.z)
	var body_cols: Array[Color] = [
		Color(0.95, 0.75, 0.1),
		Color(0.15, 0.55, 0.35),
		Color(0.1, 0.35, 0.7),
	]
	var c: Color = body_cols[rng.randi_range(0, body_cols.size() - 1)]
	add_box(parent, Vector3(1.25, 1.15, 2.2), pos + Vector3(0, 0.85, 0), mat(c, 0.45), false, yaw)
	add_box(parent, Vector3(1.15, 0.55, 0.9), pos + Vector3(0, 1.55, -0.35), mat(Color(0.4, 0.55, 0.65, 0.45), 0.1, 0.05), false, yaw)
	add_box(parent, Vector3(0.35, 0.35, 0.18), pos + Vector3(0, 0.55, 1.15), mat(Color(0.2, 0.2, 0.22)), false, yaw)


static func hoarding(parent: Node3D, pos: Vector3, face: Vector3, rng: RandomNumberGenerator) -> void:
	## Large 6 x 3 m roadside hoarding on two poles; panel faces `face`. No collision.
	var yaw := atan2(face.x, face.z)
	var steel := mat(Color(0.3, 0.31, 0.34), 0.5, 0.35)
	var panel_bottom := 4.0
	for px in [-2.6, 2.6]:
		_cylinder(parent, 0.11, panel_bottom + 2.7, pos + _rot(Vector3(px, 0, -0.2), yaw), steel)
	# Back frame + panel
	add_box(parent, Vector3(6.2, 3.2, 0.12), pos + _rot(Vector3(0, panel_bottom + 1.5, -0.12), yaw), steel, false, yaw)
	var hue := rng.randf()
	var panel := mat(Color.from_hsv(hue, rng.randf_range(0.7, 0.95), rng.randf_range(0.75, 0.95)), 0.55)
	add_box(parent, Vector3(6.0, 3.0, 0.08), pos + _rot(Vector3(0, panel_bottom + 1.5, 0), yaw), panel, false, yaw)
	# White text bar + a contrasting accent block (stand-in for logo / product shot)
	add_box(parent, Vector3(5.2, 0.55, 0.05), pos + _rot(Vector3(0, panel_bottom + 0.75, 0.07), yaw), mat(Color(0.97, 0.97, 0.95), 0.5), false, yaw)
	var accent := mat(Color.from_hsv(fmod(hue + 0.5, 1.0), 0.6, 0.9), 0.55)
	add_box(parent, Vector3(1.6, 1.4, 0.05), pos + _rot(Vector3(-1.9, panel_bottom + 2.0, 0.07), yaw), accent, false, yaw)
	# Cross-brace behind the panel
	add_box(parent, Vector3(5.4, 0.08, 0.08), pos + _rot(Vector3(0, panel_bottom - 0.4, -0.2), yaw), steel, false, yaw)


static func dustbin_pair(parent: Node3D, pos: Vector3, yaw: float) -> void:
	## Twin municipal bins (green wet / blue dry) on a shared stand. No collision.
	var steel := mat(Color(0.35, 0.36, 0.38), 0.5, 0.3)
	var bin_cols: Array[Color] = [Color(0.15, 0.5, 0.22), Color(0.12, 0.38, 0.75)]
	for i in 2:
		var bx := -0.42 if i == 0 else 0.42
		var bin_pos := pos + _rot(Vector3(bx, 0.25, 0), yaw)
		_add_mesh(parent, _unit_cylinder(), bin_pos + Vector3(0, 0.4, 0), mat(bin_cols[i], 0.6), Vector3(0.28, 0.8, 0.28), yaw)
		_add_mesh(parent, _unit_cylinder(), bin_pos + Vector3(0, 0.83, 0), mat(bin_cols[i].darkened(0.25), 0.6), Vector3(0.3, 0.06, 0.3), yaw)
	for sx in [-0.9, 0.9]:
		add_box(parent, Vector3(0.06, 1.1, 0.06), pos + _rot(Vector3(sx, 0.55, 0), yaw), steel, false, yaw)
	add_box(parent, Vector3(1.86, 0.06, 0.06), pos + _rot(Vector3(0, 1.08, 0), yaw), steel, false, yaw)
	add_box(parent, Vector3(1.0, 0.06, 0.06), pos + _rot(Vector3(0, 0.26, 0), yaw), steel, false, yaw)
