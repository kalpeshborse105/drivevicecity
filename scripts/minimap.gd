extends Control
## Top-down minimap with zoom + centre player marker (PC + Android).

@export var car_path: NodePath
@export var map_path: NodePath
@export var height: float = 110.0

@onready var _viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var _cam: Camera3D = $SubViewportContainer/SubViewport/MiniCam

var _car: Node3D
var _zoom: float = 110.0
var _marker: Control
var _btn_in: Button
var _btn_out: Button
var _zoom_label: Label

const ZOOM_MIN := 45.0
const ZOOM_MAX := 280.0


func _ready() -> void:
	if car_path != NodePath(""):
		_car = get_node_or_null(car_path) as Node3D
	_viewport.world_3d = get_viewport().world_3d
	_zoom = height
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = _zoom
	_cam.current = true
	_build_chrome()


func _build_chrome() -> void:
	## Player is always at map centre — draw a big arrow on top + zoom buttons.
	_marker = Control.new()
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker.draw.connect(_draw_player_marker)
	add_child(_marker)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -28.0
	row.offset_bottom = -2.0
	row.offset_left = 4.0
	row.offset_right = -4.0
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)

	_btn_out = Button.new()
	_btn_out.text = "−"
	_btn_out.custom_minimum_size = Vector2(36, 28)
	_btn_out.focus_mode = Control.FOCUS_NONE
	_btn_out.pressed.connect(func() -> void: zoom_by(1.25))
	row.add_child(_btn_out)

	_zoom_label = Label.new()
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_label.custom_minimum_size = Vector2(48, 0)
	_zoom_label.add_theme_font_size_override("font_size", 12)
	row.add_child(_zoom_label)

	_btn_in = Button.new()
	_btn_in.text = "+"
	_btn_in.custom_minimum_size = Vector2(36, 28)
	_btn_in.focus_mode = Control.FOCUS_NONE
	_btn_in.pressed.connect(func() -> void: zoom_by(0.8))
	row.add_child(_btn_in)
	_refresh_zoom_label()


func zoom_by(factor: float) -> void:
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	_cam.size = _zoom
	_refresh_zoom_label()
	_marker.queue_redraw()


func _refresh_zoom_label() -> void:
	if _zoom_label:
		_zoom_label.text = "%dm" % int(_zoom)


func _draw_player_marker() -> void:
	var c := size * 0.5
	c.y -= 10.0 # sit above zoom row
	var yaw := 0.0
	if _car:
		# Car forward in XZ (account for drive sign via -Z * sign is done in car; marker uses -Z)
		var f := -_car.global_transform.basis.z
		yaw = atan2(f.x, f.z)
	var tip := c + Vector2(sin(yaw), -cos(yaw)) * 14.0
	var left := c + Vector2(sin(yaw + 2.5), -cos(yaw + 2.5)) * 10.0
	var right := c + Vector2(sin(yaw - 2.5), -cos(yaw - 2.5)) * 10.0
	# Direction wedge only — no blue ring under the player icon
	_marker.draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(1.0, 0.92, 0.2, 0.98))
	_marker.draw_circle(c, 3.5, Color(0.12, 0.12, 0.14, 0.95))


func _process(_delta: float) -> void:
	if _car == null:
		return
	_cam.global_position = _car.global_position + Vector3(0, 220, 0)
	_cam.look_at(_car.global_position, Vector3(0, 0, -1))
	_marker.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	## Pinch / wheel zoom on the minimap itself (Android + desktop).
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(0.85)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.15)
			accept_event()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom_by(1.0 / maxf(mg.factor, 0.05))
		accept_event()
