extends Node3D
## Flat GPS arrow above the car — yaw only (never pitch into the roof).

@onready var _mesh: MeshInstance3D = $MeshInstance3D

var _target: Vector3 = Vector3.ZERO
var _active: bool = false
var _follow: Node3D


func setup(follow: Node3D) -> void:
	_follow = follow


func set_target(world_pos: Vector3, active: bool) -> void:
	_target = world_pos
	_active = active
	visible = active
	if _mesh:
		_mesh.rotation = Vector3(0, 0, 0)


func _process(_delta: float) -> void:
	if _follow == null:
		return
	global_position = _follow.global_position + Vector3(0, 2.85, 0)
	rotation = Vector3.ZERO
	if not _active:
		return
	var to := Vector3(_target.x - global_position.x, 0.0, _target.z - global_position.z)
	if to.length() < 1.0:
		return
	# Yaw only: flat arrow stays horizontal (fixes yellow bar through roof)
	rotation.y = atan2(to.x, to.z)
