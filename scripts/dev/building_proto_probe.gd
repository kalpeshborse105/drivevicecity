extends SceneTree


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/dev/dhule_building_prototype.tscn")
	var node := packed.instantiate()
	root.add_child(node)
	await process_frame
	await node.run_capture()
	quit()
