extends RefCounted
## Original low-poly vehicle meshes + body kits (no paid / ripped assets).


static func clear_children(node: Node) -> void:
	## queue_free avoids "material is null" spam when kit meshes tear down mid-frame.
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func mat(color: Color, rough: float = 0.45, metal: float = 0.15, emission: Color = Color(0, 0, 0, 0), emit_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emit_energy
	return m


static func add_box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, yaw: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


static func build_sedan(root: Node3D, paint: StandardMaterial3D, kit: int = 0) -> Vector3:
	clear_children(root)
	var glass := mat(Color(0.35, 0.5, 0.65, 0.55), 0.05, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var dark := mat(Color(0.08, 0.08, 0.09), 0.7, 0.2)
	var chrome := mat(Color(0.75, 0.75, 0.78), 0.25, 0.85)
	var light_f := mat(Color(1, 0.95, 0.75), 0.2, 0.0, Color(1, 0.95, 0.7), 1.4)
	var light_r := mat(Color(0.85, 0.1, 0.08), 0.35, 0.0, Color(0.9, 0.1, 0.05), 1.2)
	var rubber := mat(Color(0.12, 0.12, 0.12), 0.95, 0.0)
	var accent := mat(Color(0.05, 0.05, 0.06), 0.55, 0.4)

	add_box(root, Vector3(1.85, 0.55, 4.15), Vector3(0, 0.48, 0), paint)
	add_box(root, Vector3(1.7, 0.22, 1.15), Vector3(0, 0.82, 1.25), paint)
	add_box(root, Vector3(1.65, 0.7, 1.7), Vector3(0, 1.15, -0.15), paint)
	add_box(root, Vector3(1.7, 0.35, 0.95), Vector3(0, 0.85, -1.55), paint)
	add_box(root, Vector3(1.45, 0.08, 1.4), Vector3(0, 1.55, -0.2), paint)
	add_box(root, Vector3(1.55, 0.5, 0.08), Vector3(0, 1.2, 0.72), glass)
	add_box(root, Vector3(1.55, 0.45, 0.08), Vector3(0, 1.15, -1.05), glass)
	add_box(root, Vector3(0.08, 0.45, 1.35), Vector3(0.84, 1.15, -0.15), glass)
	add_box(root, Vector3(0.08, 0.45, 1.35), Vector3(-0.84, 1.15, -0.15), glass)
	add_box(root, Vector3(1.9, 0.28, 0.28), Vector3(0, 0.38, 2.15), dark)
	add_box(root, Vector3(1.9, 0.28, 0.28), Vector3(0, 0.38, -2.15), dark)
	add_box(root, Vector3(0.7, 0.22, 0.08), Vector3(0, 0.55, 2.28), chrome)
	add_box(root, Vector3(0.35, 0.18, 0.12), Vector3(0.65, 0.55, 2.25), light_f)
	add_box(root, Vector3(0.35, 0.18, 0.12), Vector3(-0.65, 0.55, 2.25), light_f)
	add_box(root, Vector3(0.4, 0.16, 0.1), Vector3(0.6, 0.55, -2.25), light_r)
	add_box(root, Vector3(0.4, 0.16, 0.1), Vector3(-0.6, 0.55, -2.25), light_r)
	add_box(root, Vector3(0.22, 0.1, 0.18), Vector3(1.05, 1.05, 0.55), dark)
	add_box(root, Vector3(0.22, 0.1, 0.18), Vector3(-1.05, 1.05, 0.55), dark)
	add_box(root, Vector3(0.45, 0.14, 0.04), Vector3(0, 0.4, 2.32), rubber)

	# Kits: 0 stock, 1 spoiler, 2 roof rack, 3 sport (skirts + stripe)
	if kit == 1 or kit == 3:
		add_box(root, Vector3(1.2, 0.12, 0.45), Vector3(0, 1.35, -1.85), accent)
		add_box(root, Vector3(0.15, 0.25, 0.35), Vector3(0.45, 1.2, -1.75), accent)
		add_box(root, Vector3(0.15, 0.25, 0.35), Vector3(-0.45, 1.2, -1.75), accent)
	if kit == 2:
		add_box(root, Vector3(1.35, 0.08, 1.5), Vector3(0, 1.7, -0.2), chrome)
		add_box(root, Vector3(0.08, 0.35, 1.4), Vector3(0.55, 1.55, -0.2), chrome)
		add_box(root, Vector3(0.08, 0.35, 1.4), Vector3(-0.55, 1.55, -0.2), chrome)
	if kit == 3:
		add_box(root, Vector3(0.12, 0.18, 3.6), Vector3(0.95, 0.45, 0), accent)
		add_box(root, Vector3(0.12, 0.18, 3.6), Vector3(-0.95, 0.45, 0), accent)
		add_box(root, Vector3(1.7, 0.08, 0.35), Vector3(0, 0.78, 0.2), accent)

	return Vector3(1.9, 1.2, 4.4)


static func build_van(root: Node3D, paint: StandardMaterial3D, kit: int = 0) -> Vector3:
	clear_children(root)
	var glass := mat(Color(0.35, 0.5, 0.65, 0.55), 0.05, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var dark := mat(Color(0.08, 0.08, 0.09), 0.7, 0.2)
	var chrome := mat(Color(0.75, 0.75, 0.78), 0.25, 0.85)
	var light_f := mat(Color(1, 0.95, 0.75), 0.2, 0.0, Color(1, 0.95, 0.7), 1.4)
	var light_r := mat(Color(0.85, 0.1, 0.08), 0.35, 0.0, Color(0.9, 0.1, 0.05), 1.2)
	var cargo := mat(Color(0.92, 0.92, 0.9), 0.85, 0.05)
	var accent := mat(Color(0.05, 0.05, 0.06), 0.55, 0.4)

	add_box(root, Vector3(2.05, 0.7, 1.6), Vector3(0, 0.55, 1.35), paint)
	add_box(root, Vector3(1.9, 0.85, 1.2), Vector3(0, 1.25, 1.2), paint)
	add_box(root, Vector3(2.15, 1.7, 3.0), Vector3(0, 1.15, -0.85), cargo)
	add_box(root, Vector3(2.05, 0.15, 2.9), Vector3(0, 2.05, -0.85), paint)
	add_box(root, Vector3(2.18, 0.35, 2.6), Vector3(0, 1.2, -0.85), paint)
	add_box(root, Vector3(1.7, 0.55, 0.08), Vector3(0, 1.25, 1.85), glass)
	add_box(root, Vector3(0.08, 0.5, 0.9), Vector3(1.02, 1.2, 1.2), glass)
	add_box(root, Vector3(0.08, 0.5, 0.9), Vector3(-1.02, 1.2, 1.2), glass)
	add_box(root, Vector3(2.1, 0.3, 0.28), Vector3(0, 0.4, 2.2), dark)
	add_box(root, Vector3(2.1, 0.3, 0.28), Vector3(0, 0.4, -2.4), dark)
	add_box(root, Vector3(0.55, 0.2, 0.08), Vector3(0, 0.6, 2.32), chrome)
	add_box(root, Vector3(0.38, 0.18, 0.12), Vector3(0.7, 0.6, 2.28), light_f)
	add_box(root, Vector3(0.38, 0.18, 0.12), Vector3(-0.7, 0.6, 2.28), light_f)
	add_box(root, Vector3(0.45, 0.18, 0.1), Vector3(0.7, 0.7, -2.48), light_r)
	add_box(root, Vector3(0.45, 0.18, 0.1), Vector3(-0.7, 0.7, -2.48), light_r)

	if kit == 1 or kit == 3:
		add_box(root, Vector3(1.6, 0.15, 0.5), Vector3(0, 2.15, -2.2), accent)
	if kit == 2:
		add_box(root, Vector3(1.9, 0.1, 2.4), Vector3(0, 2.25, -0.85), chrome)
		add_box(root, Vector3(0.5, 0.45, 0.5), Vector3(0.6, 2.45, -0.5), dark)
		add_box(root, Vector3(0.5, 0.45, 0.5), Vector3(-0.6, 2.45, -1.2), dark)
	if kit == 3:
		add_box(root, Vector3(2.2, 0.12, 0.4), Vector3(0, 0.55, 0.2), accent)

	return Vector3(2.2, 1.9, 4.9)


static func _add_wheel(parent: Node3D, name: String, pos: Vector3, tire: Material, rim: Material) -> Node3D:
	## Separate identifiable wheel node (tire + alloy) for VehicleWheel3D / export.
	var holder := Node3D.new()
	holder.name = name
	holder.position = pos
	parent.add_child(holder)
	var tire_mi := MeshInstance3D.new()
	tire_mi.name = "Tire"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.34
	cyl.bottom_radius = 0.34
	cyl.height = 0.22
	cyl.radial_segments = 16
	tire_mi.mesh = cyl
	tire_mi.material_override = tire
	tire_mi.rotation_degrees = Vector3(0, 0, 90)
	holder.add_child(tire_mi)
	var rim_mi := MeshInstance3D.new()
	rim_mi.name = "Rim"
	var rim_cyl := CylinderMesh.new()
	rim_cyl.top_radius = 0.22
	rim_cyl.bottom_radius = 0.22
	rim_cyl.height = 0.14
	rim_cyl.radial_segments = 12
	rim_mi.mesh = rim_cyl
	rim_mi.material_override = rim
	rim_mi.rotation_degrees = Vector3(0, 0, 90)
	holder.add_child(rim_mi)
	return holder


static func build_premium_sedan(root: Node3D, paint: StandardMaterial3D = null) -> Vector3:
	## Original Maharashtra-market premium 4-door sedan (no logos/text).
	## Forward = MODEL_FRONT (+Z). Wheels are separate named nodes.
	clear_children(root)
	if paint == null:
		paint = mat(Color(0.12, 0.18, 0.32), 0.28, 0.55) # deep indigo metallic
	var glass := mat(Color(0.18, 0.26, 0.34, 0.42), 0.04, 0.15)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var dark := mat(Color(0.06, 0.06, 0.07), 0.75, 0.25)
	var chrome := mat(Color(0.82, 0.84, 0.86), 0.2, 0.92)
	var black_trim := mat(Color(0.08, 0.08, 0.09), 0.55, 0.35)
	var light_f := mat(Color(0.95, 0.96, 0.98), 0.12, 0.05, Color(0.95, 0.97, 1.0), 1.6)
	var light_r := mat(Color(0.75, 0.08, 0.08), 0.3, 0.05, Color(0.9, 0.05, 0.05), 1.35)
	var fog := mat(Color(0.9, 0.88, 0.8), 0.25, 0.1, Color(1.0, 0.95, 0.8), 0.55)
	var tire := mat(Color(0.08, 0.08, 0.09), 0.92, 0.0)
	var alloy := mat(Color(0.72, 0.74, 0.76), 0.28, 0.88)
	var plastic := mat(Color(0.12, 0.12, 0.13), 0.65, 0.15)

	# Body shell — plausible ~4.65 × 1.82 × 1.48 m sedan proportions
	add_box(root, Vector3(1.82, 0.52, 4.35), Vector3(0, 0.52, 0.02), paint) # lower body
	add_box(root, Vector3(1.72, 0.28, 1.05), Vector3(0, 0.88, 1.35), paint) # hood
	add_box(root, Vector3(1.68, 0.72, 1.85), Vector3(0, 1.18, -0.05), paint) # cabin
	add_box(root, Vector3(1.7, 0.38, 0.95), Vector3(0, 0.92, -1.55), paint) # boot
	add_box(root, Vector3(1.55, 0.06, 1.55), Vector3(0, 1.58, -0.08), paint) # roof
	# Soft shoulder / belt line
	add_box(root, Vector3(1.84, 0.08, 3.6), Vector3(0, 0.78, 0.0), black_trim)
	# Front bumper + grille stack
	add_box(root, Vector3(1.86, 0.32, 0.28), Vector3(0, 0.38, 2.22), dark)
	add_box(root, Vector3(0.95, 0.22, 0.06), Vector3(0, 0.58, 2.34), chrome)
	add_box(root, Vector3(0.72, 0.12, 0.04), Vector3(0, 0.42, 2.36), black_trim)
	add_box(root, Vector3(0.28, 0.1, 0.08), Vector3(0, 0.28, 2.3), plastic) # plate blank (no text)
	# Headlights + DRLs + fog
	add_box(root, Vector3(0.42, 0.2, 0.14), Vector3(0.68, 0.58, 2.28), light_f)
	add_box(root, Vector3(0.42, 0.2, 0.14), Vector3(-0.68, 0.58, 2.28), light_f)
	add_box(root, Vector3(0.22, 0.06, 0.08), Vector3(0.68, 0.48, 2.32), chrome)
	add_box(root, Vector3(0.22, 0.06, 0.08), Vector3(-0.68, 0.48, 2.32), chrome)
	add_box(root, Vector3(0.2, 0.1, 0.1), Vector3(0.72, 0.28, 2.18), fog)
	add_box(root, Vector3(0.2, 0.1, 0.1), Vector3(-0.72, 0.28, 2.18), fog)
	# Rear bumper + lamps + reflector
	add_box(root, Vector3(1.86, 0.3, 0.26), Vector3(0, 0.4, -2.2), dark)
	add_box(root, Vector3(0.48, 0.18, 0.12), Vector3(0.62, 0.62, -2.22), light_r)
	add_box(root, Vector3(0.48, 0.18, 0.12), Vector3(-0.62, 0.62, -2.22), light_r)
	add_box(root, Vector3(1.2, 0.05, 0.06), Vector3(0, 0.48, -2.28), chrome)
	add_box(root, Vector3(0.3, 0.1, 0.06), Vector3(0, 0.3, -2.26), plastic)
	# Glass
	add_box(root, Vector3(1.58, 0.48, 0.06), Vector3(0, 1.22, 0.88), glass) # windscreen
	add_box(root, Vector3(1.55, 0.42, 0.06), Vector3(0, 1.18, -1.0), glass) # rear glass
	add_box(root, Vector3(0.06, 0.42, 0.7), Vector3(0.86, 1.2, 0.35), glass)
	add_box(root, Vector3(0.06, 0.42, 0.7), Vector3(-0.86, 1.2, 0.35), glass)
	add_box(root, Vector3(0.06, 0.4, 0.65), Vector3(0.86, 1.18, -0.45), glass)
	add_box(root, Vector3(0.06, 0.4, 0.65), Vector3(-0.86, 1.18, -0.45), glass)
	# Door seams + handles (four doors)
	for zpos in [0.55, -0.35]:
		add_box(root, Vector3(0.02, 0.55, 0.02), Vector3(0.915, 0.85, zpos), black_trim)
		add_box(root, Vector3(0.02, 0.55, 0.02), Vector3(-0.915, 0.85, zpos), black_trim)
		add_box(root, Vector3(0.12, 0.04, 0.04), Vector3(0.92, 0.95, zpos + 0.2), chrome)
		add_box(root, Vector3(0.12, 0.04, 0.04), Vector3(-0.92, 0.95, zpos + 0.2), chrome)
	# Mirrors
	add_box(root, Vector3(0.22, 0.12, 0.18), Vector3(1.02, 1.08, 0.72), black_trim)
	add_box(root, Vector3(0.22, 0.12, 0.18), Vector3(-1.02, 1.08, 0.72), black_trim)
	add_box(root, Vector3(0.14, 0.1, 0.02), Vector3(1.08, 1.08, 0.78), chrome)
	add_box(root, Vector3(0.14, 0.1, 0.02), Vector3(-1.08, 1.08, 0.78), chrome)
	# Wheel arches (visual lips)
	for zx in [[1.15, 0.95], [1.15, -0.95], [-1.15, 0.95], [-1.15, -0.95]]:
		add_box(root, Vector3(0.08, 0.35, 0.55), Vector3(zx[0], 0.45, zx[1]), paint)
	# Separate wheels — MODEL_FRONT +Z, left = +X to match truck_town naming habit
	_add_wheel(root, "WheelFL", Vector3(0.78, 0.34, 1.35), tire, alloy)
	_add_wheel(root, "WheelFR", Vector3(-0.78, 0.34, 1.35), tire, alloy)
	_add_wheel(root, "WheelRL", Vector3(0.78, 0.34, -1.35), tire, alloy)
	_add_wheel(root, "WheelRR", Vector3(-0.78, 0.34, -1.35), tire, alloy)

	return Vector3(1.9, 1.48, 4.65)
