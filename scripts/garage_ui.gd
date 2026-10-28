extends PanelContainer
## Home dashboard: vehicles · paint · kits · settings (G or HUD Customize).

signal paint_requested(index: int)
signal profile_requested(index: int)
signal kit_requested(index: int)
signal rim_requested(index: int)

const HomeDashboard = preload("res://scripts/home_dashboard.gd")

@onready var _title: Label = $Margin/VBox/Title
@onready var _paint_row: HBoxContainer = $Margin/VBox/PaintRow
@onready var _profile_row: HBoxContainer = $Margin/VBox/ProfileRow
@onready var _info: Label = $Margin/VBox/Info
@onready var _vbox: VBoxContainer = $Margin/VBox

const PAINT_NAMES := [
	"Saffron", "Blue", "Red", "Green", "White", "Black", "Silver",
	"Taxi Yellow", "Royal Purple", "Teal"
]
const PAINT_COLORS := [
	Color(0.85, 0.55, 0.12),
	Color(0.12, 0.35, 0.7),
	Color(0.82, 0.15, 0.12),
	Color(0.15, 0.55, 0.28),
	Color(0.92, 0.92, 0.9),
	Color(0.12, 0.12, 0.14),
	Color(0.55, 0.55, 0.58),
	Color(0.95, 0.75, 0.15),
	Color(0.55, 0.15, 0.55),
	Color(0.1, 0.55, 0.55),
]
const KIT_NAMES := ["Stock", "Spoiler", "Roof Rack", "Sport"]
const RIM_NAMES := ["Steel", "Chrome", "Gold", "Black"]

var _tabs: TabContainer
var _minimap_toggle: CheckButton
var _sign_density: OptionButton
@onready var _settings: Node = get_node_or_null("/root/GameSettings")


func _ready() -> void:
	if _settings == null:
		_settings = get_node_or_null("/root/GameSettings")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title.text = "Home — Customize"
	for c in _paint_row.get_children():
		c.queue_free()
	for c in _profile_row.get_children():
		c.queue_free()

	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(520, 300)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(_tabs)
	_vbox.move_child(_tabs, _title.get_index() + 1)

	_build_home_tab()
	_build_vehicles_tab()
	_build_paint_tab()
	_build_kits_tab()
	_build_settings_tab()

	_info.text = "G / Esc / Customize closes · Vehicle · Paint · Kits · Settings all apply live"
	visible = false


func _build_home_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Home"
	page.add_theme_constant_override("separation", 10)
	_tabs.add_child(page)

	var hint := Label.new()
	hint.text = "Quick pick vehicle"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(hint)

	var quick := HBoxContainer.new()
	quick.alignment = BoxContainer.ALIGNMENT_CENTER
	quick.add_theme_constant_override("separation", 8)
	page.add_child(quick)

	for entry in HomeDashboard.BODY_QUICK_PICK:
		var btn := Button.new()
		btn.text = str(entry[0])
		btn.custom_minimum_size = Vector2(72, 40)
		var pi: int = int(entry[1])
		btn.pressed.connect(func() -> void: profile_requested.emit(pi))
		quick.add_child(btn)

	var sub := Label.new()
	sub.text = "Use tabs for paint, body kits, rims, and display settings."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(sub)


func _build_vehicles_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Vehicles"
	page.add_theme_constant_override("separation", 8)
	_tabs.add_child(page)

	var lbl := Label.new()
	lbl.text = "Body style"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(lbl)

	# Reparent scene rows into tabs (must remove_child first)
	_profile_row.get_parent().remove_child(_profile_row)
	_profile_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(_profile_row)

	var bodies := HomeDashboard.BODY_QUICK_PICK
	for entry in bodies:
		var btn := Button.new()
		btn.text = str(entry[0])
		btn.custom_minimum_size = Vector2(72, 36)
		var pi: int = int(entry[1])
		btn.pressed.connect(func() -> void: profile_requested.emit(pi))
		_profile_row.add_child(btn)


func _build_paint_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Paint"
	page.add_theme_constant_override("separation", 8)
	_tabs.add_child(page)

	var lbl := Label.new()
	lbl.text = "Paint color"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(lbl)

	_paint_row.get_parent().remove_child(_paint_row)
	_paint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(_paint_row)

	for i in PAINT_NAMES.size():
		var btn := Button.new()
		btn.text = PAINT_NAMES[i]
		btn.custom_minimum_size = Vector2(64, 30)
		var sb := StyleBoxFlat.new()
		sb.bg_color = PAINT_COLORS[i]
		sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sb)
		var idx := i
		btn.pressed.connect(func() -> void: paint_requested.emit(idx))
		_paint_row.add_child(btn)


func _build_kits_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Kits"
	page.add_theme_constant_override("separation", 10)
	_tabs.add_child(page)

	var note := Label.new()
	note.text = "Body kits change Sedan / Van meshes. Carnival · Safari · Bus · Truck use kit GLBs (paint + rims still apply)."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(note)

	var kit_label := Label.new()
	kit_label.text = "Body kit (Sedan / Van)"
	kit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(kit_label)

	var kit_row := HBoxContainer.new()
	kit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	kit_row.add_theme_constant_override("separation", 6)
	for i in KIT_NAMES.size():
		var btn := Button.new()
		btn.text = KIT_NAMES[i]
		btn.custom_minimum_size = Vector2(88, 36)
		var ki := i
		btn.pressed.connect(func() -> void: kit_requested.emit(ki))
		kit_row.add_child(btn)
	page.add_child(kit_row)

	var rim_label := Label.new()
	rim_label.text = "Rims"
	rim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(rim_label)

	var rim_row := HBoxContainer.new()
	rim_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rim_row.add_theme_constant_override("separation", 6)
	for i in RIM_NAMES.size():
		var btn := Button.new()
		btn.text = RIM_NAMES[i]
		btn.custom_minimum_size = Vector2(88, 36)
		var ri := i
		btn.pressed.connect(func() -> void: rim_requested.emit(ri))
		rim_row.add_child(btn)
	page.add_child(rim_row)


func _build_settings_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Settings"
	page.add_theme_constant_override("separation", 12)
	_tabs.add_child(page)

	_minimap_toggle = CheckButton.new()
	_minimap_toggle.text = "Show minimap"
	_minimap_toggle.button_pressed = bool(_settings.get("minimap_enabled")) if _settings else true
	_minimap_toggle.toggled.connect(_on_minimap_toggled)
	page.add_child(_minimap_toggle)

	var sign_row := HBoxContainer.new()
	sign_row.add_theme_constant_override("separation", 8)
	var sign_lbl := Label.new()
	sign_lbl.text = "Road name signs"
	sign_row.add_child(sign_lbl)
	_sign_density = OptionButton.new()
	for label in HomeDashboard.SIGN_DENSITY_LABELS:
		_sign_density.add_item(label)
	var dens := int(_settings.get("road_sign_density")) if _settings else 1
	_sign_density.select(clampi(dens, 0, 2))
	_sign_density.item_selected.connect(_on_sign_density_selected)
	sign_row.add_child(_sign_density)
	page.add_child(sign_row)

	var note := Label.new()
	note.text = "Sign density applies on next game launch (map rebuild)."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(note)

	var guide := Label.new()
	guide.text = (
		"HOW TO PLAY\n"
		+ "PC: W/S drive · A/D steer · Space handbrake · R reset · V next car · P paint\n"
		+ "Look: hold Right-Mouse (or Left-drag empty view) and move — 360° orbit\n"
		+ "Map: + / − on minimap (or mouse wheel over it)\n"
		+ "Android: on-screen drive pad · drag finger on empty view to look · tap +/− on map\n"
		+ "Menus: G / Customize / Esc = Home (Vehicles · Paint · Kits · Settings)"
	)
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_font_size_override("font_size", 13)
	page.add_child(guide)


func _on_minimap_toggled(on: bool) -> void:
	if _settings and _settings.has_method("set_minimap"):
		_settings.call("set_minimap", on)


func _on_sign_density_selected(index: int) -> void:
	if _settings and _settings.has_method("set_road_sign_density"):
		_settings.call("set_road_sign_density", index)


func set_info(profile_name: String, detail: String) -> void:
	_info.text = "Current: %s · %s   (G / Customize to close)" % [profile_name, detail]


func toggle() -> void:
	visible = not visible
