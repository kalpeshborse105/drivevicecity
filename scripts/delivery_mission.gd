extends Node
## P2 jobs: parcel / food / passenger — pickup → dropoff → cash → next job.

signal mission_updated(text: String)
signal stats_updated(cash: int, completed: int, carrying: bool, job_type: String)
signal target_changed(world_pos: Vector3, active: bool)

enum Phase { IDLE, TO_PICKUP, TO_DROPOFF }
enum JobType { PARCEL, FOOD, PASSENGER }

const JOB_META := {
	JobType.PARCEL: {
		"name": "Parcel",
		"pickup": "PICK UP PARCEL",
		"drop": "DELIVER PARCEL",
		"carry": "PARCEL",
		"color_pick": Color(0.15, 0.9, 0.35, 0.5),
		"color_drop": Color(0.95, 0.55, 0.1, 0.55),
		"base": 80,
		"per_m": 0.35,
	},
	JobType.FOOD: {
		"name": "Food",
		"pickup": "PICK UP FOOD",
		"drop": "DELIVER FOOD",
		"carry": "FOOD",
		"color_pick": Color(0.95, 0.25, 0.35, 0.5),
		"color_drop": Color(0.95, 0.7, 0.15, 0.55),
		"base": 60,
		"per_m": 0.42,
	},
	JobType.PASSENGER: {
		"name": "Passenger",
		"pickup": "PICK UP RIDER",
		"drop": "DROP RIDER",
		"carry": "RIDER",
		"color_pick": Color(0.25, 0.55, 0.95, 0.5),
		"color_drop": Color(0.55, 0.35, 0.95, 0.55),
		"base": 100,
		"per_m": 0.48,
	},
}

@export var zone_scene: PackedScene
@export var car_path: NodePath
@export var min_job_distance: float = 80.0

var _car: VehicleBody3D
var _anchors: Array = []
var _pickup: Area3D
var _dropoff: Area3D
var _phase: Phase = Phase.IDLE
var _job: JobType = JobType.PARCEL
var _cash: int = 0
var _completed: int = 0
var _carrying: bool = false
var _job_distance: float = 0.0
var _pickup_index: int = -1
var _dropoff_index: int = -1


func _ready() -> void:
	if car_path != NodePath(""):
		_car = get_node_or_null(car_path) as VehicleBody3D
	_pickup = zone_scene.instantiate()
	_dropoff = zone_scene.instantiate()
	add_child(_pickup)
	add_child(_dropoff)
	_pickup.car_entered.connect(_on_pickup_entered)
	_dropoff.car_entered.connect(_on_dropoff_entered)
	_pickup.deactivate()
	_dropoff.deactivate()


func start_with_anchors(anchors: Array) -> void:
	_anchors = []
	for a in anchors:
		if typeof(a) == TYPE_DICTIONARY and a.has("pos"):
			_anchors.append(a)
		elif typeof(a) == TYPE_VECTOR3:
			_anchors.append({"pos": a, "heading": Vector2(0, -1), "road": ""})
	if _anchors.size() < 2:
		mission_updated.emit("Not enough map anchors for deliveries.")
		target_changed.emit(Vector3.ZERO, false)
		return
	_start_new_job()


func get_active_target() -> Vector3:
	if _phase == Phase.TO_PICKUP and _pickup_index >= 0:
		return (_anchors[_pickup_index] as Dictionary)["pos"]
	if _phase == Phase.TO_DROPOFF and _dropoff_index >= 0:
		return (_anchors[_dropoff_index] as Dictionary)["pos"]
	return Vector3.ZERO


func _anchor_pos(i: int) -> Vector3:
	return (_anchors[i] as Dictionary)["pos"]


func _start_new_job() -> void:
	if _anchors.size() < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_job = [JobType.PARCEL, JobType.FOOD, JobType.PASSENGER][rng.randi_range(0, 2)] as JobType
	_pickup_index = -1
	_dropoff_index = -1

	var attempts := 0
	while attempts < 50:
		attempts += 1
		var i := rng.randi_range(0, _anchors.size() - 1)
		var j := rng.randi_range(0, _anchors.size() - 1)
		if i == j:
			continue
		var dist := _anchor_pos(i).distance_to(_anchor_pos(j))
		if dist < min_job_distance:
			continue
		_pickup_index = i
		_dropoff_index = j
		_job_distance = dist
		break

	if _pickup_index < 0:
		_pickup_index = 0
		_dropoff_index = mini(1, _anchors.size() - 1)
		_job_distance = _anchor_pos(_pickup_index).distance_to(_anchor_pos(_dropoff_index))

	var meta: Dictionary = JOB_META[_job]
	_carrying = false
	_phase = Phase.TO_PICKUP
	_pickup.configure(_anchor_pos(_pickup_index), str(meta["pickup"]), meta["color_pick"])
	_dropoff.deactivate()
	var road := str((_anchors[_pickup_index] as Dictionary).get("road", ""))
	var road_bit := (" @ " + road) if road != "" else ""
	mission_updated.emit(
		"%s job%s — go to pickup · est. ₹%d" % [meta["name"], road_bit, _estimate_payout()]
	)
	stats_updated.emit(_cash, _completed, _carrying, str(meta["name"]))
	target_changed.emit(_anchor_pos(_pickup_index), true)


func _estimate_payout() -> int:
	var meta: Dictionary = JOB_META[_job]
	return int(meta["base"]) + int(_job_distance * float(meta["per_m"]))


func _on_pickup_entered(_zone: Area3D) -> void:
	if _phase != Phase.TO_PICKUP:
		return
	var meta: Dictionary = JOB_META[_job]
	_carrying = true
	_phase = Phase.TO_DROPOFF
	_pickup.deactivate()
	_dropoff.configure(_anchor_pos(_dropoff_index), str(meta["drop"]), meta["color_drop"])
	mission_updated.emit("%s on board — drive to dropoff" % meta["name"])
	stats_updated.emit(_cash, _completed, _carrying, str(meta["name"]))
	target_changed.emit(_anchor_pos(_dropoff_index), true)


func _on_dropoff_entered(_zone: Area3D) -> void:
	if _phase != Phase.TO_DROPOFF or not _carrying:
		return
	var meta: Dictionary = JOB_META[_job]
	var pay := _estimate_payout()
	_cash += pay
	_completed += 1
	_carrying = false
	_phase = Phase.IDLE
	_dropoff.deactivate()
	mission_updated.emit("%s done! +₹%d · Total ₹%d (%d jobs)" % [meta["name"], pay, _cash, _completed])
	stats_updated.emit(_cash, _completed, _carrying, str(meta["name"]))
	target_changed.emit(Vector3.ZERO, false)
	await get_tree().create_timer(1.35).timeout
	_start_new_job()
