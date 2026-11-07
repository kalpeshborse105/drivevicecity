extends Node3D
## Terrain3D ring outside the OSM ground slab.
## The city ground stays the drive surface. This mesh is visual only.

const SPACING := 24.0
const RESOLUTION := 256
const CITY_HALF := 2200.0
const HEIGHT_OFFSET := -8.0
const HEIGHT_SCALE := 28.0

func _ready() -> void:
	call_deferred("_build")


func _build() -> void:
	var terrain := Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.collision_mode = 0
	terrain.vertex_spacing = SPACING
	terrain.mesh_size = 48
	terrain.mesh_lods = 6
	terrain.cast_shadows = RenderingServer.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)
	if terrain.material == null:
		terrain.set_material(Terrain3DMaterial.new())
	var cam := get_viewport().get_camera_3d()
	if cam:
		terrain.set_camera(cam)
	var data: Terrain3DData = terrain.data
	if data == null:
		push_error("Terrain3D data was not created. Horizon hills were skipped.")
		return
	var height := Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RF)
	var color := Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8)
	var origin := -0.5 * float(RESOLUTION - 1) * SPACING
	for y in RESOLUTION:
		for x in RESOLUTION:
			var wx := origin + float(x) * SPACING
			var wz := origin + float(y) * SPACING
			var dist := maxf(absf(wx), absf(wz))
			var h := HEIGHT_OFFSET
			if dist > CITY_HALF - 80.0:
				var t := clampf((dist - (CITY_HALF - 80.0)) / 520.0, 0.0, 1.0)
				var roll := sin(wx * 0.0032) * cos(wz * 0.0028)
				h = lerpf(0.0, 55.0 + roll * 18.0, t * t)
			var pixel := clampf((h - HEIGHT_OFFSET) / HEIGHT_SCALE, 0.0, 1.0)
			height.set_pixel(x, y, Color(pixel, 0, 0))
			var scrub := Color(0.45, 0.42, 0.28).lerp(Color(0.34, 0.42, 0.24), t_scrub(dist))
			color.set_pixel(x, y, scrub)
	data.import_images([height, null, color], Vector3(origin, 0, origin), HEIGHT_OFFSET, HEIGHT_SCALE)
	_apply_ground_texture(terrain)


func t_scrub(dist: float) -> float:
	return clampf((dist - CITY_HALF) / 600.0, 0.0, 1.0)


func _apply_ground_texture(terrain: Terrain3D) -> void:
	if not ResourceLoader.exists("res://demo/assets/textures/ground037_alb_ht.png"):
		return
	var albedo := load("res://demo/assets/textures/ground037_alb_ht.png") as Texture2D
	if albedo == null:
		return
	var assets := Terrain3DAssets.new()
	var tex := Terrain3DTextureAsset.new()
	tex.set_albedo_texture(albedo)
	assets.set_texture(0, tex)
	terrain.assets = assets
