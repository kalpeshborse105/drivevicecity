extends Area3D
## Pickup or dropoff cylinder the car drives into.

signal car_entered(zone: Area3D)

@export var zone_color: Color = Color(0.2, 0.85, 0.35, 0.55)
@export var label_text: String = "ZONE"
@export var radius: float = 7.0

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _label: Label3D = $Label3D
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_apply_visuals()


func configure(pos: Vector3, text: String, color: Color) -> void:
	global_position = pos
	label_text = text
	zone_color = color
	_apply_visuals()
	show()
	set_deferred("monitoring", true)


func deactivate() -> void:
	hide()
	monitoring = false


func _apply_visuals() -> void:
	if _label:
		_label.text = label_text
		_label.modulate = Color(zone_color.r, zone_color.g, zone_color.b, 1.0)
	if _mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = zone_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(zone_color.r, zone_color.g, zone_color.b)
		mat.emission_energy_multiplier = 1.8
		_mesh.material_override = mat
	if _collision and _collision.shape is CylinderShape3D:
		(_collision.shape as CylinderShape3D).radius = radius


func _on_body_entered(body: Node) -> void:
	if body is VehicleBody3D:
		car_entered.emit(self)
