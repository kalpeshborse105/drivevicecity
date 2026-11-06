import bpy
import addon_utils
import os

print("--- STARTING BLOSM IMPORT FOR DHULE MAP ---")

# 1. Enable blosm addon
addon_utils.enable("blosm")

# 2. Clear default objects
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# 3. Configure blosm
scene = bpy.context.scene
scene["lat"] = 20.902
scene["lon"] = 74.777

blosm = scene.blosm
blosm.relativeToInitialImport = True
blosm.dataType = "osm"
blosm.osmSource = "file"
blosm.osmFilepath = r"C:\Users\Admin\Downloads\dhulemap.osm"
blosm.buildings = True
blosm.highways = True
blosm.water = True
blosm.forests = True
blosm.vegetation = True
blosm.railways = False
blosm.defaultRoofShape = "flat"
blosm.levelHeight = 3.0

print(f"Importing OSM from: {blosm.osmFilepath}")

# 4. Run import operator
res = bpy.ops.blosm.import_data()
print(f"Blosm import result: {res}")

# 5. List created objects
objs = list(bpy.context.scene.objects)
print(f"Total objects in scene after import: {len(objs)}")
for o in objs[:20]:
    print(f"  Object: {o.name} (type: {o.type}, verts: {len(o.data.vertices) if o.type == 'MESH' else 0})")

# 6. Save .blend file for reference
blend_path = r"D:\drivevicecity\assets\models\environments\dhule_blosm_city.blend"
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
print(f"Saved Blender project to: {blend_path}")

# 7. Export GLB for Godot
glb_path = r"D:\drivevicecity\assets\models\environments\dhule_blosm_city.glb"
bpy.ops.export_scene.gltf(
    filepath=glb_path,
    export_format='GLB',
    use_selection=False,
    export_apply=True
)
print(f"Exported glTF/GLB to: {glb_path}")
print(f"GLB size: {os.path.getsize(glb_path) / 1024:.1f} KB")

print("--- BLOSM IMPORT COMPLETED SUCCESSFULLY ---")

