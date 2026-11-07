extends PanelContainer
## Centered Home garage: full-car stage + live apply.
## Does not edit VehicleBody3D physics.

signal paint_requested(index: int)
signal profile_requested(index: int)
signal kit_requested(index: int)
signal rim_requested(index: int)

const HomeDashboard = preload("res://scripts/home_dashboard.gd")
const GarageCarPreview = preload("res://scripts/garage_car_preview.gd")

const PAINT_NAMES := [
	"White", "Black", "Silver", "Grey", "Red", "Blue", "Dark Blue", "Green", "Brown", "Yellow"
]
const PAINT_COLORS := [
	Color(0.92, 0.92, 0.9), Color(0.12, 0.12, 0.14), Color(0.72, 0.73, 0.75),
	Color(0.42, 0.44, 0.46), Color(0.72, 0.12, 0.1), Color(0.12, 0.28, 0.62),
	Color(0.08, 0.14, 0.32), Color(0.12, 0.38, 0.22), Color(0.38, 0.24, 0.14),
	Color(0.86, 0.72, 0.12),
]
const KIT_NAMES := ["Stock", "Spoiler", "Roof", "Sport"]
const KIT_FOCUS := ["full", "spoiler", "roof", "sport"]
const RIM_NAMES := ["Steel", "Chrome", "Gold", "Black"]
const BODY_ICONS := ["Sd", "Vn", "Cv", "Sf", "Rk", "Bs", "Tk", "Cm", "Pr"]

@onready var _title: Label = $Margin/VBox/Title
@onready var _paint_row: HBoxContainer = $Margin/VBox/PaintRow
@onready var _profile_row: HBoxContainer = $Margin/VBox/ProfileRow
@onready var _info: Label = $Margin/VBox/Info
@onready var _vbox: VBoxContainer = $Margin/VBox

var _tabs: TabContainer
var _preview: SubViewportContainer
var _focus_label: Label
var _minimap_toggle: CheckButton
var _sign_density: OptionButton
var _fx_quality: OptionButton
var _audio_toggle: CheckButton
var _touch_mode: OptionButton
var _car: Node
var _profile := 0
var _paint := 0
var _kit := 0
var _rim := 0
@onready var _settings: Node = get_node_or_null("/root/GameSettings")


func _ready() -> void:
	if _settings == null:
		_settings = get_node_or_null("/root/GameSettings")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title.text = "GARAGE"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for c in _paint_row.get_children():
		c.queue_free()
	for c in _profile_row.get_children():
		c.queue_free()

	# Center stage: full car on top, options under it.
	_preview = GarageCarPreview.new()
	_preview.name = "CarPreview"
	_preview.custom_minimum_size = Vector2(640, 300)
	_vbox.add_child(_preview)
	_vbox.move_child(_preview, _title.get_index() + 1)

	_focus_label = Label.new()
	_focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_focus_label.add_theme_font_size_override("font_size", 14)
	_focus_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	_focus_label.text = "Full vehicle"
	_vbox.add_child(_focus_label)
	_vbox.move_child(_focus_label, _preview.get_index() + 1)

	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(0, 190)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(_tabs)
	_vbox.move_child(_tabs, _focus_label.get_index() + 1)

	_build_home_tab()
	_build_vehicles_tab()
	_build_paint_tab()
	_build_kits_tab()
	_build_settings_tab()

	_info.text = "Tap a part · applies live · G closes"
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visible = false


func bind_car(car: Node) -> void:
	_car = car
	_sync_indices_from_car()
	_refresh_preview("full")


func _sync_indices_from_car() -> void:
	if _car == null:
		return
	if _car.has_method("profile_index"):
		_profile = int(_car.profile_index())
	if _car.has_method("paint_index"):
		_paint = int(_car.paint_index())
	if _car.has_method("kit_index"):
		_kit = int(_car.kit_index())
	if _car.has_method("rim_index"):
		_rim = int(_car.rim_index())


func _refresh_preview(focus: String = "full") -> void:
	if _preview and _preview.has_method("rebuild"):
		_preview.call("rebuild", _profile, _paint, _kit, _rim)
	if _preview and _preview.has_method("focus_part"):
		_preview.call("focus_part", focus)
	_set_focus_caption(focus)


func _set_focus_caption(focus: String) -> void:
	if _focus_label == null:
		return
	match focus:
		"spoiler":
			_focus_label.text = "Focus · rear spoiler"
		"roof":
			_focus_label.text = "Focus · roof rack"
		"sport":
			_focus_label.text = "Focus · side skirts"
		"rim":
			_focus_label.text = "Focus · wheels"
		"paint":
			_focus_label.text = "Focus · body paint"
		_:
			_focus_label.text = "Full vehicle"


func _emit_profile(pi: int) -> void:
	_profile = pi
	profile_requested.emit(pi)
	_refresh_preview("full")


func _emit_paint(pi: int) -> void:
	_paint = pi
	paint_requested.emit(pi)
	_refresh_preview("paint")


func _emit_kit(ki: int) -> void:
	_kit = ki
	kit_requested.emit(ki)
	_refresh_preview(KIT_FOCUS[clampi(ki, 0, KIT_FOCUS.size() - 1)])


func _emit_rim(ri: int) -> void:
	_rim = ri
	rim_requested.emit(ri)
	_refresh_preview("rim")


func _icon_btn(caption: String, min_w: float = 52.0) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.custom_minimum_size = Vector2(min_w, 40)
	btn.focus_mode = Control.FOCUS_NONE
	return btn


func _build_home_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Home"
	page.add_theme_constant_override("separation", 8)
	_tabs.add_child(page)
	var quick := HBoxContainer.new()
	quick.alignment = BoxContainer.ALIGNMENT_CENTER
	quick.add_theme_constant_override("separation", 6)
	page.add_child(quick)
	var i := 0
	for entry in HomeDashboard.BODY_QUICK_PICK:
		var btn := _icon_btn(BODY_ICONS[i] if i < BODY_ICONS.size() else str(entry[0])[0], 48)
		btn.tooltip_text = str(entry[0])
		var pi: int = int(entry[1])
		btn.pressed.connect(func() -> void: _emit_profile(pi))
		quick.add_child(btn)
		i += 1


func _build_vehicles_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Cars"
	page.add_theme_constant_override("separation", 8)
	_tabs.add_child(page)
	_profile_row.get_parent().remove_child(_profile_row)
	_profile_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(_profile_row)
	var i := 0
	for entry in HomeDashboard.BODY_QUICK_PICK:
		var btn := _icon_btn(BODY_ICONS[i] if i < BODY_ICONS.size() else "?", 48)
		btn.tooltip_text = str(entry[0])
		var pi: int = int(entry[1])
		btn.pressed.connect(func() -> void: _emit_profile(pi))
		_profile_row.add_child(btn)
		i += 1


func _build_paint_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Paint"
	page.add_theme_constant_override("separation", 8)
	_tabs.add_child(page)
	_paint_row.get_parent().remove_child(_paint_row)
	_paint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(_paint_row)
	for i in PAINT_NAMES.size():
		var btn := _icon_btn("", 40)
		btn.tooltip_text = PAINT_NAMES[i]
		var sb := StyleBoxFlat.new()
		sb.bg_color = PAINT_COLORS[i]
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(2)
		sb.border_color = Color(1, 1, 1, 0.35)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		var idx := i
		btn.pressed.connect(func() -> void: _emit_paint(idx))
		_paint_row.add_child(btn)


func _build_kits_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Parts"
	page.add_theme_constant_override("separation", 10)
	_tabs.add_child(page)

	var kit_row := HBoxContainer.new()
	kit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	kit_row.add_theme_constant_override("separation", 8)
	for i in KIT_NAMES.size():
		var btn := _icon_btn(KIT_NAMES[i], 84)
		btn.tooltip_text = "Zooms to %s on Sedan / Van" % KIT_NAMES[i]
		var ki := i
		btn.pressed.connect(func() -> void: _emit_kit(ki))
		kit_row.add_child(btn)
	page.add_child(kit_row)

	var rim_row := HBoxContainer.new()
	rim_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rim_row.add_theme_constant_override("separation", 8)
	for i in RIM_NAMES.size():
		var btn := _icon_btn(RIM_NAMES[i], 84)
		btn.tooltip_text = "Wheel finish · %s" % RIM_NAMES[i]
		var ri := i
		btn.pressed.connect(func() -> void: _emit_rim(ri))
		rim_row.add_child(btn)
	page.add_child(rim_row)


func _build_settings_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Set"
	page.add_theme_constant_override("separation", 10)
	_tabs.add_child(page)

	_minimap_toggle = CheckButton.new()
	_minimap_toggle.text = "Map"
	_minimap_toggle.button_pressed = bool(_settings.get("minimap_enabled")) if _settings else true
	_minimap_toggle.toggled.connect(_on_minimap_toggled)
	page.add_child(_minimap_toggle)

	var sign_row := HBoxContainer.new()
	sign_row.add_theme_constant_override("separation", 8)
	var sign_lbl := Label.new()
	sign_lbl.text = "Signs"
	sign_row.add_child(sign_lbl)
	_sign_density = OptionButton.new()
	for label in HomeDashboard.SIGN_DENSITY_LABELS:
		_sign_density.add_item(label)
	var dens := int(_settings.get("road_sign_density")) if _settings else 1
	_sign_density.select(clampi(dens, 0, 2))
	_sign_density.item_selected.connect(_on_sign_density_selected)
	sign_row.add_child(_sign_density)
	page.add_child(sign_row)

	var fx_row := HBoxContainer.new()
	fx_row.add_theme_constant_override("separation", 8)
	var fx_lbl := Label.new()
	fx_lbl.text = "FX"
	fx_row.add_child(fx_lbl)
	_fx_quality = OptionButton.new()
	for label in HomeDashboard.FX_QUALITY_LABELS:
		_fx_quality.add_item(label)
	var fx_now := int(_settings.get("fx_quality")) if _settings else 1
	_fx_quality.select(clampi(fx_now, 0, 2))
	_fx_quality.item_selected.connect(_on_fx_selected)
	fx_row.add_child(_fx_quality)
	page.add_child(fx_row)

	_audio_toggle = CheckButton.new()
	_audio_toggle.text = "Audio"
	_audio_toggle.button_pressed = bool(_settings.get("audio_enabled")) if _settings else true
	_audio_toggle.toggled.connect(_on_audio_toggled)
	page.add_child(_audio_toggle)

	var touch_row := HBoxContainer.new()
	touch_row.add_theme_constant_override("separation", 8)
	var touch_lbl := Label.new()
	touch_lbl.text = "Touch"
	touch_row.add_child(touch_lbl)
	_touch_mode = OptionButton.new()
	for label in HomeDashboard.TOUCH_MODE_LABELS:
		_touch_mode.add_item(label)
	var touch_now := int(_settings.get("touch_controls_mode")) if _settings else 0
	_touch_mode.select(clampi(touch_now, 0, 2))
	_touch_mode.item_selected.connect(_on_touch_selected)
	touch_row.add_child(_touch_mode)
	page.add_child(touch_row)


func _on_minimap_toggled(on: bool) -> void:
	if _settings and _settings.has_method("set_minimap"):
		_settings.call("set_minimap", on)


func _on_sign_density_selected(index: int) -> void:
	if _settings and _settings.has_method("set_road_sign_density"):
		_settings.call("set_road_sign_density", index)


func _on_fx_selected(index: int) -> void:
	if _settings and _settings.has_method("set_fx_quality"):
		_settings.call("set_fx_quality", index)


func _on_audio_toggled(on: bool) -> void:
	if _settings and _settings.has_method("set_audio"):
		_settings.call("set_audio", on)


func _on_touch_selected(index: int) -> void:
	if _settings and _settings.has_method("set_touch_controls"):
		_settings.call("set_touch_controls", index)


func set_info(profile_name: String, detail: String) -> void:
	_info.text = "%s · %s" % [profile_name, detail]
	_sync_indices_from_car()
	if _preview and _preview.has_method("rebuild"):
		_preview.call("rebuild", _profile, _paint, _kit, _rim)


func toggle() -> void:
	visible = not visible
	if _preview and _preview.has_method("set_live"):
		_preview.call("set_live", visible)
	if visible:
		_sync_indices_from_car()
		_refresh_preview("full")
