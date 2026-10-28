extends Node
## Player prefs + last garage loadout (user://drivevicecity.cfg).
## Autoload node path: /root/GameSettings (access via get_node, not a global id).

signal settings_changed

const CFG_PATH := "user://drivevicecity.cfg"

var minimap_enabled: bool = true
## 0 = quiet, 1 = normal, 2 = more road-name signs (next map load).
var road_sign_density: int = 1
## Default body = Carnival (kit GLB) so Play shows an incoming vehicle immediately.
var profile_index: int = 2
var paint_index: int = 0
var kit_index: int = 0
var rim_index: int = 0


func _ready() -> void:
	load_cfg()


func road_sign_max() -> int:
	match road_sign_density:
		0:
			return 5
		1:
			return 10
		_:
			return 18


func load_cfg() -> void:
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) != OK:
		save_cfg()
		return
	minimap_enabled = bool(cf.get_value("settings", "minimap_enabled", true))
	road_sign_density = int(cf.get_value("settings", "road_sign_density", 1))
	profile_index = int(cf.get_value("vehicle", "profile_index", 2))
	paint_index = int(cf.get_value("vehicle", "paint_index", 0))
	kit_index = int(cf.get_value("vehicle", "kit_index", 0))
	rim_index = int(cf.get_value("vehicle", "rim_index", 0))
	road_sign_density = clampi(road_sign_density, 0, 2)
	profile_index = clampi(profile_index, 0, 6)
	paint_index = clampi(paint_index, 0, 9)
	kit_index = clampi(kit_index, 0, 3)
	rim_index = clampi(rim_index, 0, 3)
	# One-time bump: older saves defaulted to box sedan — switch to Carnival kit
	var meta_ver := int(cf.get_value("meta", "ver", 0))
	if meta_ver < 1:
		profile_index = 2
		save_cfg()


func save_cfg() -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "ver", 1)
	cf.set_value("settings", "minimap_enabled", minimap_enabled)
	cf.set_value("settings", "road_sign_density", road_sign_density)
	cf.set_value("vehicle", "profile_index", profile_index)
	cf.set_value("vehicle", "paint_index", paint_index)
	cf.set_value("vehicle", "kit_index", kit_index)
	cf.set_value("vehicle", "rim_index", rim_index)
	cf.save(CFG_PATH)


func set_minimap(enabled: bool) -> void:
	minimap_enabled = enabled
	save_cfg()
	settings_changed.emit()


func set_road_sign_density(level: int) -> void:
	road_sign_density = clampi(level, 0, 2)
	save_cfg()
	settings_changed.emit()


func record_paint(index: int) -> void:
	paint_index = clampi(index, 0, 9)
	save_cfg()


func record_profile(index: int) -> void:
	profile_index = clampi(index, 0, 6)
	save_cfg()


func record_kit(index: int) -> void:
	kit_index = clampi(index, 0, 3)
	save_cfg()


func record_rim(index: int) -> void:
	rim_index = clampi(index, 0, 3)
	save_cfg()


func sync_from_car(car: Node) -> void:
	if car == null:
		return
	if car.has_method("profile_index"):
		profile_index = clampi(int(car.profile_index()), 0, 6)
	if car.has_method("paint_index"):
		paint_index = clampi(int(car.paint_index()), 0, 9)
	if car.has_method("kit_index"):
		kit_index = clampi(int(car.kit_index()), 0, 3)
	if car.has_method("rim_index"):
		rim_index = clampi(int(car.rim_index()), 0, 3)
	save_cfg()


func apply_vehicle(car: Node) -> void:
	if car == null:
		return
	if car.has_method("apply_profile_index"):
		car.apply_profile_index(profile_index)
	if car.has_method("apply_paint_index"):
		car.apply_paint_index(paint_index)
	if car.has_method("apply_kit_index"):
		car.apply_kit_index(kit_index)
	if car.has_method("apply_rim_index"):
		car.apply_rim_index(rim_index)
