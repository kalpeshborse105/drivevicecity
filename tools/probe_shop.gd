extends SceneTree
## Probe shop + safari AABB / materials for Phase 1 placement.

const AssetKit = preload("res://scripts/asset_kit.gd")


func _init() -> void:
	_probe("res://assets/kit/buildings/bhelpuri_shop.glb")
	_probe("res://assets/models/buildings/shops/bhelpuri_shop.glb")
	_probe("res://assets/kit/vehicles/tata_safari.glb")
	quit()


func _probe(path: String) -> void:
	print("--- ", path)
	if not ResourceLoader.exists(path):
		print("MISSING")
		return
	var raw := AssetKit.instance(path)
	if raw == null:
		print("instantiate_fail")
		return
	var a := AssetKit.mesh_aabb(raw)
	print("raw size=(%.2f, %.2f, %.2f) tris~%d mats=%d" % [
		a.size.x, a.size.y, a.size.z, _tri_count(raw), _mat_count(raw)
	])
	_list_mats(raw, "  ")
	raw.free()
	var n := AssetKit.normalized(path) if AssetKit.NORMALIZE.has(path) else null
	if n:
		var b := AssetKit.mesh_aabb(n)
		print("normalized size=(%.2f, %.2f, %.2f) min_y=%.2f" % [b.size.x, b.size.y, b.size.z, b.position.y])
		n.free()


func _tri_count(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var m: Mesh = (n as MeshInstance3D).mesh
		for si in m.get_surface_count():
			var arr := m.surface_get_arrays(si)
			if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null:
				t += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	for c in n.get_children():
		t += _tri_count(c)
	return t


func _mat_count(n: Node) -> int:
	var c := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		c += (n as MeshInstance3D).mesh.get_surface_count()
	for ch in n.get_children():
		c += _mat_count(ch)
	return c


func _list_mats(n: Node, indent: String) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for si in mi.mesh.get_surface_count():
				var mat: Material = mi.get_active_material(si)
				var name := "null"
				if mat is StandardMaterial3D:
					var sm := mat as StandardMaterial3D
					name = "Std albedo=%s rough=%.2f tex=%s" % [
						str(sm.albedo_color), sm.roughness,
						"yes" if sm.albedo_texture != null else "no"
					]
				elif mat:
					name = mat.get_class()
				print("%s%s surf%d: %s" % [indent, mi.name, si, name])
	for ch in n.get_children():
		_list_mats(ch, indent)
