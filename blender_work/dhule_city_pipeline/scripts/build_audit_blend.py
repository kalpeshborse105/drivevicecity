"""Build the isolated audit blend and render diagnostic views.

Coordinates are the game projection: X east, Y up, Z south.
Does not modify production files.
"""
import json
import struct
import csv
from pathlib import Path

import bpy
import mathutils

ROOT = Path(r"D:\drivevicecity")
AUDIT = ROOT / "blender_work" / "dhule_city_pipeline" / "audit"
QA = ROOT / "docs" / "qa"
BIN = AUDIT / "preview.bin"
BLEND = AUDIT / "unresolved_geometry_audit.blend"


def read_verts(handle):
    count = struct.unpack("<I", handle.read(4))[0]
    raw = struct.unpack("<%df" % (count * 3), handle.read(count * 12))
    return raw


def read_outlines(handle):
    count = struct.unpack("<I", handle.read(4))[0]
    outlines = []
    for _ in range(count):
        length = struct.unpack("<H", handle.read(2))[0]
        osm_id = handle.read(length).decode("utf-8")
        points = struct.unpack("<I", handle.read(4))[0]
        flat = struct.unpack("<%df" % (points * 2), handle.read(points * 8))
        poly = [(flat[i], flat[i + 1]) for i in range(0, len(flat), 2)]
        outlines.append((osm_id, poly))
    return outlines


def mesh_from_tris(name, flat):
    verts = [flat[i:i + 3] for i in range(0, len(flat), 3)]
    faces = [(i, i + 1, i + 2) for i in range(0, len(verts), 3)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    return obj


def outline_mesh(name, outlines, height):
    verts = []
    faces = []
    for _osm_id, poly in outlines:
        if len(poly) < 2:
            continue
        base = len(verts)
        ring = poly + [poly[0]]
        for x, z in ring:
            verts.append((x, height, z))
            verts.append((x, 0.15, z))
        for i in range(len(poly)):
            a = base + i * 2
            b = base + i * 2 + 1
            c = base + (i + 1) * 2
            d = base + (i + 1) * 2 + 1
            faces.append((a, c, b))
            faces.append((b, c, d))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    return bpy.data.objects.new(name, mesh)


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (color[0], color[1], color[2], 1.0)
    return mat


def link(obj, col, mat):
    col.objects.link(obj)
    obj.data.materials.append(mat)


def aim(camera, location, target):
    camera.location = location
    direction = mathutils.Vector(target) - mathutils.Vector(location)
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render_to(scene, path):
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    print("AUDIT_SHOT", path)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.image_settings.file_format = "PNG"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.view_settings.view_transform = "Standard"
    scene.unit_settings.system = "METRIC"
    scene["projection_lat"] = 20.902
    scene["projection_lon"] = 74.777
    scene["axis_x"] = "east"
    scene["axis_y"] = "up"
    scene["axis_z"] = "south"

    with BIN.open("rb") as handle:
        assigned = read_verts(handle)
        unresolved = read_verts(handle)
        water = read_verts(handle)
        missing = read_outlines(handle)
        ambiguous = read_outlines(handle)

    assigned_col = bpy.data.collections.new("Assigned")
    unresolved_col = bpy.data.collections.new("Unresolved")
    missing_col = bpy.data.collections.new("MissingOutlines")
    ambiguous_col = bpy.data.collections.new("AmbiguousOutlines")
    water_col = bpy.data.collections.new("Water")
    for col in (assigned_col, unresolved_col, missing_col, ambiguous_col, water_col):
        scene.collection.children.link(col)

    link(mesh_from_tris("assigned", assigned), assigned_col, material("AssignedNeutral", (0.62, 0.62, 0.58)))
    link(mesh_from_tris("unresolved", unresolved), unresolved_col, material("UnresolvedRed", (0.78, 0.08, 0.06)))
    link(outline_mesh("missing_outlines", missing, 16.0), missing_col, material("MissingBlue", (0.12, 0.38, 0.95)))
    if ambiguous:
        link(outline_mesh("ambiguous_outlines", ambiguous, 16.2), ambiguous_col, material("AmbiguousOrange", (0.95, 0.42, 0.05)))
    link(mesh_from_tris("water", water), water_col, material("WaterBlue", (0.04, 0.18, 0.55)))

    cam_data = bpy.data.cameras.new("AuditCamera")
    cam_data.clip_end = 30000.0
    cam_data.lens = 28
    camera = bpy.data.objects.new("AuditCamera", cam_data)
    scene.collection.objects.link(camera)
    scene.camera = camera

    summary = json.loads((AUDIT / "audit_summary.json").read_text(encoding="utf-8"))
    center = summary["cameras"]["overview"]["look"]
    unresolved_look = summary["cameras"]["unresolved"]["look"]
    rows = list(csv.DictReader((AUDIT / "missing_buildings.csv").open(encoding="utf-8")))
    cluster = [row for row in rows if row["osm_id"].startswith("152728") or row["osm_id"].startswith("152727")]
    if not cluster:
        cluster = rows
    mx = sum((float(row["min_x"]) + float(row["max_x"])) * 0.5 for row in cluster) / len(cluster)
    mz = sum((float(row["min_z"]) + float(row["max_z"])) * 0.5 for row in cluster) / len(cluster)

    water_col.hide_render = True
    aim(camera, (center[0] - 1800.0, 4200.0, center[2] + 2600.0), (center[0], 0.0, center[2]))
    render_to(scene, QA / "36-overview.png")

    aim(camera, (mx + 80.0, 70.0, mz + 90.0), (mx, 4.0, mz))
    render_to(scene, QA / "36-missing.png")

    ux, _uy, uz = unresolved_look
    aim(camera, (ux + 35.0, 28.0, uz + 40.0), (ux, 3.0, uz))
    render_to(scene, QA / "36-unresolved.png")

    for col in (assigned_col, unresolved_col, missing_col, ambiguous_col):
        col.hide_render = True
    water_col.hide_render = False
    aim(camera, (center[0] - 2200.0, 7000.0, center[2] + 3200.0), (center[0], 0.0, center[2]))
    render_to(scene, QA / "36-water.png")

    for col in (assigned_col, unresolved_col, missing_col, ambiguous_col, water_col):
        col.hide_render = False
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    print("AUDIT_BLEND", BLEND)


if __name__ == "__main__":
    main()
