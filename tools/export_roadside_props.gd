extends SceneTree
## godot_console --path . --headless -s res://tools/export_roadside_props.gd

const Props = preload("res://scripts/roadside_props_kit.gd")

const OUT := {
	"street_light": ["res://assets/models/props/street_light_mh.glb", Callable(Props, "build_street_light")],
	"traffic_barrier": ["res://assets/models/props/traffic_barrier_mh.glb", Callable(Props, "build_traffic_barrier")],
	"bus_stop_shelter": ["res://assets/models/props/bus_stop_shelter_mh.glb", Callable(Props, "build_bus_stop_shelter")],
	"concrete_planter": ["res://assets/models/props/concrete_planter_mh.glb", Callable(Props, "build_concrete_planter")],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/models/props")
	var all_ok := true
	for key in OUT.keys():
		var path: String = OUT[key][0]
		var builder: Callable = OUT[key][1]
		var ok := _export_one(key, path, builder)
		print("EXPORT_PROP_", key, "=", "OK" if ok else "FAIL", " ", path)
		all_ok = all_ok and ok
	quit(0 if all_ok else 1)


func _export_one(name: String, path: String, builder: Callable) -> bool:
	var root := Node3D.new()
	root.name = name
	builder.call(root)
	var holder := Node3D.new()
	holder.name = "ExportRoot"
	holder.add_child(root)
	root.owner = holder
	_owners(root, holder)
	get_root().add_child(holder)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_scene(holder, state, 0) != OK:
		holder.queue_free()
		return false
	var err := doc.write_to_filesystem(state, path)
	holder.queue_free()
	return err == OK and FileAccess.file_exists(path)


func _owners(n: Node, owner: Node) -> void:
	for c in n.get_children():
		c.owner = owner
		_owners(c, owner)
