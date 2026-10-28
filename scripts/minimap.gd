extends Control
## Top-down minimap following the player (own UI, no paid assets).

@export var car_path: NodePath
@export var map_path: NodePath
@export var height: float = 180.0

@onready var _viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var _cam: Camera3D = $SubViewportContainer/SubViewport/MiniCam

var _car: Node3D


func _ready() -> void:
	if car_path != NodePath(""):
		_car = get_node_or_null(car_path) as Node3D
	_viewport.world_3d = get_viewport().world_3d
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = height
	_cam.current = true
	# MiniCam should not be the game camera — disable current on it for main;
	# SubViewport has its own current.
	_cam.current = true


func _process(_delta: float) -> void:
	if _car == null:
		return
	_cam.global_position = _car.global_position + Vector3(0, 220, 0)
	_cam.look_at(_car.global_position, Vector3(0, 0, -1))
