extends PanelContainer
## Simple on-screen garage: paint + vehicle switch (G to toggle).

signal paint_requested(index: int)
signal profile_requested(index: int)

@onready var _title: Label = $Margin/VBox/Title
@onready var _paint_row: HBoxContainer = $Margin/VBox/PaintRow
@onready var _profile_row: HBoxContainer = $Margin/VBox/ProfileRow
@onready var _info: Label = $Margin/VBox/Info

const PAINT_NAMES := ["Saffron", "Blue", "Red", "Green", "White", "Black", "Silver"]
const PAINT_COLORS := [
	Color(0.85, 0.55, 0.12),
	Color(0.12, 0.35, 0.7),
	Color(0.82, 0.15, 0.12),
	Color(0.15, 0.55, 0.28),
	Color(0.92, 0.92, 0.9),
	Color(0.12, 0.12, 0.14),
	Color(0.55, 0.55, 0.58),
]


func _ready() -> void:
	_title.text = "Garage"
	for i in PAINT_NAMES.size():
		var btn := Button.new()
		btn.text = PAINT_NAMES[i]
		btn.custom_minimum_size = Vector2(72, 32)
		var sb := StyleBoxFlat.new()
		sb.bg_color = PAINT_COLORS[i]
		sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sb)
		var idx := i
		btn.pressed.connect(func() -> void: paint_requested.emit(idx))
		_paint_row.add_child(btn)

	var sedan := Button.new()
	sedan.text = "Sedan"
	sedan.pressed.connect(func() -> void: profile_requested.emit(0))
	_profile_row.add_child(sedan)
	var van := Button.new()
	van.text = "Delivery Van"
	van.pressed.connect(func() -> void: profile_requested.emit(1))
	_profile_row.add_child(van)
	_info.text = "Hotkeys: P paint · V vehicle · G close"
	visible = false


func set_info(profile_name: String, paint_name: String) -> void:
	_info.text = "Current: %s · %s   (G close)" % [profile_name, paint_name]


func toggle() -> void:
	visible = not visible
