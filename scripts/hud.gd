extends CanvasLayer
## Drive HUD + minimap + garage (P3).

@export var car_path: NodePath

@onready var _speed_label: Label = $Root/SpeedLabel
@onready var _hint_label: Label = $Root/HintLabel
@onready var _title_label: Label = $Root/TitleLabel
@onready var _mission_label: Label = $Root/MissionLabel
@onready var _stats_label: Label = $Root/StatsLabel
@onready var _vehicle_label: Label = $Root/VehicleLabel
@onready var _nav_label: Label = $Root/NavLabel
@onready var _garage: PanelContainer = $Root/GaragePanel
@onready var _test_label: Label = $Root/TestLabel

var _car: VehicleBody3D
var _target: Vector3 = Vector3.ZERO
var _nav_active: bool = false


func _ready() -> void:
	if car_path != NodePath(""):
		_car = get_node_or_null(car_path) as VehicleBody3D
	_title_label.text = "DriveViceCity — Dhule"
	_hint_label.text = "WASD · Space · R reset · P paint · V van · G garage · Guide: docs/USER-GUIDE.md"
	_mission_label.text = "Loading Dhule OSM roads…"
	_stats_label.text = "₹0  ·  0 jobs"
	_vehicle_label.text = "Sedan · Saffron"
	_nav_label.text = ""
	_test_label.text = "Map © OpenStreetMap (ODbL)"
	if _garage.has_signal("paint_requested"):
		_garage.paint_requested.connect(_on_paint_requested)
	if _garage.has_signal("profile_requested"):
		_garage.profile_requested.connect(_on_profile_requested)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_garage"):
		if _garage.has_method("toggle"):
			_garage.toggle()
	if _car == null:
		return
	var kph := 0.0
	if _car.has_method("speed_kph"):
		kph = _car.speed_kph()
	else:
		kph = _car.linear_velocity.length() * 3.6
	_speed_label.text = "%d km/h" % int(round(kph))
	if _nav_active:
		var d := _car.global_position.distance_to(_target)
		_nav_label.text = "Target  %d m" % int(round(d))
	else:
		_nav_label.text = ""


func set_mission_text(text: String) -> void:
	_mission_label.text = text


func set_stats(cash: int, completed: int, carrying: bool, job_type: String = "Parcel") -> void:
	var cargo := job_type.to_upper() if carrying else "empty"
	_stats_label.text = "₹%d  ·  %d jobs  ·  %s" % [cash, completed, cargo]


func set_vehicle_info(profile_name: String, paint_name: String) -> void:
	_vehicle_label.text = "%s · %s" % [profile_name, paint_name]
	if _garage.has_method("set_info"):
		_garage.set_info(profile_name, paint_name)


func set_distance_to_target(world_pos: Vector3, active: bool, car: Node3D) -> void:
	_target = world_pos
	_nav_active = active
	if car:
		_car = car as VehicleBody3D


func set_test_status(text: String) -> void:
	_test_label.text = text


func _on_paint_requested(index: int) -> void:
	if _car and _car.has_method("apply_paint_index"):
		_car.apply_paint_index(index)


func _on_profile_requested(index: int) -> void:
	if _car and _car.has_method("apply_profile_index"):
		_car.apply_profile_index(index)
