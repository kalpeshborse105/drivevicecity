extends Node3D
## Flat GPS-style arrow above the car (not a tall debug beam).

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


func _process(_delta: float) -> void:
	if _follow == null:
		return
	# Stay low above roof — GTA/BUSID style marker, not a sky pillar
	global_position = _follow.global_position + Vector3(0, 2.6, 0)
	if not _active:
		return
	var flat := Vector3(_target.x, global_position.y, _target.z)
	if global_position.distance_to(flat) > 0.8:
		look_at(flat, Vector3.UP)
