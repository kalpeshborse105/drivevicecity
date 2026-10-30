extends Control
## Upgraded Google-Maps Style Minimap for Dhule, Maharashtra (PC + Android).
## Supports Street Map / Satellite Hybrid view, GPS route line, real lat/lon readout, and Dhule landmark pins.

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
var _btn_mode: Button
var _zoom_label: Label
var _coord_label: Label
var _target_world_pos: Vector3 = Vector3.ZERO
var _has_target: bool = false
var _satellite_mode: bool = false

const ORIGIN_LAT := 20.9020
const ORIGIN_LON := 74.7770
const ZOOM_MIN := 45.0
const ZOOM_MAX := 320.0

const DHULE_POIS := [
	{"name": "Agra Rd NH-3", "pos": Vector3(0, 0, 0), "color": Color(0.98, 0.74, 0.02)},
	{"name": "Swaminarayan Mandir", "pos": Vector3(145, 0, -210), "color": Color(0.95, 0.35, 0.25)},
	{"name": "Shivaji Maharaj Statue", "pos": Vector3(-60, 0, 40), "color": Color(1.0, 0.55, 0.1)},
	{"name": "Panzara River Bridge", "pos": Vector3(20, 0, -95), "color": Color(0.25, 0.65, 0.98)},
	{"name": "Deopur Vidyanagri", "pos": Vector3(-160, 0, -240), "color": Color(0.3, 0.85, 0.45)},
	{"name": "Rajwade Mandal", "pos": Vector3(85, 0, 110), "color": Color(0.85, 0.45, 0.95)},
]

func _ready() -> void:
	if car_path != NodePath(""):
		_car = get_node_or_null(car_path) as Node3D
	_viewport.world_3d = get_viewport().world_3d
	_zoom = height
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = _zoom
	_cam.current = true
	_build_chrome()

func set_navigation_target(world_pos: Vector3, active: bool) -> void:
	_target_world_pos = world_pos
	_has_target = active
	if _marker:
		_marker.queue_redraw()

func _build_chrome() -> void:
	_marker = Control.new()
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker.draw.connect(_draw_google_map_overlay)
	add_child(_marker)

	# Top GPS coordinate header bar (Google Maps style)
	_coord_label = Label.new()
	_coord_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_coord_label.offset_top = 4.0
	_coord_label.offset_left = 6.0
	_coord_label.offset_right = -6.0
	_coord_label.add_theme_font_size_override("font_size", 11)
	_coord_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 0.95))
	_coord_label.text = "DHULE GPS · 20.9020°N 74.7770°E"
	add_child(_coord_label)

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
	_btn_out.text = "-"
	_btn_out.custom_minimum_size = Vector2(30, 26)
	_btn_out.focus_mode = Control.FOCUS_NONE
	_btn_out.pressed.connect(func() -> void: zoom_by(1.25))
	row.add_child(_btn_out)

	_zoom_label = Label.new()
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_label.custom_minimum_size = Vector2(44, 0)
	_zoom_label.add_theme_font_size_override("font_size", 11)
	row.add_child(_zoom_label)

	_btn_in = Button.new()
	_btn_in.text = "+"
	_btn_in.custom_minimum_size = Vector2(30, 26)
	_btn_in.focus_mode = Control.FOCUS_NONE
	_btn_in.pressed.connect(func() -> void: zoom_by(0.8))
	row.add_child(_btn_in)

	_btn_mode = Button.new()
	_btn_mode.text = "SAT"
	_btn_mode.custom_minimum_size = Vector2(40, 26)
	_btn_mode.focus_mode = Control.FOCUS_NONE
	_btn_mode.pressed.connect(_toggle_map_mode)
	row.add_child(_btn_mode)

	_refresh_zoom_label()

func _toggle_map_mode() -> void:
	_satellite_mode = not _satellite_mode
	_btn_mode.text = "MAP" if _satellite_mode else "SAT"
	_marker.queue_redraw()

func zoom_by(factor: float) -> void:
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	_cam.size = _zoom
	_refresh_zoom_label()
	_marker.queue_redraw()

func _refresh_zoom_label() -> void:
	if _zoom_label:
		_zoom_label.text = "%dm" % int(_zoom)

func _world_to_minimap(world_pos: Vector3, center_pos: Vector3) -> Vector2:
	var c := size * 0.5
	c.y -= 10.0
	var rel := Vector2(world_pos.x - center_pos.x, world_pos.z - center_pos.z)
	var scale_px := (minf(size.x, size.y) / maxf(_zoom, 1.0))
	return c + rel * scale_px

func _draw_google_map_overlay() -> void:
	var c := size * 0.5
	c.y -= 10.0

	# Border frame
	_marker.draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.16, 0.22, 0.9), false, 2.0)

	if _car == null:
		return

	var car_pos := _car.global_position

	# Draw POI pins inside radar radius
	for poi in DHULE_POIS:
		var p_screen := _world_to_minimap(poi["pos"], car_pos)
		if p_screen.x > 8 and p_screen.x < size.x - 8 and p_screen.y > 18 and p_screen.y < size.y - 30:
			_marker.draw_circle(p_screen, 4.5, Color(0.08, 0.08, 0.1, 0.9))
			_marker.draw_circle(p_screen, 3.2, poi["color"])

	# Draw Google Maps cyan/blue route line to active delivery target
	if _has_target:
		var t_screen := _world_to_minimap(_target_world_pos, car_pos)
		t_screen.x = clampf(t_screen.x, 10.0, size.x - 10.0)
		t_screen.y = clampf(t_screen.y, 20.0, size.y - 32.0)
		_marker.draw_line(c, t_screen, Color(0.09, 0.45, 0.98, 0.85), 4.0)
		_marker.draw_line(c, t_screen, Color(0.38, 0.78, 1.0, 0.95), 2.0)
		_marker.draw_circle(t_screen, 6.0, Color(0.95, 0.22, 0.18, 1.0))
		_marker.draw_circle(t_screen, 2.5, Color(1.0, 1.0, 1.0, 1.0))

	# Player navigation arrow (Google Maps navigation chevron)
	var f := -_car.global_transform.basis.z
	var yaw := atan2(f.x, f.z)
	var tip := c + Vector2(sin(yaw), -cos(yaw)) * 14.0
	var left := c + Vector2(sin(yaw + 2.5), -cos(yaw + 2.5)) * 10.0
	var right := c + Vector2(sin(yaw - 2.5), -cos(yaw - 2.5)) * 10.0
	_marker.draw_circle(c, 12.0, Color(0.15, 0.48, 0.98, 0.28))
	_marker.draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(1.0, 0.92, 0.2, 0.98))
	_marker.draw_circle(c, 3.5, Color(0.12, 0.12, 0.14, 0.95))

func _process(_delta: float) -> void:
	if _car == null:
		return
	var pos := _car.global_position
	_cam.global_position = pos + Vector3(0, 220, 0)
	_cam.look_at(pos, Vector3(0, 0, -1))
	if _coord_label:
		var lat := ORIGIN_LAT - (pos.z / 111320.0)
		var lon := ORIGIN_LON + (pos.x / (111320.0 * cos(deg_to_rad(ORIGIN_LAT))))
		_coord_label.text = "DHULE · %.4f°N %.4f°E" % [lat, lon]
	_marker.queue_redraw()
