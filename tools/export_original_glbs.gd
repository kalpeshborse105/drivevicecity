extends SceneTree
## Headless export: original premium sedan + Dhule junction streetscape GLBs.
## Usage: godot_console --path . --headless -s res://tools/export_original_glbs.gd

const VehicleMeshBuilder = preload("res://scripts/vehicle_mesh_builder.gd")
const StreetscapeKit = preload("res://scripts/streetscape_kit.gd")

const SEDAN_OUT := "res://assets/models/vehicles/premium_sedan_mh.glb"
const STREET_OUT := "res://assets/models/environments/dhule_junction_streetscape.glb"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/models/vehicles")
	DirAccess.make_dir_recursive_absolute("res://assets/models/environments")
	var ok_sedan := _export_sedan()
	var ok_street := _export_streetscape()
	print("EXPORT_SEDAN=", "OK" if ok_sedan else "FAIL", " path=", SEDAN_OUT)
	print("EXPORT_STREET=", "OK" if ok_street else "FAIL", " path=", STREET_OUT)
	quit(0 if ok_sedan and ok_street else 1)


func _export_sedan() -> bool:
	var root := Node3D.new()
	root.name = "PremiumSedanMH"
	root.set_meta("author", "DriveViceCity original")
	root.set_meta("forward", "MODEL_FRONT_+Z")
	VehicleMeshBuilder.build_premium_sedan(root)
	# Ensure scene is in tree so materials/meshes resolve for GLTF
	var holder := Node3D.new()
	holder.name = "ExportRoot"
	holder.add_child(root)
	root.owner = holder
	_set_owners(root, holder)
	get_root().add_child(holder)
	var ok := _write_gltf(holder, SEDAN_OUT)
	holder.queue_free()
	return ok


func _export_streetscape() -> bool:
	var root := Node3D.new()
	root.name = "DhuleJunctionStreetscape"
	root.set_meta("author", "DriveViceCity original")
	root.set_meta("note", "Inspired by urban Dhule junction — original, not a scan")
	StreetscapeKit.build_dhule_junction(root)
	var holder := Node3D.new()
	holder.name = "ExportRoot"
	holder.add_child(root)
	root.owner = holder
	_set_owners(root, holder)
	get_root().add_child(holder)
	var ok := _write_gltf(holder, STREET_OUT)
	holder.queue_free()
	return ok


func _set_owners(n: Node, owner: Node) -> void:
	for c in n.get_children():
		c.owner = owner
		_set_owners(c, owner)


func _write_gltf(scene_root: Node, path: String) -> bool:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(scene_root, state, 0)
	if err != OK:
		push_error("append_from_scene failed: %s" % err)
		return false
	err = doc.write_to_filesystem(state, path)
	if err != OK:
		push_error("write_to_filesystem failed: %s path=%s" % [err, path])
		return false
	return FileAccess.file_exists(path)
