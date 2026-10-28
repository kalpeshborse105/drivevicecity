extends Node3D
## Wires OSM map spawn, missions, nav arrow, vehicle HUD (P2).

@onready var _map: Node3D = $DhuleMap
@onready var _car: VehicleBody3D = $PlayerCar
@onready var _missions: Node = $DeliveryMission
@onready var _hud: CanvasLayer = $HUD
@onready var _nav: Node3D = $NavArrow


func _ready() -> void:
	if _nav.has_method("setup"):
		_nav.setup(_car)
	if _map.has_signal("map_ready"):
		_map.map_ready.connect(_on_map_ready)
	if _missions.has_signal("mission_updated"):
		_missions.mission_updated.connect(_hud.set_mission_text)
	if _missions.has_signal("stats_updated"):
		_missions.stats_updated.connect(_hud.set_stats)
	if _missions.has_signal("target_changed"):
		_missions.target_changed.connect(_on_target_changed)
	if _car.has_signal("vehicle_changed"):
		_car.vehicle_changed.connect(_hud.set_vehicle_info)
		_car.vehicle_changed.connect(_on_vehicle_changed)
	var gs := get_node_or_null("/root/GameSettings")
	if gs and gs.has_method("apply_vehicle"):
		gs.call("apply_vehicle", _car)
	if _hud.has_method("sync_player_settings"):
		_hud.sync_player_settings()


func _on_vehicle_changed(_profile: String, _detail: String) -> void:
	var gs := get_node_or_null("/root/GameSettings")
	if gs and gs.has_method("sync_from_car"):
		gs.call("sync_from_car", _car)


func _on_map_ready(spawn_position: Vector3, spawn_heading: Vector2, anchors: Array) -> void:
	if _car.has_method("set_spawn"):
		_car.set_spawn(spawn_position, spawn_heading)
	else:
		_car.global_position = spawn_position
	if _missions.has_method("start_with_anchors"):
		_missions.start_with_anchors(anchors)
	# On-screen self-check summary after map wires up
	var status := "OK map+%d anchors · vehicle ready · G or Customize" % anchors.size()
	if _hud.has_method("set_test_status"):
		_hud.set_test_status(status)


func _on_target_changed(world_pos: Vector3, active: bool) -> void:
	if _nav.has_method("set_target"):
		_nav.set_target(world_pos, active)
	if _hud.has_method("set_distance_to_target"):
		_hud.set_distance_to_target(world_pos, active, _car)
