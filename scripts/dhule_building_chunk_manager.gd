extends Node3D
## Reusable spatial chunk manager for Dhule building neighbourhoods.
## Loads / unloads batched BuildingShell chunks by player distance.
## Does not generate new buildings — only registered manifest sources.


const BuildingShell = preload("res://scripts/building_shell.gd")
const DhuleBuildingStyles = preload("res://scripts/dhule_building_styles.gd")
const AssetPlacementValidator = preload("res://scripts/asset_placement_validator.gd")

const DEFAULT_LOAD_M := 480.0
const DEFAULT_UNLOAD_M := 720.0

signal chunk_loaded(chunk_id: String)
signal chunk_unloaded(chunk_id: String)
signal chunk_failed(chunk_id: String, reason: String)

@export var load_radius_m: float = DEFAULT_LOAD_M
@export var unload_radius_m: float = DEFAULT_UNLOAD_M
@export var auto_stream: bool = true

## id -> { id, manifest, clearance, origin: Vector3, label }
var _defs: Dictionary = {}
## id -> loaded root Node3D
var _loaded: Dictionary = {}
## id -> true while a load is in progress (blocks double load)
var _busy: Dictionary = {}
## id -> last error string
var _errors: Dictionary = {}
## id -> meta rows for OSM inspection
var _meta: Dictionary = {}
## id -> last load/unload timings ms
var _timings: Dictionary = {}

var _player: Node3D
var _road_segments: Array = []
var _manual_lock: bool = false


func set_player(player: Node3D) -> void:
	_player = player


func set_road_segments(segments: Array) -> void:
	_road_segments = segments


func set_manual_lock(locked: bool) -> void:
	## When locked, distance streaming is paused (probe force modes).
	_manual_lock = locked


func register_chunk(def: Dictionary) -> void:
	var id := str(def.get("id", ""))
	if id.is_empty():
		push_warning("DhuleBuildingChunkManager: register_chunk missing id")
		return
	var origin_v = def.get("origin", Vector3.ZERO)
	var origin := origin_v as Vector3 if origin_v is Vector3 else Vector3(
		float(origin_v.get("x", 0.0)),
		float(origin_v.get("y", 0.0)),
		float(origin_v.get("z", 0.0))
	)
	_defs[id] = {
		"id": id,
		"manifest": str(def.get("manifest", "")),
		"clearance": str(def.get("clearance", "")),
		"origin": origin,
		"label": str(def.get("label", id)),
	}


func chunk_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in _defs.keys():
		out.append(str(id))
	out.sort()
	return out


func is_loaded(chunk_id: String) -> bool:
	return _loaded.has(chunk_id) and is_instance_valid(_loaded[chunk_id])


func get_origin(chunk_id: String) -> Vector3:
	if not _defs.has(chunk_id):
		return Vector3.ZERO
	return _defs[chunk_id]["origin"] as Vector3


func get_meta_rows(chunk_id: String) -> Array:
	return _meta.get(chunk_id, []) as Array


func get_chunk_root(chunk_id: String) -> Node3D:
	if not is_loaded(chunk_id):
		return null
	return _loaded[chunk_id] as Node3D


func active_chunk_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in _loaded.keys():
		if is_loaded(str(id)):
			out.append(str(id))
	out.sort()
	return out


func status() -> Dictionary:
	var rows: Array = []
	for id_v in _defs.keys():
		var id := str(id_v)
		var origin: Vector3 = _defs[id]["origin"]
		var dist := -1.0
		if _player:
			dist = Vector2(_player.global_position.x - origin.x, _player.global_position.z - origin.z).length()
		rows.append({
			"id": id,
			"loaded": is_loaded(id),
			"busy": _busy.get(id, false),
			"error": str(_errors.get(id, "")),
			"origin": {"x": origin.x, "z": origin.z},
			"dist_m": snapped(dist, 0.1),
			"buildings": (_meta.get(id, []) as Array).size(),
			"timing_ms": _timings.get(id, {}),
		})
	return {
		"active": active_chunk_ids(),
		"load_radius_m": load_radius_m,
		"unload_radius_m": unload_radius_m,
		"manual_lock": _manual_lock,
		"chunks": rows,
	}


func count_collision_bodies(chunk_id: String = "") -> int:
	var n := 0
	var ids: Array = [chunk_id] if not chunk_id.is_empty() else _loaded.keys()
	for id_v in ids:
		var id := str(id_v)
		if not is_loaded(id):
			continue
		var root: Node3D = _loaded[id]
		n += _count_static(root)
	return n


func count_surfaces(chunk_id: String = "") -> int:
	var n := 0
	var ids: Array = [chunk_id] if not chunk_id.is_empty() else _loaded.keys()
	for id_v in ids:
		var id := str(id_v)
		if not is_loaded(id):
			continue
		var shell := (_loaded[id] as Node).find_child("Shell", true, false) as MeshInstance3D
		if shell and shell.mesh:
			n += shell.mesh.get_surface_count()
	return n


func force_load(chunk_id: String) -> bool:
	return _load_chunk(chunk_id)


func force_unload(chunk_id: String) -> void:
	_unload_chunk(chunk_id)


func force_load_only(keep_ids: PackedStringArray) -> void:
	for id_v in _defs.keys():
		var id := str(id_v)
		if keep_ids.has(id):
			_load_chunk(id)
		else:
			_unload_chunk(id)


func force_load_all() -> void:
	for id_v in _defs.keys():
		_load_chunk(str(id_v))


func force_unload_all() -> void:
	for id_v in _defs.keys():
		_unload_chunk(str(id_v))


func _process(_delta: float) -> void:
	if not auto_stream or _manual_lock or _player == null:
		return
	for id_v in _defs.keys():
		var id := str(id_v)
		var origin: Vector3 = _defs[id]["origin"]
		var dist := Vector2(_player.global_position.x - origin.x, _player.global_position.z - origin.z).length()
		if is_loaded(id):
			if dist > unload_radius_m:
				_unload_chunk(id)
		else:
			if dist <= load_radius_m:
				_load_chunk(id)


func _load_chunk(chunk_id: String) -> bool:
	if not _defs.has(chunk_id):
		_errors[chunk_id] = "unknown_chunk"
		chunk_failed.emit(chunk_id, "unknown_chunk")
		return false
	if is_loaded(chunk_id):
		return true
	if bool(_busy.get(chunk_id, false)):
		return false
	_busy[chunk_id] = true
	var t0 := Time.get_ticks_msec()
	var host := Node3D.new()
	host.name = "Chunk_%s" % chunk_id
	add_child(host)
	var built: Dictionary = _build_from_manifest(chunk_id, host)
	if not bool(built.get("ok", false)):
		var reason := str(built.get("reason", "build_failed"))
		host.queue_free()
		_errors[chunk_id] = reason
		_busy.erase(chunk_id)
		chunk_failed.emit(chunk_id, reason)
		print("CHUNK_FAIL id=", chunk_id, " reason=", reason)
		return false
	host.set_meta("chunk_id", chunk_id)
	host.set_meta("osm_ids", built.get("ids", []))
	host.set_meta("origin", _defs[chunk_id]["origin"])
	_loaded[chunk_id] = host
	_meta[chunk_id] = built.get("meta", [])
	_errors.erase(chunk_id)
	var dt := Time.get_ticks_msec() - t0
	_timings[chunk_id] = {"load_ms": dt, "buildings": int(built.get("buildings", 0)), "surfaces": int(built.get("surfaces", 0))}
	_busy.erase(chunk_id)
	print(
		"CHUNK_LOAD id=", chunk_id,
		" buildings=", built.get("buildings", 0),
		" surfaces=", built.get("surfaces", 0),
		" ms=", dt
	)
	chunk_loaded.emit(chunk_id)
	return true


func _unload_chunk(chunk_id: String) -> void:
	if not is_loaded(chunk_id):
		_busy.erase(chunk_id)
		return
	var t0 := Time.get_ticks_msec()
	var root: Node3D = _loaded[chunk_id]
	_loaded.erase(chunk_id)
	_meta.erase(chunk_id)
	# Free visuals + StaticBody collision together — no orphan hit_* bodies.
	if is_instance_valid(root):
		root.queue_free()
	var dt := Time.get_ticks_msec() - t0
	var prev: Dictionary = _timings.get(chunk_id, {})
	prev["unload_ms"] = dt
	_timings[chunk_id] = prev
	_busy.erase(chunk_id)
	print("CHUNK_UNLOAD id=", chunk_id, " ms=", dt)
	chunk_unloaded.emit(chunk_id)


func _build_from_manifest(chunk_id: String, host: Node3D) -> Dictionary:
	var def: Dictionary = _defs[chunk_id]
	var path := str(def["manifest"])
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"ok": false, "reason": "missing_manifest"}
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(man) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "bad_manifest_json"}
	var allow := _accepted_ids(str(def.get("clearance", "")))
	var buildings: Array = (man as Dictionary).get("buildings", [])
	var specs: Array = []
	var party: Array = []
	var meta: Array = []
	for b_v in buildings:
		var b: Dictionary = b_v
		var id := str(b["osm_id"])
		if not allow.is_empty() and not allow.has(id):
			continue
		var poly := PackedVector2Array()
		for p_v in b.get("polygon", []):
			var p: Dictionary = p_v
			poly.append(Vector2(float(p["x"]), float(p["z"])))
		if poly.size() < 3:
			continue
		_wind(poly)
		if allow.is_empty():
			# Live clearance gate when no clearance allow-list is supplied.
			var front := _front_edge(poly)
			var aabb := _poly_aabb(poly, 3.2)
			var clear := AssetPlacementValidator.asphalt_clearance(aabb, _road_segments)
			if float(front["clear"]) < 0.5 or clear < 0.5:
				continue
			var overlap := false
			for prev in party:
				if _polys_overlap(poly, prev["poly"], 0.2):
					overlap = true
					break
			if overlap:
				continue
		var style_key := str(b.get("style", DhuleBuildingStyles.STYLE_A))
		var floors := int(b.get("floors", 1))
		var shell := DhuleBuildingStyles.shell_style(style_key)
		var front2 := _front_edge(poly)
		party.append({"id": id, "poly": poly})
		specs.append({
			"id": id,
			"poly": poly,
			"floors": floors,
			"style": shell,
			"front": front2["index"],
			"front_clear": front2["clear"],
		})
		var cx := float(b.get("cx", 0.0))
		var cz := float(b.get("cz", 0.0))
		if cx == 0.0 and cz == 0.0:
			for p2 in poly:
				cx += p2.x
				cz += p2.y
			cx /= float(poly.size())
			cz /= float(poly.size())
		meta.append({
			"osm_id": id,
			"cx": cx,
			"cz": cz,
			"style": style_key,
			"floors": floors,
			"chunk_id": chunk_id,
		})
	if specs.is_empty():
		return {"ok": false, "reason": "no_buildings"}
	# Safe fallback: BuildingShell failure → empty host, report fail.
	var result: Dictionary = BuildingShell.add_neighbourhood(host, specs, party)
	var chunk_root := host.get_node_or_null("Chunk_spawn") as Node3D
	if chunk_root == null:
		return {"ok": false, "reason": "shell_missing"}
	chunk_root.set_meta("chunk_id", chunk_id)
	chunk_root.set_meta("chunk_key", chunk_id)
	return {
		"ok": true,
		"buildings": int(result.get("buildings", specs.size())),
		"surfaces": int(result.get("surfaces", 0)),
		"ids": result.get("ids", []),
		"meta": meta,
	}


func _accepted_ids(clearance_path: String) -> Dictionary:
	var out: Dictionary = {}
	if clearance_path.is_empty() or not FileAccess.file_exists(clearance_path):
		return out
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(clearance_path))
	if typeof(data) != TYPE_DICTIONARY:
		return out
	for row_v in (data as Dictionary).get("rows", []):
		var row: Dictionary = row_v
		if bool(row.get("ok", false)):
			out[str(row["osm_id"])] = true
	return out


func _count_static(n: Node) -> int:
	var c := 1 if n is StaticBody3D else 0
	for ch in n.get_children():
		c += _count_static(ch)
	return c


func _front_edge(poly: PackedVector2Array) -> Dictionary:
	var best_i := 0
	var best_d := 1.0e9
	var best_clear := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if a.distance_to(b) < 1.6:
			continue
		var mid := (a + b) * 0.5
		var hit := _nearest_road(mid)
		if float(hit["dist"]) < best_d:
			best_d = float(hit["dist"])
			best_clear = float(hit["dist"]) - float(hit["half"])
			best_i = i
	return {"index": best_i, "clear": best_clear}


func _nearest_road(p: Vector2) -> Dictionary:
	var best := 1.0e9
	var half := 3.5
	for seg_v in _road_segments:
		var seg: Dictionary = seg_v
		var a: Vector2 = seg["a"]
		var b: Vector2 = seg["b"]
		var ab := b - a
		var den := ab.length_squared()
		var t := 0.0 if den == 0.0 else clampf((p - a).dot(ab) / den, 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			half = float(seg["half"])
	return {"dist": best, "half": half}


func _polys_overlap(a: PackedVector2Array, b: PackedVector2Array, margin: float) -> bool:
	var aa := _poly_aabb(a, 1.0).grow(margin)
	var bb := _poly_aabb(b, 1.0)
	return aa.intersects(bb)


func _poly_aabb(poly: PackedVector2Array, height: float) -> AABB:
	var mn := Vector2(1.0e9, 1.0e9)
	var mx := Vector2(-1.0e9, -1.0e9)
	for p in poly:
		mn.x = minf(mn.x, p.x)
		mn.y = minf(mn.y, p.y)
		mx.x = maxf(mx.x, p.x)
		mx.y = maxf(mx.y, p.y)
	return AABB(Vector3(mn.x, 0.0, mn.y), Vector3(mx.x - mn.x, height, mx.y - mn.y))


func _wind(poly: PackedVector2Array) -> void:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	if a < 0.0:
		poly.reverse()
