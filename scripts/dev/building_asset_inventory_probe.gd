extends SceneTree
## Phase 2H.4B.2 — inventory kit building GLBs + dry-fit against 48-pilot footprints.


const AssetKit = preload("res://scripts/asset_kit.gd")
const BuildingAssetFitter = preload("res://scripts/building_asset_fitter.gd")
const MANIFEST := "res://docs/qa/64-chunk-pilot-manifest.json"
const OUT := "res://docs/qa/70-building-asset-inventory.json"

const PATHS := [
	"res://assets/kit/buildings/indian_house.glb",
	"res://assets/kit/buildings/bhelpuri_shop.glb",
	"res://assets/kit/props/bullock_cart.glb",
	"res://assets/kit/props/barriers.glb",
	"res://assets/kit/props/street_asset_pack.glb",
]


func _initialize() -> void:
	var rows: Array = []
	for path in PATHS:
		rows.append(_inspect(path))
	var fit := _dry_fit_house()
	for r in rows:
		if str(r["kind"]) == "complete_building":
			r["can_fit_pilot"] = int(fit.get("fitted", 0)) > 0
			r["fitted_count_dry"] = int(fit.get("fitted", 0))
	var payload := {
		"assets": rows,
		"pilot_fit": fit,
		"note": "Pilot keeps batched procedural shell; GLB only if undistorted fit. Dry-fit ignores asphalt (empty segments).",
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	print("ASSET_INV wrote ", OUT)
	for r in rows:
		print(
			"ASSET ", r["file"],
			" dim=", r["aabb_m"],
			" meshes=", r["mesh_count"],
			" mats=", r["material_count"],
			" kind=", r["kind"],
			" fit_any=", r.get("can_fit_pilot", false)
		)
	print(
		"FIT_SUMMARY candidates=", fit["candidates"],
		" fitted=", fit["fitted"],
		" procedural=", fit["procedural"],
		" rejected=", fit["rejected"]
	)
	print("ASSET_INV_DONE")
	quit()


func _inspect(path: String) -> Dictionary:
	var row := {
		"file": path.get_file(),
		"path": path,
		"exists": AssetKit.exists(path),
		"aabb_m": [0, 0, 0],
		"mesh_count": 0,
		"material_count": 0,
		"has_collision_in_scene": false,
		"kind": "missing",
		"can_fit_pilot": false,
		"notes": "",
	}
	if not AssetKit.exists(path):
		return row
	var n := AssetKit.normalized(path)
	if n == null:
		row["notes"] = "instantiate_failed"
		return row
	var aabb := AssetKit.mesh_aabb(n)
	row["aabb_m"] = [snapped(aabb.size.x, 0.01), snapped(aabb.size.y, 0.01), snapped(aabb.size.z, 0.01)]
	var acc := {"meshes": 0, "col": false}
	var mats: Dictionary = {}
	_count(n, acc, mats)
	row["mesh_count"] = int(acc["meshes"])
	row["material_count"] = mats.size()
	row["has_collision_in_scene"] = bool(acc["col"])
	var nm := path.get_file().to_lower()
	if "house" in nm:
		row["kind"] = "complete_building"
		row["notes"] = "Only complete residential kit shell; uniform fit only."
	elif "bhelpuri" in nm or "cart" in nm:
		row["kind"] = "prop_cart"
		row["notes"] = "Not a building — never stretch into footprint."
	elif "barrier" in nm:
		row["kind"] = "prop_barrier"
		row["notes"] = "Road prop — not a building."
	elif "street_asset" in nm:
		row["kind"] = "prop_pack"
		row["notes"] = "Street props pack — not a building."
	else:
		row["kind"] = "other"
	n.queue_free()
	return row


func _count(n: Node, acc: Dictionary, mats: Dictionary) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		acc["meshes"] = int(acc["meshes"]) + 1
		var mi := n as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(si)
			if m:
				mats[m.get_instance_id()] = true
			if mi.get_active_material(si):
				mats[mi.get_active_material(si).get_instance_id()] = true
	if n is CollisionObject3D:
		acc["col"] = true
	for c in n.get_children():
		_count(c, acc, mats)


func _dry_fit_house() -> Dictionary:
	## Geometry-only uniform fit (no scene collision). Pilot still uses procedural batching.
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var buildings: Array = man.get("buildings", [])
	var house := "res://assets/kit/buildings/indian_house.glb"
	var fitted := 0
	var procedural := 0
	var rejected := 0
	var fitted_ids: Array = []
	var probe: Node3D = null
	var raw_aabb := AABB()
	if AssetKit.exists(house):
		probe = AssetKit.normalized(house)
		if probe:
			raw_aabb = AssetKit.mesh_aabb(probe)
	for b_v in buildings:
		var b: Dictionary = b_v
		var poly := PackedVector2Array()
		for p_v in b["polygon"]:
			var p: Dictionary = p_v
			poly.append(Vector2(float(p["x"]), float(p["z"])))
		if poly.size() < 3:
			rejected += 1
			continue
		var area := float(b.get("area_m2", 80.0))
		if probe == null or area < 55.0 or area > 120.0:
			procedural += 1
			continue
		var fit: Dictionary = BuildingAssetFitter._fit_uniform(poly, 0, raw_aabb, 0.0)
		if bool(fit.get("ok", false)):
			fitted += 1
			fitted_ids.append(str(b["osm_id"]))
		else:
			procedural += 1
	if probe:
		probe.queue_free()
	return {
		"candidates": buildings.size(),
		"fitted": fitted,
		"procedural": procedural,
		"rejected": rejected,
		"fitted_ids": fitted_ids,
		"decision": "pilot_keeps_procedural_batching",
	}
