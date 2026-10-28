extends RefCounted
## Own Indian street props — shared materials, fewer decorative collisions.


static var _mat_cache: Dictionary = {}


static func mat(color: Color, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(false), rough, metal]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	_mat_cache[key] = m
	return m


static func add_box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, with_collision: bool = false, yaw: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation.y = yaw
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


static func shop_row(
	parent: Node3D,
	origin: Vector3,
	along: Vector3,
	outward: Vector3,
	count: int,
	rng: RandomNumberGenerator,
	palette: Array
) -> void:
	var cursor := origin
	var glass := mat(Color(0.45, 0.55, 0.65, 0.55), 0.08, 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var roof_mat := mat(Color(0.35, 0.32, 0.3), 0.85)
	var concrete := mat(Color(0.55, 0.53, 0.48), 0.95)
	var wood := mat(Color(0.28, 0.16, 0.1))
	var awning_mat := mat(Color(0.12, 0.32, 0.55))

	for _i in count:
		var w := rng.randf_range(5.5, 9.0)
		var d := rng.randf_range(5.5, 8.5)
		var floors := rng.randi_range(1, 3)
		var h := 3.2 + float(floors) * 2.5
		var wall: Material = palette[rng.randi_range(0, palette.size() - 1)]
		var center := cursor + outward * (d * 0.5 + 0.5)
		var yaw := atan2(along.x, along.z)

		# Collision only on main shell (decor is visual)
		add_box(parent, Vector3(w, h, d), center + Vector3(0, h * 0.5, 0), wall, true, yaw)
		add_box(parent, Vector3(w + 0.3, 0.22, d + 0.3), center + Vector3(0, h + 0.08, 0), roof_mat, false, yaw)

		var face := center - outward * (d * 0.5 + 0.02)
		for fy in range(floors):
			var wy := 1.55 + float(fy) * 2.5
			for fx in [-1, 1]:
				add_box(
					parent,
					Vector3(1.05, 1.1, 0.06),
					face + along * (float(fx) * (w * 0.28)) + Vector3(0, wy, 0),
					glass,
					false,
					yaw
				)

		add_box(parent, Vector3(w + 0.4, 0.1, 1.8), cursor + outward * 1.0 + Vector3(0, 0.05, 0), mat(Color(0.58, 0.56, 0.5)), false, yaw)
		var board := mat(Color(rng.randf_range(0.7, 1.0), rng.randf_range(0.15, 0.5), rng.randf_range(0.05, 0.25)))
		add_box(parent, Vector3(w * 0.88, 0.65, 0.18), cursor + outward * 0.12 + Vector3(0, 2.55, 0), board, false, yaw)
		add_box(parent, Vector3(w * 0.85, 0.07, 1.2), cursor + outward * 0.7 + Vector3(0, 2.1, 0), awning_mat, false, yaw)
		add_box(parent, Vector3(1.1, 2.05, 0.08), cursor + outward * 0.05 + Vector3(0, 1.02, 0), wood, false, yaw)

		cursor += along * (w + rng.randf_range(0.5, 1.2))


static func lamp(parent: Node3D, pos: Vector3) -> void:
	add_box(parent, Vector3(0.14, 4.8, 0.14), pos + Vector3(0, 2.4, 0), mat(Color(0.32, 0.32, 0.35), 0.5), false)
	var lamp_mat := mat(Color(0.95, 0.9, 0.55), 0.35)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.92, 0.6)
	lamp_mat.emission_energy_multiplier = 1.4
	add_box(parent, Vector3(0.45, 0.2, 0.45), pos + Vector3(0, 4.9, 0), lamp_mat, false)


static func tree(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	add_box(parent, Vector3(0.3, 1.5, 0.3), pos + Vector3(0, 0.75, 0), mat(Color(0.34, 0.2, 0.1)), false)
	var canopy := rng.randf_range(1.7, 2.4)
	add_box(parent, Vector3(canopy, canopy * 0.8, canopy), pos + Vector3(0, 2.2, 0), mat(Color(0.16, 0.4, 0.18)), false)


static func parked_stub(parent: Node3D, pos: Vector3, along: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := atan2(along.x, along.z)
	var colors: Array[Color] = [
		Color(0.75, 0.2, 0.15),
		Color(0.15, 0.25, 0.55),
		Color(0.85, 0.85, 0.82),
		Color(0.2, 0.2, 0.22),
		Color(0.8, 0.55, 0.1),
	]
	var c: Color = colors[rng.randi_range(0, colors.size() - 1)]
	add_box(parent, Vector3(1.65, 0.5, 3.4), pos + Vector3(0, 0.42, 0), mat(c, 0.5), false, yaw)
	add_box(parent, Vector3(1.45, 0.4, 1.5), pos + Vector3(0, 0.9, -0.15), mat(c, 0.5), false, yaw)


static func billboard(parent: Node3D, pos: Vector3, face: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := atan2(face.x, face.z)
	add_box(parent, Vector3(0.16, 4.0, 0.16), pos + Vector3(0, 2.0, 0), mat(Color(0.3, 0.3, 0.32)), false)
	var board := mat(Color(rng.randf_range(0.6, 1.0), rng.randf_range(0.2, 0.7), rng.randf_range(0.1, 0.4)))
	add_box(parent, Vector3(2.8, 1.5, 0.12), pos + Vector3(0, 3.8, 0), board, false, yaw)


static func compound_wall(parent: Node3D, pos: Vector3, along: Vector3, length: float) -> void:
	var yaw := atan2(along.x, along.z)
	add_box(parent, Vector3(0.22, 1.45, length), pos + Vector3(0, 0.72, 0), mat(Color(0.72, 0.68, 0.58)), true, yaw)
	add_box(parent, Vector3(0.3, 0.18, length + 0.08), pos + Vector3(0, 1.5, 0), mat(Color(0.45, 0.42, 0.38)), false, yaw)


static func filled_lot(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var w := rng.randf_range(12.0, 22.0)
	var d := rng.randf_range(10.0, 18.0)
	var floor_colors: Array[Color] = [
		Color(0.42, 0.4, 0.36),
		Color(0.35, 0.42, 0.28),
		Color(0.5, 0.45, 0.35),
	]
	var floor_c: Color = floor_colors[rng.randi_range(0, floor_colors.size() - 1)]
	add_box(parent, Vector3(w, 0.06, d), pos + Vector3(0, 0.03, 0), mat(floor_c), false)
	add_box(parent, Vector3(0.2, 1.35, d), pos + Vector3(w * 0.48, 0.67, 0), mat(Color(0.7, 0.66, 0.56)), true)
	add_box(parent, Vector3(w, 1.35, 0.2), pos + Vector3(0, 0.67, d * 0.48), mat(Color(0.7, 0.66, 0.56)), true)
	if rng.randf() < 0.4:
		var shed_h := rng.randf_range(2.6, 3.8)
		add_box(
			parent,
			Vector3(rng.randf_range(3.5, 6.0), shed_h, rng.randf_range(3.5, 5.5)),
			pos + Vector3(rng.randf_range(-2.0, 2.0), shed_h * 0.5, rng.randf_range(-1.5, 1.5)),
			mat(Color(0.65, 0.5, 0.35)),
			true
		)


static func water_tower(parent: Node3D, pos: Vector3) -> void:
	add_box(parent, Vector3(1.1, 9.0, 1.1), pos + Vector3(0, 4.5, 0), mat(Color(0.55, 0.55, 0.58), 0.6, 0.2), true)
	add_box(parent, Vector3(4.2, 2.8, 4.2), pos + Vector3(0, 10.4, 0), mat(Color(0.25, 0.45, 0.7), 0.45), true)
	add_box(parent, Vector3(4.5, 0.3, 4.5), pos + Vector3(0, 11.9, 0), mat(Color(0.2, 0.2, 0.22)), false)


static func bus_stop(parent: Node3D, pos: Vector3, along: Vector3) -> void:
	var yaw := atan2(along.x, along.z)
	add_box(parent, Vector3(0.12, 2.4, 0.12), pos + Vector3(1.5, 1.2, 0), mat(Color(0.3, 0.3, 0.32)), false, yaw)
	add_box(parent, Vector3(0.12, 2.4, 0.12), pos + Vector3(-1.5, 1.2, 0), mat(Color(0.3, 0.3, 0.32)), false, yaw)
	add_box(parent, Vector3(3.3, 0.1, 1.3), pos + Vector3(0, 2.45, 0.15), mat(Color(0.15, 0.45, 0.75)), false, yaw)
	add_box(parent, Vector3(3.1, 0.08, 0.85), pos + Vector3(0, 0.95, 0.1), mat(Color(0.45, 0.35, 0.2)), false, yaw)
	add_box(parent, Vector3(1.6, 0.55, 0.06), pos + Vector3(0, 2.95, 0.08), mat(Color(0.1, 0.35, 0.75)), false, yaw)


static func market_stall(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf() * TAU
	add_box(parent, Vector3(2.2, 0.65, 1.3), pos + Vector3(0, 0.5, 0), mat(Color(0.55, 0.35, 0.2)), false, yaw)
	var cloth := mat(Color(rng.randf_range(0.7, 1.0), rng.randf_range(0.2, 0.6), 0.15))
	add_box(parent, Vector3(2.4, 0.06, 1.6), pos + Vector3(0, 1.95, 0), cloth, false, yaw)
	for ox in [-1.0, 1.0]:
		for oz in [-0.6, 0.6]:
			add_box(parent, Vector3(0.08, 1.85, 0.08), pos + Vector3(ox, 0.9, oz), mat(Color(0.4, 0.3, 0.2)), false, yaw)
