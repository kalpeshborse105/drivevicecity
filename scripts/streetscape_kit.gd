extends RefCounted
## Original Dhule-inspired urban junction streetscape (no vehicles/people/text).
## Procedural game-ready props for GLB export / Phase 1 dressing.

const BuildingKit = preload("res://scripts/building_kit.gd")
const StreetKit = preload("res://scripts/street_kit.gd")
const VehicleMeshBuilder = preload("res://scripts/vehicle_mesh_builder.gd")


static func _mat(c: Color, rough: float = 0.7, metal: float = 0.05) -> StandardMaterial3D:
	return VehicleMeshBuilder.mat(c, rough, metal)


static func build_dhule_junction(root: Node3D) -> void:
	## Crossroads + commercial corners + pavements + streetlights. Origin at junction centre.
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()

	var asphalt := _mat(Color(0.18, 0.18, 0.2), 0.85, 0.02)
	var lane := _mat(Color(0.92, 0.92, 0.9), 0.55, 0.05)
	var curb := _mat(Color(0.55, 0.52, 0.48), 0.8, 0.0)
	var walk := _mat(Color(0.62, 0.58, 0.52), 0.75, 0.0)
	var pole := _mat(Color(0.35, 0.35, 0.36), 0.55, 0.4)

	# Carriageways (cross)
	StreetKit.add_box(root, Vector3(12.0, 0.08, 48.0), Vector3(0, 0.04, 0), asphalt, false, 0.0)
	StreetKit.add_box(root, Vector3(48.0, 0.08, 12.0), Vector3(0, 0.04, 0), asphalt, false, 0.0)
	# Centre dashed hints (geometry only — no glyphs)
	for i in range(-3, 4):
		if i == 0:
			continue
		StreetKit.add_box(root, Vector3(0.18, 0.02, 1.2), Vector3(0, 0.09, float(i) * 5.0), lane, false, 0.0)
		StreetKit.add_box(root, Vector3(1.2, 0.02, 0.18), Vector3(float(i) * 5.0, 0.09, 0), lane, false, 0.0)
	# Pavements
	for side in [-1.0, 1.0]:
		StreetKit.add_box(root, Vector3(3.2, 0.12, 40.0), Vector3(side * 8.2, 0.1, 0), walk, false, 0.0)
		StreetKit.add_box(root, Vector3(40.0, 0.12, 3.2), Vector3(0, 0.1, side * 8.2), walk, false, 0.0)
		StreetKit.add_box(root, Vector3(0.35, 0.22, 40.0), Vector3(side * 6.4, 0.12, 0), curb, false, 0.0)
		StreetKit.add_box(root, Vector3(40.0, 0.22, 0.35), Vector3(0, 0.12, side * 6.4), curb, false, 0.0)

	# Four commercial corner buildings (balconies / shopfronts via BuildingKit)
	var corners := [
		{"pos": Vector3(14.0, 0, 14.0), "sz": Vector2(10.0, 10.0), "face": Vector3(-1, 0, -1), "kind": "commercial"},
		{"pos": Vector3(-14.0, 0, 14.0), "sz": Vector2(9.0, 11.0), "face": Vector3(1, 0, -1), "kind": "retail"},
		{"pos": Vector3(14.0, 0, -14.0), "sz": Vector2(11.0, 9.0), "face": Vector3(-1, 0, 1), "kind": "commercial"},
		{"pos": Vector3(-15.0, 0, -14.0), "sz": Vector2(10.0, 10.0), "face": Vector3(1, 0, 1), "kind": "residential"},
	]
	var seed := 742021
	for c_v in corners:
		var c: Dictionary = c_v
		var face: Vector3 = (c["face"] as Vector3).normalized()
		BuildingKit.footprint(root, c["pos"], c["sz"], str(c["kind"]), seed, face, false)
		seed += 17

	# Streetlights on each approach
	for p in [
		Vector3(7.5, 0, 18.0), Vector3(-7.5, 0, 18.0),
		Vector3(7.5, 0, -18.0), Vector3(-7.5, 0, -18.0),
		Vector3(18.0, 0, 7.5), Vector3(18.0, 0, -7.5),
		Vector3(-18.0, 0, 7.5), Vector3(-18.0, 0, -7.5),
	]:
		StreetKit.add_box(root, Vector3(0.12, 5.2, 0.12), p + Vector3(0, 2.6, 0), pole, false, 0.0)
		StreetKit.add_box(root, Vector3(0.8, 0.08, 0.25), p + Vector3(0, 5.15, 0), pole, false, 0.0)
		var lamp_m := VehicleMeshBuilder.mat(Color(1.0, 0.95, 0.82), 0.35, 0.0, Color(1.0, 0.95, 0.8), 0.8)
		StreetKit.add_box(root, Vector3(0.35, 0.12, 0.2), p + Vector3(0, 5.05, 0), lamp_m, false, 0.0)

	# Roadside details: dustbin pair stubs, low compound wall fragment, planter
	var dust := _mat(Color(0.25, 0.45, 0.28), 0.7, 0.05)
	StreetKit.add_box(root, Vector3(0.45, 0.7, 0.45), Vector3(9.2, 0.4, 10.5), dust, false, 0.0)
	StreetKit.add_box(root, Vector3(0.45, 0.7, 0.45), Vector3(9.8, 0.4, 10.5), dust, false, 0.0)
	var wall := _mat(Color(0.78, 0.72, 0.62), 0.8, 0.0)
	StreetKit.add_box(root, Vector3(6.0, 1.4, 0.22), Vector3(-20.0, 0.7, -9.5), wall, false, 0.0)
	var planter := _mat(Color(0.55, 0.35, 0.22), 0.75, 0.0)
	StreetKit.add_box(root, Vector3(1.2, 0.45, 0.6), Vector3(-9.5, 0.28, 12.0), planter, false, 0.0)
	StreetKit.add_box(root, Vector3(1.0, 0.35, 0.45), Vector3(-9.5, 0.7, 12.0), _mat(Color(0.22, 0.4, 0.2), 0.85), false, 0.0)
