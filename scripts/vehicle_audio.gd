extends Node3D
## Layered vehicle + city audio. Original WAVs in assets/audio/. Parent = VehicleBody3D.
## Avoids overlapping same one-shots; volumes stay modest.

var _car: VehicleBody3D
var _idle: AudioStreamPlayer3D
var _accel: AudioStreamPlayer3D
var _horn: AudioStreamPlayer3D
var _screech: AudioStreamPlayer3D
var _impact: AudioStreamPlayer3D
var _ambience: AudioStreamPlayer
var _screech_cd: float = 0.0
var _enabled: bool = true


func _ready() -> void:
	_car = get_parent() as VehicleBody3D
	var gs := get_node_or_null("/root/GameSettings")
	if gs and gs.get("audio_enabled") != null:
		_enabled = bool(gs.audio_enabled)
	_idle = _make3d("Idle", "res://assets/audio/engine_idle.wav", -20.0, true)
	_accel = _make3d("Accel", "res://assets/audio/engine_accel.wav", -28.0, true)
	_horn = _make3d("Horn", "res://assets/audio/horn.wav", -10.0, false)
	_screech = _make3d("Screech", "res://assets/audio/tire_screech.wav", -16.0, false)
	_impact = _make3d("Impact", "res://assets/audio/collision_thud.wav", -8.0, false)
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "CityAmbience"
	_ambience.volume_db = -28.0
	_ambience.bus = &"Master"
	add_child(_ambience)
	if ResourceLoader.exists("res://assets/audio/city_ambience.wav"):
		var s: AudioStream = load("res://assets/audio/city_ambience.wav")
		if s is AudioStreamWAV:
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_ambience.stream = s
		if _enabled:
			_ambience.play()
	if _enabled and _idle.stream:
		_idle.play()
	if _enabled and _accel.stream:
		_accel.play()


func _make3d(n: String, path: String, vol: float, loop: bool) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = n
	p.volume_db = vol
	p.max_distance = 60.0
	p.bus = &"Master"
	add_child(p)
	if ResourceLoader.exists(path):
		var s: AudioStream = load(path)
		if loop and s is AudioStreamWAV:
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		p.stream = s
	return p


func _physics_process(delta: float) -> void:
	if not _enabled or _car == null:
		return
	_screech_cd = maxf(_screech_cd - delta, 0.0)
	var speed_kph := _car.linear_velocity.length() * 3.6
	var throttle := absf(_car.engine_force) / maxf(_car.get("engine_force_value") if _car.get("engine_force_value") else 640.0, 1.0)
	throttle = clampf(throttle, 0.0, 1.0)
	var t := clampf(speed_kph / 140.0, 0.0, 1.0)
	if _idle.stream:
		_idle.pitch_scale = lerpf(0.85, 1.15, t)
		_idle.volume_db = lerpf(-18.0, -26.0, throttle)
		if not _idle.playing:
			_idle.play()
	if _accel.stream:
		_accel.pitch_scale = lerpf(0.9, 1.45, t)
		_accel.volume_db = lerpf(-32.0, -12.0, maxf(throttle, t * 0.5))
		if not _accel.playing:
			_accel.play()
	# Horn (H) — one-shot, no stack
	if Input.is_physical_key_pressed(KEY_H):
		if _horn.stream and not _horn.playing:
			_horn.play()
	# Screech on slip / handbrake
	var lat := absf(_car.linear_velocity.dot(_car.global_transform.basis.x))
	var hb := Input.is_action_pressed("handbrake") or Input.is_physical_key_pressed(KEY_SPACE)
	if (lat > 4.0 or hb) and speed_kph > 20.0 and _screech_cd <= 0.0:
		if _screech.stream and not _screech.playing:
			_screech.play()
			_screech_cd = 0.55


func play_collision() -> void:
	if not _enabled or _impact.stream == null:
		return
	if _impact.playing:
		_impact.stop()
	_impact.play()
