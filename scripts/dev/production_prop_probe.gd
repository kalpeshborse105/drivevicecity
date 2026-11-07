extends SceneTree
## Confirm production no longer seeds the street pack.


const AssetKit = preload("res://scripts/asset_kit.gd")


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var node := packed.instantiate()
	root.add_child(node)
	for _i in 120:
		await process_frame
	var tally := {"street": 0, "giant": 0, "solid": 0}
	_count(node, tally)
	print("PROD_PROPS street_nodes=", tally["street"], " giants=", tally["giant"], " solids=", tally["solid"])
	quit()


func _count(n: Node, tally: Dictionary) -> void:
	var nm := str(n.name)
	if nm.begins_with("street_"):
		tally["street"] = int(tally["street"]) + 1
	if nm.begins_with("Solid_"):
		tally["solid"] = int(tally["solid"]) + 1
	if n is Node3D and nm.begins_with("street_"):
		var aabb := AssetKit.mesh_aabb(n)
		if maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)) > 20.0:
			tally["giant"] = int(tally["giant"]) + 1
			print("GIANT ", nm, " ", aabb.size)
	for c in n.get_children():
		_count(c, tally)
