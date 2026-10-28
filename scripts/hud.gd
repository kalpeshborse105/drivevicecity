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
var _focus_hint_shown: bool = false
@onready var _settings: Node = get_node_or_null("/root/GameSettings")


func _ready() -> void:
	if car_path != NodePath(""):
		_car = get_node_or_null(car_path) as VehicleBody3D
	if _settings == null:
		_settings = get_node_or_null("/root/GameSettings")
	_title_label.text = "DriveViceCity — Dhule"
	_hint_label.text = "WASD drive · RMB/drag look 360° · Map +/− zoom · G Home · V vehicle · R reset"
	_mission_label.text = "Loading Dhule OSM roads…"
	_stats_label.text = "₹0  ·  0 jobs"
	_vehicle_label.text = "Loading vehicle…"
	_nav_label.text = ""
	_test_label.text = "Map © OpenStreetMap (ODbL)"
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
	# Show Home once so menus are discoverable
	call_deferred("_open_home_once")


func _open_home_once() -> void:
	if _garage and not _garage.visible and _garage.has_method("toggle"):
		_garage.toggle()
		if _garage.has_method("set_info"):
			_garage.set_info("Home", "Pick vehicle tab · Esc or G to drive")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_garage") or Input.is_action_just_pressed("ui_cancel"):
		_toggle_garage()
	if _car == null:
		return
	var kph := 0.0
	if _car.has_method("speed_kph"):
		kph = _car.speed_kph()
	else:
		kph = _car.linear_velocity.length() * 3.6
	var keyed := Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("accelerate")
	if keyed:
		_focus_hint_shown = true
		_speed_label.text = "%d km/h  ▶" % int(round(kph))
	elif not _focus_hint_shown and kph < 0.5:
		_speed_label.text = "0 · click here + W"
	else:
		_speed_label.text = "%d km/h" % int(round(kph))
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


func _toggle_garage() -> void:
	if _garage == null:
		return
	if _garage.has_method("toggle"):
		_garage.toggle()
	# Keep panel clickable; only release focus when closing so WASD works again
	if _garage.visible:
		_garage.move_to_front()
		_garage.grab_focus()
	else:
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


func _on_paint_requested(index: int) -> void:
	if _car and _car.has_method("apply_paint_index"):
		_car.apply_paint_index(index)
	if _settings and _settings.has_method("record_paint"):
		_settings.call("record_paint", index)


func _on_profile_requested(index: int) -> void:
	if _car and _car.has_method("apply_profile_index"):
		_car.apply_profile_index(index)
	if _settings and _settings.has_method("record_profile"):
		_settings.call("record_profile", index)


func _on_kit_requested(index: int) -> void:
	if _car and _car.has_method("apply_kit_index"):
		_car.apply_kit_index(index)
	if _settings and _settings.has_method("record_kit"):
		_settings.call("record_kit", index)


func _on_rim_requested(index: int) -> void:
	if _car and _car.has_method("apply_rim_index"):
		_car.apply_rim_index(index)
	if _settings and _settings.has_method("record_rim"):
		_settings.call("record_rim", index)
