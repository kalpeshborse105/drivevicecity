extends SceneTree
## Phase 2H.4C — capture second neighbourhood pilot QA.


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var packed: PackedScene = load("res://scenes/dev/dhule_building_chunk_2_test.tscn")
	var node := packed.instantiate()
	root.add_child(node)
	await process_frame
	if node.has_method("run_capture"):
		await node.run_capture()
	quit()
