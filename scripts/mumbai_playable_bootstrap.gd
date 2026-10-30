extends Node3D
## Isolated Mumbai Fort prototype bootstrap — reuses PlayerCar only.
## Does not load Dhule missions/minimap production flow.

@onready var _map: Node3D = $MumbaiMap
@onready var _car: VehicleBody3D = $PlayerCar


func _ready() -> void:
	if _map.has_signal("map_ready"):
		_map.map_ready.connect(_on_map_ready)


func _on_map_ready(spawn_position: Vector3, spawn_heading: Vector2, _anchors: Array) -> void:
	if _car.has_method("set_spawn"):
		_car.set_spawn(spawn_position, spawn_heading)
	else:
		_car.global_position = spawn_position
	print(
		"MUMBAI_PROTO spawn_ok pos=(%.2f,%.2f) heading=(%.3f,%.3f)"
		% [spawn_position.x, spawn_position.z, spawn_heading.x, spawn_heading.y]
	)
