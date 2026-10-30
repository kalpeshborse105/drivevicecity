extends RefCounted
## Original modular Indian roadside props (mobile-friendly). Export as separate GLBs.

const VehicleMeshBuilder = preload("res://scripts/vehicle_mesh_builder.gd")


static func _mat(c: Color, rough: float = 0.75, metal: float = 0.05) -> StandardMaterial3D:
	return VehicleMeshBuilder.mat(c, rough, metal)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, yaw: float = 0.0) -> void:
	VehicleMeshBuilder.add_box(parent, size, pos, mat, yaw)


static func build_street_light(root: Node3D) -> void:
	## ~6.2 m concrete/steel pole + arm + warm LED head. Indian municipal proportions.
	for c in root.get_children():
		c.queue_free()
	var concrete := _mat(Color(0.62, 0.6, 0.56), 0.88)
	var steel := _mat(Color(0.35, 0.36, 0.38), 0.45, 0.55)
	var head := VehicleMeshBuilder.mat(Color(0.95, 0.92, 0.82), 0.35, 0.1, Color(1.0, 0.94, 0.75), 1.2)
	_box(root, Vector3(0.28, 0.18, 0.28), Vector3(0, 0.09, 0), concrete) # base
	_box(root, Vector3(0.14, 5.6, 0.14), Vector3(0, 2.98, 0), steel)
	_box(root, Vector3(0.18, 0.12, 0.18), Vector3(0, 5.85, 0), steel) # collar
	_box(root, Vector3(1.15, 0.08, 0.12), Vector3(0.5, 5.95, 0), steel) # arm
	_box(root, Vector3(0.45, 0.14, 0.28), Vector3(1.05, 5.88, 0), head)


static func build_traffic_barrier(root: Node3D) -> void:
	## Portable plastic Jersey-style barrier ~1.1 m — orange/white, no logos.
	for c in root.get_children():
		c.queue_free()
	var orange := _mat(Color(0.92, 0.42, 0.08), 0.7)
	var white := _mat(Color(0.92, 0.92, 0.9), 0.65)
	var base := _mat(Color(0.2, 0.2, 0.22), 0.9)
	_box(root, Vector3(1.35, 0.12, 0.45), Vector3(0, 0.06, 0), base)
	_box(root, Vector3(1.2, 0.95, 0.32), Vector3(0, 0.58, 0), orange)
	_box(root, Vector3(1.22, 0.18, 0.34), Vector3(0, 0.72, 0), white)
	_box(root, Vector3(1.22, 0.14, 0.34), Vector3(0, 0.42, 0), white)
	_box(root, Vector3(0.08, 0.85, 0.08), Vector3(-0.55, 0.55, 0), base) # handle posts
	_box(root, Vector3(0.08, 0.85, 0.08), Vector3(0.55, 0.55, 0), base)


static func build_bus_stop_shelter(root: Node3D) -> void:
	## Steel shelter + bench + blank blue board (no text/logos). ~3.4 m long.
	for c in root.get_children():
		c.queue_free()
	var steel := _mat(Color(0.32, 0.33, 0.35), 0.5, 0.4)
	var roof := _mat(Color(0.12, 0.4, 0.72), 0.55)
	var glass := _mat(Color(0.7, 0.78, 0.85, 0.35), 0.12, 0.05)
	var wood := _mat(Color(0.5, 0.38, 0.22), 0.85)
	var blue := _mat(Color(0.1, 0.32, 0.7), 0.6)
	var stripe := _mat(Color(0.95, 0.78, 0.12), 0.55)
	for z in [-1.45, 1.45]:
		_box(root, Vector3(0.1, 2.35, 0.1), Vector3(0.55, 1.18, z), steel)
		_box(root, Vector3(0.1, 2.35, 0.1), Vector3(-0.55, 1.18, z), steel)
	_box(root, Vector3(1.35, 0.08, 3.2), Vector3(0, 2.42, 0), roof)
	_box(root, Vector3(0.06, 1.15, 3.0), Vector3(-0.62, 1.75, 0), glass)
	_box(root, Vector3(0.42, 0.08, 2.3), Vector3(0.1, 0.48, 0), wood)
	_box(root, Vector3(0.38, 0.42, 0.08), Vector3(0.1, 0.22, -0.9), steel)
	_box(root, Vector3(0.38, 0.42, 0.08), Vector3(0.1, 0.22, 0.9), steel)
	_box(root, Vector3(0.05, 0.5, 1.5), Vector3(0.62, 2.85, 0), blue)
	_box(root, Vector3(0.06, 0.08, 1.4), Vector3(0.62, 2.68, 0), stripe)


static func build_concrete_planter(root: Node3D) -> void:
	## Square municipal planter ~1.1 m with soil + low hedge. No flowers/logos.
	for c in root.get_children():
		c.queue_free()
	var concrete := _mat(Color(0.58, 0.56, 0.52), 0.9)
	var soil := _mat(Color(0.28, 0.2, 0.12), 0.95)
	var green := _mat(Color(0.2, 0.38, 0.18), 0.88)
	_box(root, Vector3(1.1, 0.55, 1.1), Vector3(0, 0.28, 0), concrete)
	_box(root, Vector3(0.9, 0.12, 0.9), Vector3(0, 0.58, 0), soil)
	_box(root, Vector3(0.75, 0.35, 0.75), Vector3(0, 0.78, 0), green)
