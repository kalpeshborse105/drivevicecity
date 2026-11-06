"""Replace three Blosm shells in a test copy. Does not write the production GLB.

The production file is one mesh, dhule_city.osm_buildings, with no OSM ids.
Triangles are kept or removed by testing their centroid against the OSM
polygon in the game projection (X east, Z south). A face is removed only when
that test names one of the three replacement ids.
"""
import csv
import json
import math
import xml.etree.ElementTree as ET
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(r"D:\drivevicecity")
OSM = ROOT / "assets" / "maps" / "dhule_city.osm"
ROADS = ROOT / "assets" / "maps" / "dhule_roads_game.json"
BLOSM = ROOT / "assets" / "models" / "environments" / "dhule_blosm_city.glb"
ARCH = ROOT / "blender_work" / "dhule_architecture" / "export" / "dhule_architecture_test.glb"
OUT = ROOT / "blender_work" / "dhule_building_replacement"
EXPORT = OUT / "export" / "dhule_building_replacement.glb"

LAT0 = 20.902
LON0 = 74.777
M_LAT = 111320.0
M_LON = M_LAT * math.cos(math.radians(LAT0))
REPLACE = {
    "1337951722": {"role": "single_storey_residential", "kind": "house1"},
    "1337953905": {"role": "two_storey_residential", "kind": "house2"},
    "482794524": {"role": "sessions_court_wing", "kind": "civic"},
}
EDGE_BAND = 0.45


def xz(lat, lon):
    return ((lon - LON0) * M_LON, -(lat - LAT0) * M_LAT)


def signed_area(poly):
    a = 0.0
    for i, p in enumerate(poly):
        q = poly[(i + 1) % len(poly)]
        a += p[0] * q[1] - q[0] * p[1]
    return a * 0.5


def point_in(x, z, poly):
    inside = False
    j = len(poly) - 1
    for i, (xi, zi) in enumerate(poly):
        xj, zj = poly[j]
        if ((zi > z) != (zj > z)) and (x < (xj - xi) * (z - zi) / ((zj - zi) or 1e-12) + xi):
            inside = not inside
        j = i
    return inside


def edge_distance(x, z, poly):
    best = 1e9
    for i, a in enumerate(poly):
        b = poly[(i + 1) % len(poly)]
        dx, dz = b[0] - a[0], b[1] - a[1]
        l2 = dx * dx + dz * dz
        t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((x - a[0]) * dx + (z - a[1]) * dz) / l2))
        qx, qz = a[0] + dx * t, a[1] + dz * t
        best = min(best, math.hypot(x - qx, z - qz))
    return best


def load_osm():
    nodes = {}
    buildings = []
    for _ev, elem in ET.iterparse(OSM, events=("end",)):
        if elem.tag == "node":
            nodes[elem.attrib["id"]] = (float(elem.attrib["lat"]), float(elem.attrib["lon"]))
            elem.clear()
        elif elem.tag == "way":
            tags = {t.attrib["k"]: t.attrib["v"] for t in elem.findall("tag")}
            if "building" in tags:
                poly = []
                for nd in elem.findall("nd"):
                    latlon = nodes.get(nd.attrib["ref"])
                    if latlon:
                        poly.append(xz(*latlon))
                if len(poly) >= 4 and poly[0] == poly[-1]:
                    poly = poly[:-1]
                if len(poly) >= 3:
                    xs = [p[0] for p in poly]
                    zs = [p[1] for p in poly]
                    buildings.append({
                        "id": elem.attrib["id"],
                        "poly": poly,
                        "tags": tags,
                        "area": abs(signed_area(poly)),
                        "minx": min(xs), "maxx": max(xs),
                        "minz": min(zs), "maxz": max(zs),
                        "tris": 0,
                        "wall": 0,
                        "roof": 0,
                        "miny": 1e9,
                        "maxy": -1e9,
                    })
            elem.clear()
    return buildings


def load_roads():
    data = json.loads(ROADS.read_text(encoding="utf-8"))
    roads = []
    for road in data["roads"]:
        pts = []
        for pt in road.get("points") or []:
            if isinstance(pt, dict):
                pts.append((float(pt["x"]), float(pt["z"])))
            else:
                pts.append((float(pt[0]), float(pt[1])))
        if len(pts) >= 2:
            roads.append({"id": str(road.get("id", "")), "width": float(road.get("width") or 7.0), "xz": pts})
    return roads


def clearance(poly, roads):
    best = 1e9
    nearest = ""
    for i, a in enumerate(poly):
        b = poly[(i + 1) % len(poly)]
        for k in range(4):
            t = k / 3.0
            p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            for road in roads:
                half = road["width"] * 0.5
                pts = road["xz"]
                for s in range(len(pts) - 1):
                    d = edge_distance(p[0], p[1], [pts[s], pts[s + 1]]) - half
                    if d < best:
                        best = d
                        nearest = road["id"]
    return best, nearest


class Grid:
    def __init__(self, buildings, cell=48.0):
        self.cell = cell
        self.bins = {}
        for index, b in enumerate(buildings):
            x0 = int((b["minx"] - EDGE_BAND) // cell)
            x1 = int((b["maxx"] + EDGE_BAND) // cell)
            z0 = int((b["minz"] - EDGE_BAND) // cell)
            z1 = int((b["maxz"] + EDGE_BAND) // cell)
            for ix in range(x0, x1 + 1):
                for iz in range(z0, z1 + 1):
                    self.bins.setdefault((ix, iz), []).append(index)
        self.buildings = buildings

    def candidates(self, x, z):
        return self.bins.get((int(x // self.cell), int(z // self.cell)), [])


def assign_face(x, z, grid):
    inside = []
    for index in grid.candidates(x, z):
        b = grid.buildings[index]
        if b["minx"] - 0.01 <= x <= b["maxx"] + 0.01 and b["minz"] - 0.01 <= z <= b["maxz"] + 0.01:
            if point_in(x, z, b["poly"]):
                inside.append(b)
    if len(inside) == 1:
        return inside[0], "inside"
    if len(inside) > 1:
        inside.sort(key=lambda b: b["area"])
        return inside[0], "inside_smallest"
    near = []
    for index in grid.candidates(x, z):
        b = grid.buildings[index]
        d = edge_distance(x, z, b["poly"])
        if d <= EDGE_BAND:
            near.append((d, b))
    if not near:
        return None, "unmatched"
    near.sort(key=lambda item: item[0])
    if len(near) > 1 and near[1][0] - near[0][0] < 0.12:
        return None, "ambiguous"
    return near[0][1], "edge"


def game_xz(obj, co):
    world = obj.matrix_world @ co
    return world.x, -world.y, world.z


def main():
    buildings = load_osm()
    by_id = {b["id"]: b for b in buildings}
    grid = Grid(buildings)
    roads = load_roads()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(BLOSM))
    bpy.ops.import_scene.gltf(filepath=str(ARCH))

    blosm = next(obj for obj in bpy.data.objects if obj.name.startswith("dhule_city.osm_buildings"))
    water = [obj for obj in bpy.data.objects if obj.name.startswith("dhule_city.osm_water")]
    keep_names = []
    for osm_id in REPLACE:
        keep_names.append("bld_" + osm_id)
        keep_names.append("col_" + osm_id)
    kept = []
    for obj in list(bpy.data.objects):
        if obj == blosm or obj in water:
            continue
        if any(obj.name == name or obj.name.startswith(name + ".") for name in keep_names):
            kept.append(obj)
        elif obj.type == "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
    for obj in water:
        bpy.data.objects.remove(obj, do_unlink=True)

    bm = bmesh.new()
    bm.from_mesh(blosm.data)
    bm.faces.ensure_lookup_table()
    for face in bm.faces:
        face.select = False
    removed = {osm_id: 0 for osm_id in REPLACE}
    unmatched = 0
    ambiguous = 0
    for face in bm.faces:
        center = face.calc_center_median()
        x, z, y = game_xz(blosm, center)
        owner, how = assign_face(x, z, grid)
        mat_name = ""
        if face.material_index < len(blosm.data.materials) and blosm.data.materials[face.material_index]:
            mat_name = blosm.data.materials[face.material_index].name.lower()
        if owner is None:
            if how == "ambiguous":
                ambiguous += 1
            else:
                unmatched += 1
            continue
        owner["tris"] += 1
        owner["miny"] = min(owner["miny"], y)
        owner["maxy"] = max(owner["maxy"], y)
        if "roof" in mat_name:
            owner["roof"] += 1
        else:
            owner["wall"] += 1
        if owner["id"] in REPLACE and how != "ambiguous":
            face.select = True
            removed[owner["id"]] += 1
    selected = [face for face in bm.faces if face.select]
    bmesh.ops.delete(bm, geom=selected, context="FACES")
    bm.to_mesh(blosm.data)
    blosm.data.update()
    bm.free()
    print("REMAINING_FACES", len(blosm.data.polygons))

    leftover = {osm_id: 0 for osm_id in REPLACE}
    check = bmesh.new()
    check.from_mesh(blosm.data)
    for face in check.faces:
        x, z, _y = game_xz(blosm, face.calc_center_median())
        for osm_id in REPLACE:
            if point_in(x, z, by_id[osm_id]["poly"]):
                leftover[osm_id] += 1
    check.free()

    rows = []
    manifest_buildings = []
    for osm_id, spec in REPLACE.items():
        b = by_id[osm_id]
        gap, road_id = clearance(b["poly"], roads)
        overlaps = []
        for other in buildings:
            if other["id"] == osm_id:
                continue
            if other["maxx"] < b["minx"] or other["minx"] > b["maxx"] or other["maxz"] < b["minz"] or other["minz"] > b["maxz"]:
                continue
            cx = sum(p[0] for p in other["poly"]) / len(other["poly"])
            cz = sum(p[1] for p in other["poly"]) / len(other["poly"])
            if point_in(cx, cz, b["poly"]):
                overlaps.append(other["id"])
        detail = next(obj for obj in kept if obj.name.startswith("bld_" + osm_id))
        col = next(obj for obj in kept if obj.name.startswith("col_" + osm_id))
        corners = [detail.matrix_world @ Vector(c) for c in detail.bound_box]
        min_z = min(v.z for v in corners)
        max_z = max(v.z for v in corners)
        height = round(max_z - min(0.0, min_z), 2)
        ground_ok = abs(min_z) < 0.08
        status = "estimated"
        if b["tags"].get("height") or (b["tags"].get("building:levels") or "").isdigit():
            status = "verified"
        mesh_ok = removed[osm_id] > 0 and leftover[osm_id] == 0
        rows.append({
            "osm_id": osm_id,
            "role": spec["role"],
            "footprint_area_m2": round(b["area"], 2),
            "blosm_tris_removed": removed[osm_id],
            "blosm_tris_left_inside": leftover[osm_id],
            "road_clearance_m": round(gap, 2),
            "nearest_road": road_id,
            "footprint_overlaps": " ".join(overlaps),
            "ground_min_y": round(min_z, 3),
            "roof_height_m": height,
            "height_status": status,
            "collision": col.name,
            "mesh_status": "replaced" if mesh_ok and ground_ok else "failed",
            "note": b["tags"].get("name", ""),
        })
        manifest_buildings.append({
            "osm_id": osm_id,
            "role": spec["role"],
            "kind": spec["kind"],
            "blosm_mesh": "dhule_city.osm_buildings",
            "blosm_triangles": b["tris"],
            "triangles_removed": removed[osm_id],
            "triangles_left_inside_footprint": leftover[osm_id],
            "materials": {"wall": b["wall"], "roof": b["roof"]},
            "bounds_godot": {
                "min_x": round(b["minx"], 2), "max_x": round(b["maxx"], 2),
                "min_z": round(b["minz"], 2), "max_z": round(b["maxz"], 2),
                "min_y": None if b["miny"] > 1e8 else round(b["miny"], 2),
                "max_y": None if b["maxy"] < -1e8 else round(b["maxy"], 2),
            },
            "replacement_object": detail.name,
            "replacement_height_m": height,
            "height_status": status,
            "collision_object": col.name,
            "road_clearance_m": round(gap, 2),
            "nearest_road": road_id,
            "footprint_contains_other_centroids": overlaps,
            "validation": rows[-1]["mesh_status"],
        })

    identified = []
    for b in buildings:
        if b["tris"] <= 0 or b["id"] in REPLACE:
            continue
        identified.append({
            "osm_id": b["id"],
            "blosm_mesh": "dhule_city.osm_buildings",
            "blosm_triangles": b["tris"],
            "materials": {"wall": b["wall"], "roof": b["roof"]},
            "bounds_godot": {
                "min_x": round(b["minx"], 2), "max_x": round(b["maxx"], 2),
                "min_z": round(b["minz"], 2), "max_z": round(b["maxz"], 2),
                "min_y": round(b["miny"], 2), "max_y": round(b["maxy"], 2),
            },
            "osm_building": b["tags"].get("building", ""),
            "osm_name": b["tags"].get("name", ""),
            "replacement_object": None,
            "height_status": "blosm_shell",
            "validation": "kept",
        })

    blosm.name = "blosm_buildings_remaining"
    for obj in kept:
        if obj.name.startswith("col_"):
            obj.hide_render = True

    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [blosm] + kept:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(EXPORT),
        use_selection=True,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_extras=True,
    )
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "replacement_source.blend"))

    payload = {
        "production_glb": {
            "path": "assets/models/environments/dhule_blosm_city.glb",
            "nodes": ["dhule_city.osm_buildings", "dhule_city.osm_water"],
            "preserves_osm_ids": False,
            "per_building_geometry": False,
            "attributes": ["POSITION", "NORMAL"],
            "materials": ["wall", "roof", "water"],
            "reason": "Blosm imported with singleObject left at its default, so every building was joined into one mesh. The glTF has no node extras, no OSM id, and no per-building attribute.",
        },
        "rebuild_path": "Blosm singleObject=False writes one object per building and copies OSM tags onto it, but the object name is the name tag or 'element', not the way id. A test export can store the way id only with a post-step. This experiment does not rewrite the production file. It identifies triangles by the OSM polygon, then deletes only those faces from a test copy.",
        "identification": "Game projection, origin 20.902 N, 74.777 E. A triangle is owned by the OSM polygon that contains its centroid. Faces within 0.45 m of exactly one polygon are included. Ambiguous faces stay in the original mesh.",
        "unmatched_triangles": unmatched,
        "ambiguous_triangles": ambiguous,
        "osm_buildings_in_file": len(buildings),
        "osm_ids_with_triangles": sum(1 for b in buildings if b["tris"] > 0),
        "replacements": manifest_buildings,
        "kept_shells": identified,
    }
    (OUT / "building_identity_manifest.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    with (OUT / "validation.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    print("REPLACE_DONE", {k: removed[k] for k in removed}, "leftover", leftover, "unmatched", unmatched, "ambiguous", ambiguous)


if __name__ == "__main__":
    main()
