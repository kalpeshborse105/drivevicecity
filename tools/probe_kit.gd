extends SceneTree

const AssetKit = preload("res://scripts/asset_kit.gd")


func _init() -> void:
	var paths := [
		AssetKit.road_path("avenue"),
		AssetKit.road_path("avenue_hq"),
		AssetKit.road_path("india_street"),
		AssetKit.sidewalk_path("sidewalk_8m"),
		AssetKit.sidewalk_path("tiles"),
		AssetKit.building_path("bhelpuri"),
		AssetKit.prop_path("barrier"),
		AssetKit.prop_path("street_light"),
		AssetKit.prop_path("bullock"),
		AssetKit.vehicle_path("carnival"),
		AssetKit.vehicle_path("safari"),
		AssetKit.vehicle_path("autorickshaw"),
		AssetKit.vehicle_path("bus"),
		AssetKit.vehicle_path("truck"),
	]
	for p in paths:
		var n := AssetKit.instance(p)
		if n == null:
			print("MISSING ", p)
			continue
		var a := AssetKit.mesh_aabb(n)
		print("%s  size=(%.2f, %.2f, %.2f) min_y=%.2f" % [p.get_file(), a.size.x, a.size.y, a.size.z, a.position.y])
		if a.size.y > 3.0 * maxf(a.size.x, a.size.z):
			_dump_meshes(n, "")
		n.free()
		var w := AssetKit.normalized(p)
		if w:
			var b := AssetKit.mesh_aabb(w)
			print("   normalized size=(%.2f, %.2f, %.2f) min_y=%.2f" % [b.size.x, b.size.y, b.size.z, b.position.y])
			w.free()
	quit()


func _dump_meshes(n: Node, indent: String) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var a: AABB = (n as MeshInstance3D).mesh.get_aabb()
		print("%s  mesh %s aabb size=(%.1f, %.1f, %.1f)" % [indent, n.name, a.size.x, a.size.y, a.size.z])
	for c in n.get_children():
		_dump_meshes(c, indent + "  ")
