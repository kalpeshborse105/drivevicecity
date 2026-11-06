"""Sessions Court reference scene in the game's coordinate system.

Flat OSM footprints and the production road polylines only.
Buildings are not extruded, so this does not stack a second city
on assets/models/environments/dhule_blosm_city.glb.

Blender: X east, Y north, Z up.
Godot glTF import: X east, Y up, Z south.
"""

import json
import math
import xml.etree.ElementTree as ET
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(r"D:\drivevicecity")
OSM_PATH = ROOT / "assets" / "maps" / "dhule_city.osm"
ROADS_PATH = ROOT / "assets" / "maps" / "dhule_roads_game.json"
OUT_DIR = ROOT / "blender_work" / "dhule_gis_test"
EXPORT_DIR = OUT_DIR / "export"

ORIGIN_LAT = 20.902
ORIGIN_LON = 74.777
METRES_PER_DEG = 111320.0
LON_SCALE = METRES_PER_DEG * math.cos(math.radians(ORIGIN_LAT))

# Sessions Court cell from the coverage report, with a small margin.
X_MIN, X_MAX = -820.0, -420.0
Z_MIN, Z_MAX = 680.0, 1080.0


def game_xz(lat, lon):
    x = (lon - ORIGIN_LON) * LON_SCALE
    z = -(lat - ORIGIN_LAT) * METRES_PER_DEG
    return x, z


def inside(x, z):
    return X_MIN <= x <= X_MAX and Z_MIN <= z <= Z_MAX


def blender_co(x, z, y=0.0):
    # Blender Y is north, which is negative Godot Z.
    return (x, -z, y)


def new_collection(name):
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    return col


def link(col, obj):
    col.objects.link(obj)
    return obj


def mesh_object(name, bm, col):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    return link(col, obj)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_footprints(col_buildings, col_landmarks):
    nodes = {}
    buildings = 0
    named = 0
    for _event, elem in ET.iterparse(OSM_PATH, events=("end",)):
        if elem.tag == "node":
            nodes[elem.attrib["id"]] = (float(elem.attrib["lat"]), float(elem.attrib["lon"]))
            elem.clear()
        elif elem.tag == "way":
            tags = {tag.attrib["k"]: tag.attrib["v"] for tag in elem.findall("tag")}
            if "building" not in tags:
                elem.clear()
                continue
            pts = []
            for nd in elem.findall("nd"):
                latlon = nodes.get(nd.attrib["ref"])
                if latlon is None:
                    continue
                x, z = game_xz(*latlon)
                pts.append((x, z))
            if len(pts) >= 4 and pts[0] == pts[-1]:
                pts = pts[:-1]
            if len(pts) < 3:
                elem.clear()
                continue
            cx = sum(p[0] for p in pts) / len(pts)
            cz = sum(p[1] for p in pts) / len(pts)
            if not inside(cx, cz):
                elem.clear()
                continue
            osm_id = elem.attrib["id"]
            bm = bmesh.new()
            verts = [bm.verts.new(blender_co(x, z)) for x, z in pts]
            try:
                face = bm.faces.new(verts)
                face.normal_update()
                if face.normal.z < 0:
                    face.normal_flip()
            except ValueError:
                bm.free()
                elem.clear()
                continue
            name = tags.get("name") or ("building_" + osm_id)
            obj = mesh_object("fp_" + osm_id, bm, col_buildings)
            obj["osm_id"] = osm_id
            obj["building"] = tags.get("building", "")
            if "name" in tags:
                obj["name_tag"] = tags["name"]
                named += 1
                empty = bpy.data.objects.new("name_" + osm_id, None)
                empty.empty_display_type = "PLAIN_AXES"
                empty.empty_display_size = 2.0
                empty.location = blender_co(cx, cz, 0.2)
                empty["osm_id"] = osm_id
                empty["name_tag"] = tags["name"]
                link(col_landmarks, empty)
            buildings += 1
            elem.clear()
    return buildings, named


def import_roads(col):
    data = json.loads(ROADS_PATH.read_text(encoding="utf-8"))
    kept = 0
    for road in data["roads"]:
        pts = road.get("points") or road.get("pts") or []
        coords = []
        for pt in pts:
            if isinstance(pt, dict):
                x, z = float(pt["x"]), float(pt["z"])
            else:
                x, z = float(pt[0]), float(pt[1])
            coords.append((x, z))
        if not any(inside(x, z) for x, z in coords):
            continue
        if len(coords) < 2:
            continue
        half = min(float(road.get("width", 7.0) or 7.0) * 0.5, 6.0)
        bm = bmesh.new()
        left = []
        right = []
        for i, (x, z) in enumerate(coords):
            nxt = coords[i + 1] if i < len(coords) - 1 else coords[i - 1]
            dx = (nxt[0] - x) if i < len(coords) - 1 else (x - nxt[0])
            dz = (nxt[1] - z) if i < len(coords) - 1 else (z - nxt[1])
            length = math.hypot(dx, dz) or 1.0
            rx, rz = -dz / length * half, dx / length * half
            left.append(blender_co(x + rx, z + rz, 0.02))
            right.append(blender_co(x - rx, z - rz, 0.02))
        verts_l = [bm.verts.new(p) for p in left]
        verts_r = [bm.verts.new(p) for p in right]
        for i in range(len(coords) - 1):
            try:
                face = bm.faces.new((verts_l[i], verts_l[i + 1], verts_r[i + 1], verts_r[i]))
                face.normal_update()
                if face.normal.z < 0:
                    face.normal_flip()
            except ValueError:
                pass
        osm_id = str(road.get("id", kept))
        obj = mesh_object("road_" + osm_id, bm, col)
        obj["osm_id"] = osm_id
        obj["highway"] = str(road.get("highway", ""))
        kept += 1
    return kept


def add_flat_ground(col):
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=1.0)
    # Grid is 2x2 centred on origin. Scale it onto the neighbourhood.
    sx = (X_MAX - X_MIN) * 0.5
    sy = (Z_MAX - Z_MIN) * 0.5
    cx = (X_MIN + X_MAX) * 0.5
    cz = (Z_MIN + Z_MAX) * 0.5
    bmesh.ops.scale(bm, vec=(sx, sy, 1), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(blender_co(cx, cz, 0.0)), verts=bm.verts)
    obj = mesh_object("Terrain_FlatReference", bm, col)
    obj["note"] = "No DEM loaded. This plane is y=0, matching the current game ground."
    return obj


def box(bm, sx, sy, sz, origin):
    geom = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=geom["verts"])
    bmesh.ops.translate(bm, vec=Vector((origin[0], origin[1], origin[2] + sz * 0.5)), verts=geom["verts"])


def build_kit(col):
    """Reusable shapes. They sit on a yard away from the court coordinates."""
    yard = (2500.0, 0.0, 0.0)
    specs = [
        ("Kit_SingleStoreyHouse", (8.0, 6.0, 3.2), (0, 0, 0)),
        ("Kit_TwoStoreyHouse", (8.0, 7.0, 6.4), (14, 0, 0)),
        ("Kit_KiranaShop", (5.0, 4.0, 3.0), (28, 0, 0)),
        ("Kit_CommercialBuilding", (12.0, 10.0, 12.0), (46, 0, 0)),
    ]
    made = []
    for name, size, offset in specs:
        bm = bmesh.new()
        box(bm, *size, (yard[0] + offset[0], yard[1] + offset[1], 0))
        obj = mesh_object(name, bm, col)
        obj["kit"] = True
        obj["note"] = "Reusable visual. Not a claim about a real Dhule building."
        made.append(obj)

    wall = bmesh.new()
    box(wall, 18.0, 0.25, 1.8, (yard[0] + 70, yard[1], 0))
    box(wall, 0.25, 12.0, 1.8, (yard[0] + 79, yard[1] + 6, 0))
    made.append(mesh_object("Kit_CompoundWall", wall, col))

    gate = bmesh.new()
    box(gate, 3.2, 0.12, 2.2, (yard[0] + 70, yard[1] - 8, 0))
    made.append(mesh_object("Kit_Gate", gate, col))

    tank = bmesh.new()
    geom = bmesh.ops.create_cube(tank, size=1.0)
    bmesh.ops.scale(tank, vec=(1.6, 1.6, 1.2), verts=geom["verts"])
    bmesh.ops.translate(tank, vec=Vector((yard[0] + 90, 4, 7.0)), verts=geom["verts"])
    made.append(mesh_object("Kit_RooftopWaterTank", tank, col))

    balcony = bmesh.new()
    box(balcony, 3.0, 1.1, 0.12, (yard[0] + 100, 0, 3.0))
    made.append(mesh_object("Kit_Balcony", balcony, col))

    door = bmesh.new()
    box(door, 0.12, 0.9, 2.1, (yard[0] + 108, 0, 0))
    made.append(mesh_object("Kit_Door", door, col))

    window = bmesh.new()
    box(window, 0.08, 1.2, 1.1, (yard[0] + 112, 0, 1.4))
    made.append(mesh_object("Kit_Window", window, col))
    for obj in made:
        obj["kit"] = True
    return len(made)


def export_selected(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        use_selection=True,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_extras=True,
    )


def select_collection(col, selected):
    for obj in col.objects:
        obj.select_set(selected)


def main():
    clear_scene()
    buildings = new_collection("OSM_Footprints")
    roads = new_collection("OSM_Roads")
    landmarks = new_collection("OSM_Landmarks")
    terrain = new_collection("Terrain")
    kit = new_collection("IndianCityKit")

    n_buildings, n_named = import_footprints(buildings, landmarks)
    n_roads = import_roads(roads)
    add_flat_ground(terrain)
    n_kit = build_kit(kit)

    bpy.ops.object.select_all(action="DESELECT")
    for col in (buildings, roads, landmarks, terrain):
        select_collection(col, True)
    city_glb = EXPORT_DIR / "sessions_court_reference.glb"
    export_selected(city_glb)

    bpy.ops.object.select_all(action="DESELECT")
    select_collection(kit, True)
    kit_glb = EXPORT_DIR / "indian_city_kit.glb"
    export_selected(kit_glb)

    blend_path = OUT_DIR / "sessions_court_test.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

    manifest = {
        "origin_lat": ORIGIN_LAT,
        "origin_lon": ORIGIN_LON,
        "metres_per_degree": METRES_PER_DEG,
        "window_godot_xz": [X_MIN, X_MAX, Z_MIN, Z_MAX],
        "footprints": n_buildings,
        "named_landmarks": n_named,
        "roads": n_roads,
        "kit_objects": n_kit,
        "extruded_buildings": 0,
        "dem": "not loaded",
        "city_glb": str(city_glb),
        "kit_glb": str(kit_glb),
        "blend": str(blend_path),
    }
    (OUT_DIR / "sessions_court_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("TEST_SCENE", json.dumps(manifest))


if __name__ == "__main__":
    main()
