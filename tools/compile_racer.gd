extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: PackedScene = load("res://osm_racer/scenes/main.tscn")
	var title: PackedScene = load("res://osm_racer/scenes/title_screen.tscn")
	var traffic: PackedScene = load("res://osm_racer/scenes/traffic_car.tscn")
	print("COMPILE main=%s title=%s traffic=%s" % [main != null, title != null, traffic != null])
	quit(0 if main != null and title != null else 1)
