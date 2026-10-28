extends RefCounted
## Original (own) low-poly vehicle meshes — no paid assets.
## Builds sedan / delivery-van kits with paint + glass + lights.


static func clear_children(node: Node) -> void:
	while node.get_child_count() > 0:
		var c := node.get_child(0)
		node.remove_child(c)
		c.free()


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


static func build_sedan(root: Node3D, paint: StandardMaterial3D) -> Vector3:
	## Returns collision box size used by the body.
	clear_children(root)
	var glass := mat(Color(0.35, 0.5, 0.65, 0.55), 0.05, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var dark := mat(Color(0.08, 0.08, 0.09), 0.7, 0.2)
	var chrome := mat(Color(0.75, 0.75, 0.78), 0.25, 0.85)
	var light_f := mat(Color(1, 0.95, 0.75), 0.2, 0.0, Color(1, 0.95, 0.7), 1.4)
	var light_r := mat(Color(0.85, 0.1, 0.08), 0.35, 0.0, Color(0.9, 0.1, 0.05), 1.2)
	var rubber := mat(Color(0.12, 0.12, 0.12), 0.95, 0.0)

	# Lower body / rocker
	add_box(root, Vector3(1.85, 0.55, 4.15), Vector3(0, 0.48, 0), paint)
	# Hood
	add_box(root, Vector3(1.7, 0.22, 1.15), Vector3(0, 0.82, 1.25), paint)
	# Cabin
	add_box(root, Vector3(1.65, 0.7, 1.7), Vector3(0, 1.15, -0.15), paint)
	# Trunk
	add_box(root, Vector3(1.7, 0.35, 0.95), Vector3(0, 0.85, -1.55), paint)
	# Roof slight
	add_box(root, Vector3(1.45, 0.08, 1.4), Vector3(0, 1.55, -0.2), paint)
	# Windows
	add_box(root, Vector3(1.55, 0.5, 0.08), Vector3(0, 1.2, 0.72), glass)   # windshield
	add_box(root, Vector3(1.55, 0.45, 0.08), Vector3(0, 1.15, -1.05), glass) # rear
	add_box(root, Vector3(0.08, 0.45, 1.35), Vector3(0.84, 1.15, -0.15), glass)
	add_box(root, Vector3(0.08, 0.45, 1.35), Vector3(-0.84, 1.15, -0.15), glass)
	# Bumpers
	add_box(root, Vector3(1.9, 0.28, 0.28), Vector3(0, 0.38, 2.15), dark)
	add_box(root, Vector3(1.9, 0.28, 0.28), Vector3(0, 0.38, -2.15), dark)
	# Grille + lights
	add_box(root, Vector3(0.7, 0.22, 0.08), Vector3(0, 0.55, 2.28), chrome)
	add_box(root, Vector3(0.35, 0.18, 0.12), Vector3(0.65, 0.55, 2.25), light_f)
	add_box(root, Vector3(0.35, 0.18, 0.12), Vector3(-0.65, 0.55, 2.25), light_f)
	add_box(root, Vector3(0.4, 0.16, 0.1), Vector3(0.6, 0.55, -2.25), light_r)
	add_box(root, Vector3(0.4, 0.16, 0.1), Vector3(-0.6, 0.55, -2.25), light_r)
	# Side mirrors
	add_box(root, Vector3(0.22, 0.1, 0.18), Vector3(1.05, 1.05, 0.55), dark)
	add_box(root, Vector3(0.22, 0.1, 0.18), Vector3(-1.05, 1.05, 0.55), dark)
	# Number plate stub
	add_box(root, Vector3(0.45, 0.14, 0.04), Vector3(0, 0.4, 2.32), rubber)

	return Vector3(1.9, 1.2, 4.4)


static func build_van(root: Node3D, paint: StandardMaterial3D) -> Vector3:
	clear_children(root)
	var glass := mat(Color(0.35, 0.5, 0.65, 0.55), 0.05, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var dark := mat(Color(0.08, 0.08, 0.09), 0.7, 0.2)
	var chrome := mat(Color(0.75, 0.75, 0.78), 0.25, 0.85)
	var light_f := mat(Color(1, 0.95, 0.75), 0.2, 0.0, Color(1, 0.95, 0.7), 1.4)
	var light_r := mat(Color(0.85, 0.1, 0.08), 0.35, 0.0, Color(0.9, 0.1, 0.05), 1.2)
	var cargo := mat(Color(0.92, 0.92, 0.9), 0.85, 0.05)

	# Cab
	add_box(root, Vector3(2.05, 0.7, 1.6), Vector3(0, 0.55, 1.35), paint)
	add_box(root, Vector3(1.9, 0.85, 1.2), Vector3(0, 1.25, 1.2), paint)
	# Cargo box (branding panel)
	add_box(root, Vector3(2.15, 1.7, 3.0), Vector3(0, 1.15, -0.85), cargo)
	add_box(root, Vector3(2.05, 0.15, 2.9), Vector3(0, 2.05, -0.85), paint) # roof rail color strip
	# Brand stripe on cargo
	add_box(root, Vector3(2.18, 0.35, 2.6), Vector3(0, 1.2, -0.85), paint)
	# Windows / bumper / lights
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

	return Vector3(2.2, 1.9, 4.9)
