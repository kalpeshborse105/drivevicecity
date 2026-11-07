extends CanvasLayer
## Drive HUD + minimap + home dashboard (P3).

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
@onready var _minimap: Control = $Root/Minimap
@onready var _customize_btn: Button = $Root/CustomizeBtn

var _car: VehicleBody3D
var _target: Vector3 = Vector3.ZERO
var _nav_active: bool = false
var _clock_wait: float = 0.0
@onready var _settings: Node = get_node_or_null("/root/GameSettings")


func _ready() -> void:
	if car_path != NodePath(""):
		_car = get_node_or_null(car_path) as VehicleBody3D
	if _settings == null:
		_settings = get_node_or_null("/root/GameSettings")
	_title_label.text = "DriveViceCity — Dhule"
	_hint_label.text = "W drive · S brake · A D steer · Space · G home · R reset"
	_mission_label.text = ""
	_stats_label.text = "₹0"
	_vehicle_label.text = ""
	_nav_label.text = ""
	_test_label.text = ""
	_customize_btn.focus_mode = Control.FOCUS_NONE
	_customize_btn.pressed.connect(_toggle_garage)
	if _settings and _settings.has_signal("settings_changed"):
		_settings.connect("settings_changed", _apply_display_settings)
	_apply_display_settings()
	if _garage.has_signal("paint_requested"):
		_garage.paint_requested.connect(_on_paint_requested)
	if _garage.has_signal("profile_requested"):
		_garage.profile_requested.connect(_on_profile_requested)
	if _garage.has_signal("kit_requested"):
		_garage.kit_requested.connect(_on_kit_requested)
	if _garage.has_signal("rim_requested"):
		_garage.rim_requested.connect(_on_rim_requested)
	_refresh_clock()


func _process(delta: float) -> void:
	_clock_wait += delta
	if _clock_wait >= 0.25:
		_clock_wait = 0.0
		_refresh_clock()
	if Input.is_action_just_pressed("toggle_garage") or Input.is_action_just_pressed("ui_cancel"):
		_toggle_garage()
	if _car == null:
		return
	var kph := 0.0
	if _car.has_method("speed_kph"):
		kph = _car.speed_kph()
	else:
		kph = _car.linear_velocity.length() * 3.6
	var gear := 1
	if _car.has_method("current_gear"):
		gear = int(_car.current_gear())
	_speed_label.text = "%d km/h    G%d" % [int(round(kph)), gear]
	if _nav_active:
		var d := _car.global_position.distance_to(_target)
		_nav_label.text = "Target  %d m" % int(round(d))
	else:
		_nav_label.text = ""


func sync_player_settings() -> void:
	_apply_display_settings()


func set_mission_text(text: String) -> void:
	_mission_label.text = text


func set_stats(cash: int, completed: int, carrying: bool, job_type: String = "Parcel") -> void:
	if carrying:
		_stats_label.text = "₹%d  ·  %d jobs  ·  %s" % [cash, completed, job_type]
	else:
		_stats_label.text = "₹%d  ·  %d jobs" % [cash, completed]


func set_vehicle_info(profile_name: String, paint_name: String) -> void:
	_vehicle_label.text = "%s · %s" % [profile_name, paint_name]
	if _garage.has_method("set_info"):
		_garage.set_info(profile_name, paint_name)


func set_distance_to_target(world_pos: Vector3, active: bool, car: Node3D) -> void:
	_target = world_pos
	_nav_active = active
	if car:
		_car = car as VehicleBody3D
	if _minimap and _minimap.has_method("set_navigation_target"):
		_minimap.set_navigation_target(world_pos, active)


func _refresh_clock() -> void:
	var now := Time.get_time_dict_from_system()
	_test_label.text = "%02d:%02d:%02d\n© OpenStreetMap" % [now.hour, now.minute, now.second]


func set_test_status(_text: String) -> void:
	_refresh_clock()


func _toggle_garage() -> void:
	if _garage == null:
		return
	if _garage.has_method("toggle"):
		_garage.toggle()
	# Keep panel clickable; only release focus when closing so WASD works again
	if _garage.visible:
		_garage.move_to_front()
		_garage.grab_focus()
		if _car and _car.has_method("set_showroom"):
			_car.call("set_showroom", true)
		_sync_garage_marks()
	else:
		if _car and _car.has_method("set_showroom"):
			_car.call("set_showroom", false)
		get_viewport().gui_release_focus()
		var w := get_window()
		if w:
			w.grab_focus()
		if _car and _car.has_method("_grab_play_focus"):
			_car.call("_grab_play_focus")


func _apply_display_settings() -> void:
	var show_map := true
	if _settings:
		show_map = bool(_settings.get("minimap_enabled"))
	_minimap.visible = show_map


func _sync_garage_marks() -> void:
	if _garage == null or _car == null or not _garage.has_method("mark"):
		return
	if _car.has_method("profile_index"):
		_garage.mark("profile", int(_car.profile_index()))
	if _car.has_method("paint_index"):
		_garage.mark("paint", int(_car.paint_index()))
	if _car.has_method("kit_index"):
		_garage.mark("kit", int(_car.kit_index()))
	if _car.has_method("rim_index"):
		_garage.mark("rim", int(_car.rim_index()))


func _on_paint_requested(index: int) -> void:
	if _car and _car.has_method("apply_paint_index"):
		_car.apply_paint_index(index)
	if _garage and _garage.has_method("mark"):
		_garage.mark("paint", index)
	if _settings and _settings.has_method("record_paint"):
		_settings.call("record_paint", index)


func _on_profile_requested(index: int) -> void:
	if _car and _car.has_method("apply_profile_index"):
		_car.apply_profile_index(index)
	if _garage and _garage.has_method("mark"):
		_garage.mark("profile", index)
	if _settings and _settings.has_method("record_profile"):
		_settings.call("record_profile", index)


func _on_kit_requested(index: int) -> void:
	if _car and _car.has_method("apply_kit_index"):
		_car.apply_kit_index(index)
	if _garage and _garage.has_method("mark"):
		_garage.mark("kit", index)
	if _settings and _settings.has_method("record_kit"):
		_settings.call("record_kit", index)


func _on_rim_requested(index: int) -> void:
	if _car and _car.has_method("apply_rim_index"):
		_car.apply_rim_index(index)
	if _garage and _garage.has_method("mark"):
		_garage.mark("rim", index)
	if _settings and _settings.has_method("record_rim"):
		_settings.call("record_rim", index)
