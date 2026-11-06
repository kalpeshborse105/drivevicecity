extends Node3D
## Live Dhule satellite ground from the official Google Map Tiles API.
## Key is read from res://google key.txt at runtime and is never written here.
## Tiles stay in memory for this session only. They are not saved into the project.

const CENTER_LAT := 20.90251
const CENTER_LON := 74.76819
const MIN_LAT := 20.84
const MAX_LAT := 20.96
const MIN_LON := 74.72
const MAX_LON := 74.82
const ZOOM := 18
const RADIUS := 2
const KEY_PATH := "res://google key.txt"
## Preferred key location: user:// is NOT packaged into the exported game, so the
## API key never ships inside the APK. res:// is only a legacy fallback.
const USER_KEY_PATH := "user://google_key.txt"

var _key := ""
var _session := ""
var _http: HTTPRequest
var _status: Label
var _tiles_root: Node3D
var _car: Node3D
var _ground: StaticBody3D
var _tile_m := 140.0
var _origin := Vector2i.ZERO
var _loaded: Dictionary = {}
var _queued: Dictionary = {}
var _queue: Array[Vector2i] = []
var _busy := false
var _ready_to_drive := false


func _ready() -> void:
	_status = get_node_or_null("HUD/Status") as Label
	_tiles_root = get_node_or_null("Tiles") as Node3D
	_car = get_node_or_null("PlayerCar") as Node3D
	_http = HTTPRequest.new()
	_http.timeout = 30.0
	add_child(_http)
	_set_status("Reading map key")
	_key = _read_key()
	if _key == "":
		_set_status("Put your Google key in user://google_key.txt")
		return
	_open_session()


func _process(_delta: float) -> void:
	if not _ready_to_drive or _car == null:
		return
	if _ground:
		_ground.position = Vector3(_car.position.x, -0.15, _car.position.z)
	var here := _world_to_tile(_car.position)
	_request_around(here)
	_drop_far(here)
	if not _busy:
		_pump()


func _read_key() -> String:
	## user:// first (not packaged). Legacy res:// fallback keeps existing setups working.
	for path in [USER_KEY_PATH, KEY_PATH]:
		if FileAccess.file_exists(path):
			var text := FileAccess.get_file_as_string(path).strip_edges()
			if text != "":
				return text.split("\n")[0].strip_edges()
	return ""


func _open_session() -> void:
	_set_status("Opening Google map")
	var body := JSON.stringify({
		"mapType": "satellite",
		"language": "en-US",
		"region": "IN",
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := "https://tile.googleapis.com/v1/createSession?key=" + _key.uri_encode()
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_set_status("Could not start the map request")
		return
	var result: Array = await _http.request_completed
	var code := int(result[1])
	var raw: PackedByteArray = result[3]
	if code != 200:
		_set_status("Google map refused the key (%d). %s" % [code, _google_error(raw)])
		push_warning("Google session HTTP %d" % code)
		return
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("session"):
		_set_status("Google map did not return a session")
		return
	_session = str((parsed as Dictionary)["session"])
	_tile_m = _meters_per_tile(CENTER_LAT, ZOOM)
	_origin = _latlon_to_tile(CENTER_LAT, CENTER_LON, ZOOM)
	_add_ground()
	_request_around(_origin)
	await _pump()
	if _loaded.is_empty():
		_set_status("No map tiles arrived. Check that Map Tiles API is enabled.")
		return
	_ready_to_drive = true
	_set_status("Shivtirth Chowk    WASD drive    Map data © Google")


func _request_around(origin: Vector2i) -> void:
	for dy in range(-RADIUS, RADIUS + 1):
		for dx in range(-RADIUS, RADIUS + 1):
			var tile := Vector2i(origin.x + dx, origin.y + dy)
			if _loaded.has(tile) or _queued.has(tile):
				continue
			if not _tile_in_dhule(tile):
				continue
			_queued[tile] = true
			_queue.append(tile)


func _pump() -> void:
	if _busy:
		return
	_busy = true
	while not _queue.is_empty():
		var tile: Vector2i = _queue.pop_front()
		_queued.erase(tile)
		if _loaded.has(tile):
			continue
		if _car != null and _ready_to_drive:
			var here := _world_to_tile(_car.position)
			if absi(tile.x - here.x) > RADIUS + 1 or absi(tile.y - here.y) > RADIUS + 1:
				continue
		await _load_tile(tile)
	_busy = false


func _load_tile(tile: Vector2i) -> void:
	var url := "https://tile.googleapis.com/v1/2dtiles/%d/%d/%d?session=%s&key=%s" % [
		ZOOM, tile.x, tile.y, _session.uri_encode(), _key.uri_encode()
	]
	var err := _http.request(url)
	if err != OK:
		return
	var result: Array = await _http.request_completed
	if int(result[1]) != 200:
		return
	var image := Image.new()
	var raw: PackedByteArray = result[3]
	if image.load_jpg_from_buffer(raw) != OK and image.load_png_from_buffer(raw) != OK:
		return
	var tex := ImageTexture.create_from_image(image)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.roughness = 1.0
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(_tile_m, _tile_m)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = _tile_to_world(tile)
	_tiles_root.add_child(mi)
	_loaded[tile] = mi


func _drop_far(origin: Vector2i) -> void:
	var keep := RADIUS + 2
	var gone: Array[Vector2i] = []
	for key in _loaded.keys():
		var tile: Vector2i = key
		if absi(tile.x - origin.x) > keep or absi(tile.y - origin.y) > keep:
			gone.append(tile)
	for tile in gone:
		var node: Node = _loaded[tile]
		_loaded.erase(tile)
		if is_instance_valid(node):
			node.queue_free()


func _add_ground() -> void:
	var span := _tile_m * float(RADIUS * 2 + 3)
	_ground = StaticBody3D.new()
	_ground.position = Vector3(0, -0.15, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(span, 0.3, span)
	shape.shape = box
	_ground.add_child(shape)
	add_child(_ground)


func _set_status(text: String) -> void:
	if _status:
		_status.text = text
	print("GOOGLE_MAP %s" % text)


func _world_to_tile(world: Vector3) -> Vector2i:
	return Vector2i(
		_origin.x + int(round(world.x / _tile_m)),
		_origin.y + int(round(world.z / _tile_m))
	)


func _tile_to_world(tile: Vector2i) -> Vector3:
	return Vector3(
		float(tile.x - _origin.x) * _tile_m,
		0.0,
		float(tile.y - _origin.y) * _tile_m
	)


func _tile_in_dhule(tile: Vector2i) -> bool:
	var latlon := _tile_center_latlon(tile.x, tile.y, ZOOM)
	return latlon.x >= MIN_LAT and latlon.x <= MAX_LAT and latlon.y >= MIN_LON and latlon.y <= MAX_LON


static func _google_error(raw: PackedByteArray) -> String:
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(parsed) == TYPE_DICTIONARY:
		var root: Dictionary = parsed
		var err: Variant = root.get("error", {})
		if typeof(err) == TYPE_DICTIONARY:
			return str((err as Dictionary).get("message", "Enable the Map Tiles API."))
	return "Enable the Map Tiles API, and do not restrict this key to websites."


static func _latlon_to_tile(lat: float, lon: float, zoom: int) -> Vector2i:
	var n := pow(2.0, float(zoom))
	var x := int(floor((lon + 180.0) / 360.0 * n))
	var lat_rad := deg_to_rad(lat)
	var y := int(floor((1.0 - log(tan(lat_rad) + 1.0 / cos(lat_rad)) / PI) / 2.0 * n))
	return Vector2i(x, y)


static func _tile_center_latlon(tx: int, ty: int, zoom: int) -> Vector2:
	var n := pow(2.0, float(zoom))
	var lon := ((float(tx) + 0.5) / n) * 360.0 - 180.0
	var merc := PI * (1.0 - 2.0 * (float(ty) + 0.5) / n)
	var lat := rad_to_deg(atan(sinh(merc)))
	return Vector2(lat, lon)


static func _meters_per_tile(lat: float, zoom: int) -> float:
	return 156543.03392 * cos(deg_to_rad(lat)) / pow(2.0, float(zoom)) * 256.0
