extends Control
## On-screen driving controls for Android / touch devices (android-first).
## Builds steer + pedal buttons that feed the same input actions the car reads.
## Visibility follows GameSettings.touch_controls_mode: 0=auto, 1=always, 2=off.

const ACTION_STEER_LEFT := "steer_left"
const ACTION_STEER_RIGHT := "steer_right"
const ACTION_ACCEL := "accelerate"
const ACTION_BRAKE := "brake"
const ACTION_HANDBRAKE := "handbrake"
const ACTION_RESET := "reset_car"

const BG := Color(0.05, 0.09, 0.11, 0.42)
const BG_PRESSED := Color(0.98, 0.76, 0.16, 0.6)
const BORDER := Color(1.0, 1.0, 1.0, 0.38)

var _settings: Node
var _buttons: Array[Button] = []
var _hud_adjusted := false


func _ready() -> void:
	_settings = get_node_or_null("/root/GameSettings")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	if _settings and _settings.has_signal("settings_changed"):
		_settings.connect("settings_changed", _apply_visibility)
	_apply_visibility()


func _should_show() -> bool:
	var mode := 0
	if _settings and _settings.get("touch_controls_mode") != null:
		mode = int(_settings.get("touch_controls_mode"))
	if mode == 2:
		return false
	if mode == 1:
		return true
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


func _apply_visibility() -> void:
	var show_pad := _should_show()
	visible = show_pad
	for b in _buttons:
		b.visible = show_pad
	if show_pad and not _hud_adjusted:
		_hud_adjusted = true
		_layout_hud_for_touch()
	elif not show_pad and _hud_adjusted:
		_hud_adjusted = false
		_restore_hud()


func _build() -> void:
	# Left thumb: steering. Right thumb: pedals + handbrake + reset.
	var steer_left := _hold_button("◀", ACTION_STEER_LEFT, Vector2(132, 132), 46)
	_rect(steer_left, 32, -140, 164, -8)
	var steer_right := _hold_button("▶", ACTION_STEER_RIGHT, Vector2(132, 132), 46)
	_rect(steer_right, 178, -140, 310, -8)

	var accel := _hold_button("▲\nGAS", ACTION_ACCEL, Vector2(150, 150), 30)
	_rect(accel, -186, -158, -36, -8)
	var brake := _hold_button("▼\nBRAKE", ACTION_BRAKE, Vector2(120, 120), 24)
	_rect(brake, -318, -128, -198, -8)
	var handbrake := _hold_button("HB", ACTION_HANDBRAKE, Vector2(120, 74), 22)
	_rect(handbrake, -186, -246, -66, -172)
	var reset := _hold_button("R", ACTION_RESET, Vector2(74, 74), 22)
	reset.tooltip_text = "Reset car to spawn"
	_rect(reset, -318, -222, -244, -148)


func _hold_button(text: String, action: String, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color(0.98, 0.97, 0.9))
	b.add_theme_color_override("font_pressed_color", Color(0.1, 0.08, 0.02))
	b.add_theme_stylebox_override("normal", _style(BG))
	b.add_theme_stylebox_override("hover", _style(BG))
	b.add_theme_stylebox_override("pressed", _style(BG_PRESSED))
	b.add_theme_stylebox_override("focus", _style(BG))
	b.button_down.connect(func() -> void: Input.action_press(action))
	b.button_up.connect(func() -> void: Input.action_release(action))
	add_child(b)
	_buttons.append(b)
	return b


func _style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(20)
	sb.border_color = BORDER
	sb.set_border_width_all(2)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	return sb


func _rect(c: Control, left: float, top: float, right: float, bottom: float) -> void:
	## Left/right from the left when positive, from the right edge when negative.
	## Top/bottom are measured from the bottom edge (negative = up).
	c.anchor_left = 0.0 if left >= 0.0 else 1.0
	c.anchor_right = 0.0 if right >= 0.0 else 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = left
	c.offset_right = right
	c.offset_top = top
	c.offset_bottom = bottom


func _layout_hud_for_touch() -> void:
	## Keep HUD text out from under the thumbs.
	var root := get_parent()
	if root == null:
		return
	var speed := root.get_node_or_null("SpeedLabel") as Control
	if speed:
		speed.anchor_left = 0.5
		speed.anchor_right = 0.5
		speed.anchor_top = 1.0
		speed.anchor_bottom = 1.0
		speed.offset_left = -120.0
		speed.offset_right = 120.0
		speed.offset_top = -196.0
		speed.offset_bottom = -148.0
		speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := root.get_node_or_null("HintLabel") as Control
	if hint:
		hint.visible = false
	var customize := root.get_node_or_null("CustomizeBtn") as Control
	if customize:
		customize.anchor_left = 0.0
		customize.anchor_right = 0.0
		customize.anchor_top = 0.0
		customize.anchor_bottom = 0.0
		customize.offset_left = 24.0
		customize.offset_right = 168.0
		customize.offset_top = 118.0
		customize.offset_bottom = 170.0


func _restore_hud() -> void:
	var root := get_parent()
	if root == null:
		return
	var speed := root.get_node_or_null("SpeedLabel") as Control
	if speed:
		speed.anchor_left = 0.0
		speed.anchor_right = 0.0
		speed.offset_left = 24.0
		speed.offset_right = 220.0
		speed.offset_top = -72.0
		speed.offset_bottom = -24.0
		speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var hint := root.get_node_or_null("HintLabel") as Control
	if hint:
		hint.visible = true
	var customize := root.get_node_or_null("CustomizeBtn") as Control
	if customize:
		customize.anchor_top = 1.0
		customize.anchor_bottom = 1.0
		customize.offset_left = 24.0
		customize.offset_right = 168.0
		customize.offset_top = -148.0
		customize.offset_bottom = -92.0