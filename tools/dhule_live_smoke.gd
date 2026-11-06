extends SceneTree
## Confirms the live Dhule OSM fetch and that the racer title scene loads.
## Run: godot --headless --path D:\drivevicecity -s res://tools/dhule_live_smoke.gd

const DhuleLiveMap = preload("res://osm_racer/scripts/dhule_live_map.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var title: PackedScene = load("res://osm_racer/scenes/title_screen.tscn")
	if title == null:
		printerr("DHULE_LIVE_SMOKE_FAIL title scene")
		quit(1)
		return
	var host := Node.new()
	root.add_child(host)
	var path: String = await DhuleLiveMap.fetch(host)
	if path == "":
		printerr("DHULE_LIVE_SMOKE_FAIL fetch")
		quit(1)
		return
	var text: String = FileAccess.get_file_as_string(path)
	var ok_xml: bool = text.contains("<osm") and text.contains("20.9")
	var bytes: int = FileAccess.get_file_as_bytes(path).size()
	print("dhule_live path=%s bytes=%d xml_ok=%s bbox=%s" % [path, bytes, ok_xml, DhuleLiveMap.bbox_string()])
	# Old Dhule city builder must not be the boot scene.
	var boot: String = str(ProjectSettings.get_setting("application/run/main_scene"))
	print("main_scene=%s" % boot)
	if str(boot) != "res://osm_racer/scenes/title_screen.tscn" or not ok_xml:
		printerr("DHULE_LIVE_SMOKE_FAIL")
		quit(1)
		return
	print("DHULE_LIVE_SMOKE_RESULT=PASS")
	quit(0)
