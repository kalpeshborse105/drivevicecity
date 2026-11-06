"""Original chowk monument for DriveViceCity. Not a copy of any photograph."""
import bpy
import os

OUT = r"D:\drivevicecity\assets\models\props\dhule_chowk_statue.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)

def box(name, size, loc, color, rough=0.45):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    mat = bpy.data.materials.new(name + "_mat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rough
    obj.data.materials.append(mat)
    return obj

# Stone plinth
box("plinth", (3.2, 3.2, 1.1), (0, 0, 0.55), (0.45, 0.32, 0.22, 1), 0.8)
box("step", (4.2, 4.2, 0.28), (0, 0, 0.14), (0.55, 0.42, 0.30, 1), 0.85)
# Standing figure, original block sculpture
box("legs", (0.7, 0.45, 2.2), (0, 0, 2.3), (0.72, 0.55, 0.18, 1), 0.35)
box("torso", (0.95, 0.5, 1.6), (0, 0, 4.1), (0.78, 0.58, 0.16, 1), 0.3)
box("head", (0.42, 0.38, 0.48), (0, 0, 5.15), (0.82, 0.64, 0.2, 1), 0.28)
# Raised arm
box("arm", (0.22, 0.22, 1.3), (0.55, 0, 4.7), (0.78, 0.58, 0.16, 1), 0.3)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB")
print("STATUE", OUT)
