extends RefCounted
## Own Indian street props — Phase 1 map kits (no paid assets).


static func mat(color: Color, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
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
	var glass := mat(Color(0.45, 0.55, 0.65, 0.65), 0.08, 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var roof_mat := mat(Color(0.35, 0.32, 0.3), 0.85)
	var concrete := mat(Color(0.55, 0.53, 0.48), 0.95)

	for _i in count:
		var w := rng.randf_range(5.5, 9.5)
		var d := rng.randf_range(5.5, 9.0)
		var floors := rng.randi_range(1, 3)
		var h := 3.2 + float(floors) * 2.6
		var wall: Material = palette[rng.randi_range(0, palette.size() - 1)]
		var center := cursor + outward * (d * 0.5 + 0.4)
		var yaw := atan2(along.x, along.z)

		# Main building body
		add_box(parent, Vector3(w, h, d), center + Vector3(0, h * 0.5, 0), wall, true, yaw)
		# Flat roof slab + parapet (common Indian commercial look)
		add_box(parent, Vector3(w + 0.35, 0.25, d + 0.35), center + Vector3(0, h + 0.1, 0), roof_mat, false, yaw)
		add_box(parent, Vector3(w + 0.15, 0.45, 0.2), center - outward * (d * 0.5) + Vector3(0, h + 0.35, 0), concrete, false, yaw)

		# Window grid on street face
		var face := center - outward * (d * 0.5 + 0.02)
		for fy in range(floors):
			var wy := 1.6 + float(fy) * 2.55
			for fx in [-1, 0, 1]:
				if floors == 1 and fy == 0 and fx == 0:
					continue  # leave door area
				add_box(
					parent,
					Vector3(1.1, 1.15, 0.08),
					face + along * (float(fx) * (w * 0.28)) + Vector3(0, wy, 0),
					glass,
					false,
					yaw
				)

		# Ground sidewalk
		add_box(
			parent,
			Vector3(w + 0.5, 0.12, 2.0),
			cursor + outward * 1.0 + Vector3(0, 0.06, 0),
			mat(Color(0.58, 0.56, 0.5)),
			false,
			yaw
		)
		# Bright shop board
		var board := mat(Color(rng.randf_range(0.7, 1.0), rng.randf_range(0.12, 0.55), rng.randf_range(0.05, 0.3)))
		add_box(
			parent,
			Vector3(w * 0.9, 0.75, 0.22),
			cursor + outward * 0.12 + Vector3(0, 2.65, 0),
			board,
			false,
			yaw
		)
		# Awning
		add_box(
			parent,
			Vector3(w * 0.88, 0.08, 1.35),
			cursor + outward * 0.75 + Vector3(0, 2.15, 0),
			mat(Color(0.12, 0.32, 0.55)),
			false,
			yaw
		)
		# Door
		add_box(
			parent,
			Vector3(1.15, 2.15, 0.1),
			cursor + outward * 0.05 + Vector3(0, 1.05, 0),
			mat(Color(0.28, 0.16, 0.1)),
			false,
			yaw
		)
		# Pillar edges
		add_box(parent, Vector3(0.25, h, 0.25), center + along * (w * 0.48) - outward * (d * 0.48) + Vector3(0, h * 0.5, 0), concrete, false, yaw)
		add_box(parent, Vector3(0.25, h, 0.25), center - along * (w * 0.48) - outward * (d * 0.48) + Vector3(0, h * 0.5, 0), concrete, false, yaw)

		cursor += along * (w + rng.randf_range(0.35, 1.1))


static func lamp(parent: Node3D, pos: Vector3) -> void:
	add_box(parent, Vector3(0.16, 5.2, 0.16), pos + Vector3(0, 2.6, 0), mat(Color(0.32, 0.32, 0.35), 0.5))
	var lamp_mat := mat(Color(0.95, 0.9, 0.55), 0.35)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.92, 0.6)
	lamp_mat.emission_energy_multiplier = 1.8
	add_box(parent, Vector3(0.5, 0.22, 0.5), pos + Vector3(0, 5.3, 0), lamp_mat)


static func tree(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	add_box(parent, Vector3(0.32, 1.6, 0.32), pos + Vector3(0, 0.8, 0), mat(Color(0.34, 0.2, 0.1)))
	var canopy := rng.randf_range(1.8, 2.6)
	add_box(parent, Vector3(canopy, canopy * 0.85, canopy), pos + Vector3(0, 2.3, 0), mat(Color(0.16, 0.4, 0.18)))


static func parked_stub(parent: Node3D, pos: Vector3, along: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := atan2(along.x, along.z)
	var colors := [
		Color(0.75, 0.2, 0.15),
		Color(0.15, 0.25, 0.55),
		Color(0.85, 0.85, 0.82),
		Color(0.2, 0.2, 0.22),
		Color(0.8, 0.55, 0.1),
	]
	var c: Color = colors[rng.randi_range(0, colors.size() - 1)]
	add_box(parent, Vector3(1.7, 0.55, 3.6), pos + Vector3(0, 0.45, 0), mat(c, 0.5), false, yaw)
	add_box(parent, Vector3(1.5, 0.45, 1.6), pos + Vector3(0, 0.95, -0.2), mat(c, 0.5), false, yaw)


static func billboard(parent: Node3D, pos: Vector3, face: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := atan2(face.x, face.z)
	add_box(parent, Vector3(0.2, 4.5, 0.2), pos + Vector3(0, 2.25, 0), mat(Color(0.3, 0.3, 0.32)))
	var board := mat(Color(rng.randf_range(0.6, 1.0), rng.randf_range(0.2, 0.7), rng.randf_range(0.1, 0.4)))
	add_box(parent, Vector3(3.2, 1.8, 0.15), pos + Vector3(0, 4.2, 0), board, false, yaw)


static func compound_wall(parent: Node3D, pos: Vector3, along: Vector3, length: float) -> void:
	var yaw := atan2(along.x, along.z)
	add_box(parent, Vector3(0.25, 1.6, length), pos + Vector3(0, 0.8, 0), mat(Color(0.72, 0.68, 0.58)), true, yaw)
	add_box(parent, Vector3(0.35, 0.2, length + 0.1), pos + Vector3(0, 1.65, 0), mat(Color(0.45, 0.42, 0.38)), false, yaw)


static func filled_lot(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	## Turns empty tan ground into a plot: floor + wall + optional shed (axis-aligned).
	var w := rng.randf_range(14.0, 28.0)
	var d := rng.randf_range(12.0, 24.0)
	var floor_colors: Array[Color] = [
		Color(0.42, 0.4, 0.36),
		Color(0.35, 0.42, 0.28),
		Color(0.5, 0.45, 0.35),
		Color(0.38, 0.36, 0.34),
	]
	var floor_c: Color = floor_colors[rng.randi_range(0, floor_colors.size() - 1)]
	add_box(parent, Vector3(w, 0.08, d), pos + Vector3(0, 0.04, 0), mat(floor_c), false)
	add_box(parent, Vector3(0.22, 1.5, d), pos + Vector3(w * 0.48, 0.75, 0), mat(Color(0.7, 0.66, 0.56)), true)
	add_box(parent, Vector3(w, 1.5, 0.22), pos + Vector3(0, 0.75, d * 0.48), mat(Color(0.7, 0.66, 0.56)), true)
	if rng.randf() < 0.55:
		var shed_h := rng.randf_range(2.8, 4.2)
		add_box(
			parent,
			Vector3(rng.randf_range(4.0, 7.0), shed_h, rng.randf_range(4.0, 6.5)),
			pos + Vector3(rng.randf_range(-3.0, 3.0), shed_h * 0.5, rng.randf_range(-2.0, 2.0)),
			mat(Color(0.65, 0.5, 0.35)),
			true
		)


static func water_tower(parent: Node3D, pos: Vector3) -> void:
	add_box(parent, Vector3(1.2, 10.0, 1.2), pos + Vector3(0, 5.0, 0), mat(Color(0.55, 0.55, 0.58), 0.6, 0.2), true)
	add_box(parent, Vector3(4.5, 3.2, 4.5), pos + Vector3(0, 11.5, 0), mat(Color(0.25, 0.45, 0.7), 0.45), true)
	add_box(parent, Vector3(4.8, 0.35, 4.8), pos + Vector3(0, 13.2, 0), mat(Color(0.2, 0.2, 0.22)), false)


static func bus_stop(parent: Node3D, pos: Vector3, along: Vector3) -> void:
	var yaw := atan2(along.x, along.z)
	add_box(parent, Vector3(0.15, 2.6, 0.15), pos + Vector3(1.6, 1.3, 0), mat(Color(0.3, 0.3, 0.32)), false, yaw)
	add_box(parent, Vector3(0.15, 2.6, 0.15), pos + Vector3(-1.6, 1.3, 0), mat(Color(0.3, 0.3, 0.32)), false, yaw)
	add_box(parent, Vector3(3.6, 0.12, 1.4), pos + Vector3(0, 2.65, 0.2), mat(Color(0.15, 0.45, 0.75)), false, yaw)
	add_box(parent, Vector3(3.4, 0.08, 0.9), pos + Vector3(0, 1.0, 0.15), mat(Color(0.45, 0.35, 0.2)), false, yaw)
	# Blue MSRTC-ish board
	add_box(parent, Vector3(1.8, 0.7, 0.08), pos + Vector3(0, 3.2, 0.1), mat(Color(0.1, 0.35, 0.75)), false, yaw)


static func market_stall(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf() * TAU
	add_box(parent, Vector3(2.4, 0.7, 1.4), pos + Vector3(0, 0.55, 0), mat(Color(0.55, 0.35, 0.2)), true, yaw)
	var cloth := mat(Color(rng.randf_range(0.7, 1.0), rng.randf_range(0.2, 0.6), 0.15))
	add_box(parent, Vector3(2.6, 0.08, 1.8), pos + Vector3(0, 2.1, 0), cloth, false, yaw)
	add_box(parent, Vector3(0.1, 2.0, 0.1), pos + Vector3(1.1, 1.0, 0.7), mat(Color(0.4, 0.3, 0.2)), false, yaw)
	add_box(parent, Vector3(0.1, 2.0, 0.1), pos + Vector3(-1.1, 1.0, 0.7), mat(Color(0.4, 0.3, 0.2)), false, yaw)
	add_box(parent, Vector3(0.1, 2.0, 0.1), pos + Vector3(1.1, 1.0, -0.7), mat(Color(0.4, 0.3, 0.2)), false, yaw)
	add_box(parent, Vector3(0.1, 2.0, 0.1), pos + Vector3(-1.1, 1.0, -0.7), mat(Color(0.4, 0.3, 0.2)), false, yaw)
