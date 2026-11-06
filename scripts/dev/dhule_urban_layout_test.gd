extends Node3D

const MAP := "res://assets/maps/dhule_roads_game.json"
const RoadSurface = preload("res://scripts/road_surface.gd")
const RoadLabels = preload("res://scripts/road_labels.gd")
const AssetKit = preload("res://scripts/asset_kit.gd")

var _car: VehicleBody3D
var _cam: Camera3D


func _ready() -> void:
	_car = $PlayerCar
	_cam = $ChaseCam
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	var spawn: Dictionary = data["spawn"]
	var origin := Vector3(float(spawn["x"]), 0.42, float(spawn["z"]))
	_ground(origin)
	var asphalt := _road_mat("street_road", Color(0.78, 0.78, 0.8))
	var major := _road_mat("avenue_street", Color(0.74, 0.74, 0.77))
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.93, 0.93, 0.9)
	paint.roughness = 0.55
	var roads: Array = data["roads"]
	var shown: Array = []
	for road_v in roads:
		var road: Dictionary = road_v
		var pts: Array = road.get("points", [])
		if pts.size() < 2:
			continue
		var near := false
		var named := not str(road.get("name", "")).strip_edges().is_empty()
		for p in pts:
			var d := Vector2(float(p[0]) - origin.x, float(p[1]) - origin.z).length()
			if d < 380.0 or (named and d < 520.0):
				near = true
				break
		var rid := RoadSurface.road_key(road.get("id", ""))
		if not near and not RoadSurface.is_roundabout(rid):
			continue
		shown.append(road)
	var junctions := RoadSurface.prepare_junctions(shown)
	for road_v in shown:
		var road: Dictionary = road_v
		var hw := str(road.get("highway", "residential"))
		var mat: Material = major if hw in ["primary", "secondary", "tertiary", "trunk", "trunk_link"] else asphalt
		RoadSurface.add_way(self, road.get("points", []), float(road.get("width", 7.0)), 0.04, mat, paint, hw)
	var drawn := RoadSurface.draw_prepared_junctions(self, 0.04, asphalt, major, paint)
	RoadLabels.lay_on_asphalt(self, shown, 0.04, origin)
	var kerb := StandardMaterial3D.new()
	kerb.albedo_color = Color(0.72, 0.7, 0.64)
	var fill := StandardMaterial3D.new()
	fill.albedo_color = Color(0.34, 0.42, 0.28)
	var circles := RoadSurface.add_verified_roundabouts(self, shown, 0.04, fill, kerb)
	var signs := RoadLabels.bind(self, shown, data.get("buildings", []))
	_car.set_spawn(origin, Vector2(float(spawn["hx"]), float(spawn["hz"])))
	print("URBAN ways ", shown.size(), " junctions ", junctions, " drawn ", drawn, " roundabouts ", circles, " signs ", signs)


func lock_view(pos: Vector3, at: Vector3) -> void:
	set_meta("lock_view", true)
	_cam.current = true
	_cam.global_position = pos
	_cam.look_at(at, Vector3.UP)


func _process(delta: float) -> void:
	if bool(get_meta("lock_view", false)):
		return
	if _cam == null or _car == null:
		return
	var car_cam := _car.get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if car_cam:
		car_cam.current = false
	_cam.current = true
	var back := _car.global_transform.basis.z
	_cam.global_position = _car.global_position - back * 7.2 + Vector3(0, 2.6, 0)
	_cam.look_at(_car.global_position + Vector3(0, 1.0, 0) + back * 3.0, Vector3.UP)
	RoadLabels.update(_cam.global_position, delta)


func _road_mat(kit_key: String, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.9
	var tex := AssetKit.road_albedo_clean(kit_key)
	if tex:
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


func _ground(origin: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := BoxShape3D.new()
	shape.size = Vector3(2200, 0.4, 2200)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(origin.x, -0.2, origin.z)
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh.mesh = box
	mesh.position = col.position
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.55, 0.38)
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
