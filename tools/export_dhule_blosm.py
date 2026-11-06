"""Run inside Blender 4.5. Imports the Dhule OSM clip with blosm and writes a glb.

Blosm stays out of the game repo. This script only calls the installed addon.
It never selects Google 3D Tiles or a satellite overlay.
"""
import os
import bpy

OSM = r"D:\drivevicecity\assets\maps\dhule_city.osm"
ADDON_ZIP = r"C:\Users\Admin\Downloads\blosm_2.7.28.zip"
DATA_DIR = r"D:\tools\blosm_data"
OUT = r"D:\drivevicecity\assets\models\environments\dhule_blosm_city.glb"
OUT_COPY = r"D:\drivevicecity\assets\maps\dhule_blosm.glb"
ORIGIN_LAT = 20.902
ORIGIN_LON = 74.777


def enable_blosm() -> None:
    try:
        bpy.ops.preferences.addon_enable(module="blosm")
        print("BLOSM already enabled")
        return
    except Exception as exc:
        print("BLOSM enable first try:", exc)
    bpy.ops.preferences.addon_install(filepath=ADDON_ZIP, overwrite=True)
    bpy.ops.preferences.addon_enable(module="blosm")
    print("BLOSM installed from zip")


def main() -> None:
    os.makedirs(DATA_DIR, exist_ok=True)
    enable_blosm()
    prefs = bpy.context.preferences.addons["blosm"].preferences
    prefs.dataDir = DATA_DIR
    scene = bpy.context.scene
    scene["lat"] = ORIGIN_LAT
    scene["lon"] = ORIGIN_LON
    addon = scene.blosm
    addon.dataType = "osm"
    addon.osmSource = "file"
    addon.osmFilepath = OSM
    addon.mode = "3Dsimple"
    addon.importForExport = True
    addon.buildings = True
    addon.highways = False
    addon.water = True
    if hasattr(addon, "relativeToInitialImport"):
        addon.relativeToInitialImport = True
    addon.forests = False
    addon.vegetation = False
    addon.railways = False
    if len(addon.defaultLevels) == 0:
        for levels, weight in ((1, 15), (2, 15), (3, 1)):
            entry = addon.defaultLevels.add()
            entry.levels = levels
            entry.weight = weight
    result = bpy.ops.blosm.import_data()
    print("BLOSM import", result)
    if "FINISHED" not in result:
        raise SystemExit(1)
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH" and obj.name == "Cube":
            bpy.data.objects.remove(obj, do_unlink=True)
    for obj in list(bpy.context.scene.objects):
        if obj.type != "CURVE":
            continue
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.convert(target="MESH")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB")
    print("BLOSM wrote", OUT)
    if OUT_COPY and OUT_COPY != OUT:
        import shutil
        shutil.copyfile(OUT, OUT_COPY)
        print("BLOSM copied", OUT_COPY)


if __name__ == "__main__":
    main()
