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
	# Invisible trigger only — no blue/yellow ground rings (HUD + minimap navigate).
	if _label:
		_label.visible = false
	if _mesh:
		_mesh.visible = false
	if _collision and _collision.shape is CylinderShape3D:
		(_collision.shape as CylinderShape3D).radius = radius


func _on_body_entered(body: Node) -> void:
	if body is VehicleBody3D:
		car_entered.emit(self)
