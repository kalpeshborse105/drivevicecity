extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/google_drive.tscn")
	if packed == null:
		printerr("GOOGLE_MAP_SMOKE missing scene")
		quit(1)
		return
	var world := packed.instantiate()
	root.add_child(world)
	var label: Label = world.get_node("HUD/Status")
	var last := ""
	for _i in 90:
		await create_timer(1.0).timeout
		var text := label.text
		if text != last:
			print("GOOGLE_MAP_SMOKE ", text)
			last = text
		if text.contains("Shivtirth") or text.contains("refused") or text.contains("No map") or text.contains("Put your"):
			quit(0 if text.contains("Shivtirth") else 1)
			return
	printerr("GOOGLE_MAP_SMOKE timeout last=%s" % last)
	quit(1)
