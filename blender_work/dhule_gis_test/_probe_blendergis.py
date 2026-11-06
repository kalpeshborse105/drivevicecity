import addon_utils
import bpy
import sys
import traceback

print("BLENDER", bpy.app.version_string)
print("EXE", bpy.app.binary_path)

name = "BlenderGIS-2215"
try:
    addon_utils.enable(name, default_set=False, persistent=False)
except Exception:
    traceback.print_exc()

mod = sys.modules.get(name)
print("MODULE", mod)
prefs = bpy.context.preferences.addons.get(name)
print("PREFS", prefs is not None)
if mod is not None:
    info = getattr(mod, "bl_info", {})
    print("VERSION", info.get("version"))
    print("BLENDER_MIN", info.get("blender"))
    try:
        from importlib import import_module
        deps = import_module(name + ".core.checkdeps")
        print("HAS_GDAL", deps.HAS_GDAL)
        print("HAS_PYPROJ", deps.HAS_PYPROJ)
        print("HAS_PIL", deps.HAS_PIL)
    except Exception:
        traceback.print_exc()

ids = [op.bl_idname for op in bpy.types.Operator.__subclasses__() if "importgis" in op.bl_idname or "exportgis" in op.bl_idname or op.bl_idname.startswith("geoscene.") or op.bl_idname.startswith("view3d.map")]
for item in sorted(set(ids)):
    print("OP", item)
print("PROBE_DONE")
