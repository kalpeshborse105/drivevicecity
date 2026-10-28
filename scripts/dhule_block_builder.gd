extends Node3D
## Procedural stand-in for a Dhule neighbourhood block.
## P0 only — later replace with OSM → Blender / OSM2World import of real Dhule roads.

@export var blocks_x: int = 6
@export var blocks_z: int = 6
@export var block_size: float = 48.0
@export var road_width: float = 10.0
@export var sidewalk: float = 2.0

const LANDMARK_NAMES := [
	"Old Agra Road Junction",
	"Municipal Market",
	"Station Road Stretch",
	"College Area",
	"Bus Stand Loop",
	"River Road Bend",
]


func _ready() -> void:
	_build_ground()
	_build_road_grid()
	_build_buildings()
	_build_landmarks()
	_build_props()


func _mat(color: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, collision: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collision:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		body.position = pos
		add_child(body)


func _build_ground() -> void:
	var span_x := blocks_x * block_size + road_width
	var span_z := blocks_z * block_size + road_width
	# Dusty Maharashtra ground under everything
	_box(
		Vector3(span_x + 80.0, 1.0, span_z + 80.0),
		Vector3(span_x * 0.5, -0.55, span_z * 0.5),
		_mat(Color(0.45, 0.38, 0.28))
	)


func _build_road_grid() -> void:
	var asphalt := _mat(Color(0.18, 0.18, 0.2), 0.95)
	var paint := _mat(Color(0.9, 0.85, 0.55), 0.7)
	var span_x := blocks_x * block_size + road_width
	var span_z := blocks_z * block_size + road_width

	# Horizontal roads (along X)
	for iz in range(blocks_z + 1):
		var z := iz * block_size
		_box(Vector3(span_x, 0.12, road_width), Vector3(span_x * 0.5, 0.06, z), asphalt)
		# Center line dashes
		var dash := 0.0
		while dash < span_x:
			_box(Vector3(3.0, 0.14, 0.25), Vector3(dash + 1.5, 0.13, z), paint, false)
			dash += 8.0

	# Vertical roads (along Z)
	for ix in range(blocks_x + 1):
		var x := ix * block_size
		_box(Vector3(road_width, 0.12, span_z), Vector3(x, 0.06, span_z * 0.5), asphalt)
		var dash := 0.0
		while dash < span_z:
			_box(Vector3(0.25, 0.14, 3.0), Vector3(x, 0.13, dash + 1.5), paint, false)
			dash += 8.0


func _build_buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261028  # stable layout
	var palette := [
		Color(0.78, 0.62, 0.42),
		Color(0.72, 0.72, 0.68),
		Color(0.55, 0.45, 0.38),
		Color(0.85, 0.78, 0.62),
		Color(0.42, 0.55, 0.48),
		Color(0.62, 0.35, 0.28),
	]

	for ix in range(blocks_x):
		for iz in range(blocks_z):
			var origin := Vector3(ix * block_size + road_width * 0.5, 0.0, iz * block_size + road_width * 0.5)
			var plot := block_size - road_width
			# 2–4 buildings per block
			var count := rng.randi_range(2, 4)
			for _i in count:
				var w := rng.randf_range(8.0, 16.0)
				var d := rng.randf_range(8.0, 16.0)
				var h := rng.randf_range(4.5, 14.0)
				var px := origin.x + sidewalk + rng.randf_range(0.0, maxf(plot - w - sidewalk * 2.0, 1.0))
				var pz := origin.z + sidewalk + rng.randf_range(0.0, maxf(plot - d - sidewalk * 2.0, 1.0))
				var col: Color = palette[rng.randi_range(0, palette.size() - 1)]
				_box(Vector3(w, h, d), Vector3(px + w * 0.5, h * 0.5, pz + d * 0.5), _mat(col))
				# Shop-board strip (Indian street feel)
				if h < 8.0 and rng.randf() > 0.35:
					_box(
						Vector3(w * 0.9, 0.7, 0.35),
						Vector3(px + w * 0.5, 2.4, pz - 0.1),
						_mat(Color(rng.randf_range(0.7, 1.0), rng.randf_range(0.2, 0.6), 0.15)),
						false
					)


func _build_landmarks() -> void:
	var span_x := blocks_x * block_size + road_width
	var span_z := blocks_z * block_size + road_width
	var spots := [
		Vector3(span_x * 0.15, 0, span_z * 0.2),
		Vector3(span_x * 0.55, 0, span_z * 0.35),
		Vector3(span_x * 0.8, 0, span_z * 0.55),
		Vector3(span_x * 0.3, 0, span_z * 0.75),
		Vector3(span_x * 0.65, 0, span_z * 0.85),
		Vector3(span_x * 0.45, 0, span_z * 0.15),
	]
	for i in range(mini(LANDMARK_NAMES.size(), spots.size())):
		var p: Vector3 = spots[i]
		# Landmark tower / water tank style marker
		_box(Vector3(4.0, 16.0, 4.0), Vector3(p.x, 8.0, p.z), _mat(Color(0.35, 0.55, 0.7)))
		_box(Vector3(6.0, 2.0, 6.0), Vector3(p.x, 17.0, p.z), _mat(Color(0.9, 0.55, 0.2)), false)
		var label := Label3D.new()
		label.text = LANDMARK_NAMES[i]
		label.font_size = 48
		label.pixel_size = 0.02
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(p.x, 20.0, p.z)
		label.modulate = Color(1, 0.95, 0.8)
		add_child(label)


func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var tree_mat := _mat(Color(0.2, 0.45, 0.22))
	var trunk := _mat(Color(0.35, 0.22, 0.12))
	var span_x := blocks_x * block_size + road_width
	var span_z := blocks_z * block_size + road_width
	for _i in 40:
		var x := rng.randf_range(4.0, span_x - 4.0)
		var z := rng.randf_range(4.0, span_z - 4.0)
		# Keep trees off road center strips roughly
		if fmod(x, block_size) < road_width * 0.6 or fmod(z, block_size) < road_width * 0.6:
			continue
		_box(Vector3(0.5, 2.0, 0.5), Vector3(x, 1.0, z), trunk, false)
		_box(Vector3(2.4, 2.4, 2.4), Vector3(x, 3.2, z), tree_mat, false)
