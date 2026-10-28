extends Node3D
## Mission target tracking only — no 3D yellow roof marker (minimap shows heading).

var _target: Vector3 = Vector3.ZERO
var _active: bool = false
var _follow: Node3D


func setup(follow: Node3D) -> void:
	_follow = follow
	visible = false
	var mesh := get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.visible = false


func set_target(world_pos: Vector3, active: bool) -> void:
	_target = world_pos
	_active = active
	# Keep node invisible — HUD distance + minimap are the nav cues
	visible = false


func _process(_delta: float) -> void:
	if _follow == null:
		return
	global_position = _follow.global_position + Vector3(0, 2.85, 0)
