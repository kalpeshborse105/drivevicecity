extends SceneTree
## Phase 2H.4D — two-neighbourhood chunk manager QA capture.


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var packed: PackedScene = load("res://scenes/dev/dhule_two_neighbourhoods_test.tscn")
	var node := packed.instantiate()
	root.add_child(node)
	await process_frame
	if node.has_method("run_capture"):
		await node.run_capture()
	quit()
