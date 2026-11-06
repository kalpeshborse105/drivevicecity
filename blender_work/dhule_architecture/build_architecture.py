"""Sessions Court architectural prototype.

Fits original procedural geometry inside existing OSM footprints.
Does not extrude a second copy of the whole city and does not move polygons.
"""

import csv
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(r"D:\drivevicecity")
OSM = ROOT / "assets" / "maps" / "dhule_city.osm"
ROADS = ROOT / "assets" / "maps" / "dhule_roads_game.json"
SHOPS = ROOT / "data" / "dhule" / "city_shops.json"
OUT = ROOT / "blender_work" / "dhule_architecture"
EXPORT = OUT / "export"
ASSETS = OUT / "reusable_assets"

LAT0 = 20.902
LON0 = 74.777
M_LAT = 111320.0
M_LON = M_LAT * math.cos(math.radians(LAT0))
COURT = "482794524"
SPAWN_ROAD = "887431550"


def xz(lat, lon):
    return ((lon - LON0) * M_LON, -(lat - LAT0) * M_LAT)


def B(x, z, up=0.0):
    return Vector((x, -z, up))


def hypot(x, z):
    return math.hypot(x, z)


def signed_area(poly):
    a = 0.0
    for i, p in enumerate(poly):
        q = poly[(i + 1) % len(poly)]
        a += p[0] * q[1] - q[0] * p[1]
    return a * 0.5


def centroid(poly):
    a = signed_area(poly)
    if abs(a) < 1e-6:
        sx = sum(p[0] for p in poly) / len(poly)
        sz = sum(p[1] for p in poly) / len(poly)
        return sx, sz
    cx = cz = 0.0
    for i, p in enumerate(poly):
        q = poly[(i + 1) % len(poly)]
        c = p[0] * q[1] - q[0] * p[1]
        cx += (p[0] + q[0]) * c
        cz += (p[1] + q[1]) * c
    return cx / (6 * a), cz / (6 * a)


def ensure_ccw(poly):
    return list(reversed(poly)) if signed_area(poly) < 0 else list(poly)


def inset_poly(poly, dist):
    c = centroid(poly)
    n = len(poly)
    lines = []
    for i in range(n):
        a = poly[i]
        b = poly[(i + 1) % n]
        dx, dz = b[0] - a[0], b[1] - a[1]
        length = hypot(dx, dz) or 1.0
        nx, nz = -dz / length, dx / length
        mid = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        if (c[0] - mid[0]) * nx + (c[1] - mid[1]) * nz < 0:
            nx, nz = -nx, -nz
        lines.append(((a[0] + nx * dist, a[1] + nz * dist), (dx, dz)))
    out = []
    for i in range(n):
        p, d = lines[i]
        p2, d2 = lines[(i + 1) % n]
        cross = d[0] * d2[1] - d[1] * d2[0]
        if abs(cross) < 1e-8:
            out.append(p)
            continue
        t = ((p2[0] - p[0]) * d2[1] - (p2[1] - p[1]) * d2[0]) / cross
        out.append((p[0] + d[0] * t, p[1] + d[1] * t))
    if abs(signed_area(out)) < abs(signed_area(poly)) * 0.15:
        return None
    return out


def edge_samples(poly, step=2.0):
    pts = []
    for i, a in enumerate(poly):
        b = poly[(i + 1) % len(poly)]
        pts.append(a)
        length = hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, int(length // step))
        for k in range(1, n):
            t = k / n
            pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return pts


def seg_dist(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    l2 = dx * dx + dz * dz
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / l2))
    qx, qz = a[0] + dx * t, a[1] + dz * t
    return hypot(p[0] - qx, p[1] - qz)


def clearance(poly, roads):
    best = 1e9
    nearest = ""
    for p in edge_samples(poly):
        for road in roads:
            half = float(road.get("width") or 7.0) * 0.5
            pts = road["xz"]
            for i in range(len(pts) - 1):
                d = seg_dist(p, pts[i], pts[i + 1]) - half
                if d < best:
                    best = d
                    nearest = road["id"]
    return best, nearest


def load_osm():
    import xml.etree.ElementTree as ET
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
                    poly = ensure_ccw(poly)
                    buildings.append({
                        "id": elem.attrib["id"],
                        "poly": poly,
                        "tags": tags,
                        "area": abs(signed_area(poly)),
                        "c": centroid(poly),
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
            roads.append({
                "id": str(road.get("id", "")),
                "width": float(road.get("width") or 7.0),
                "highway": str(road.get("highway", "")),
                "xz": pts,
            })
    return roads


def choose(buildings, roads):
    court = next(b for b in buildings if b["id"] == COURT)
    cx, cz = court["c"]
    pool = []
    for b in buildings:
        if hypot(b["c"][0] - cx, b["c"][1] - cz) > 130:
            continue
        gap, road_id = clearance(b["poly"], roads)
        b["clearance"] = gap
        b["nearest_road"] = road_id
        pool.append(b)
    clean = [b for b in pool if b["clearance"] >= 0.3 and b["area"] >= 20 and b["id"] != COURT]
    clean.sort(key=lambda b: b["area"])
    picked = []
    if clean:
        picked.extend(clean[:4])
        mid = len(clean) // 2
        picked.extend(clean[max(0, mid - 2): mid + 3])
        picked.extend(clean[-3:])
    uniq = []
    seen = set()
    for b in picked:
        if b["id"] not in seen:
            seen.add(b["id"])
            uniq.append(b)
    if court["clearance"] >= 0.0:
        uniq.insert(0, court)
    else:
        court["reject"] = "footprint enters a carriageway"
    uniq = uniq[:15]
    chosen = {b["id"] for b in uniq}
    for b in pool:
        b["included"] = b["id"] in chosen
        if b["id"] == COURT and court["clearance"] < 0:
            b["included"] = False
        if not b["included"] and b["clearance"] < 0.3:
            b["reject"] = "carriageway clearance %.2f m" % b["clearance"]
        elif not b["included"]:
            b["reject"] = "not in the 15-building prototype set"
    return uniq, pool, court


def mat(name, color, rough=0.72, metal=0.0, transmission=0.0):
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rough
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metal
    for key in ("Transmission Weight", "Transmission"):
        if key in bsdf.inputs and transmission:
            bsdf.inputs[key].default_value = transmission
    return m


def ensure_mats():
    return {
        "plaster": mat("ArchPlaster", (0.83, 0.75, 0.64, 1.0), 0.78),
        "sand": mat("ArchSand", (0.74, 0.60, 0.45, 1.0), 0.8),
        "civic": mat("ArchCivic", (0.80, 0.78, 0.72, 1.0), 0.7),
        "plinth": mat("ArchPlinth", (0.42, 0.38, 0.34, 1.0), 0.86),
        "roof": mat("ArchRoof", (0.52, 0.50, 0.47, 1.0), 0.84),
        "door": mat("ArchDoor", (0.36, 0.20, 0.11, 1.0), 0.55),
        "frame": mat("ArchFrame", (0.16, 0.29, 0.31, 1.0), 0.45),
        "glass": mat("ArchGlass", (0.62, 0.76, 0.80, 1.0), 0.08, 0.0, 0.8),
        "metal": mat("ArchMetal", (0.62, 0.64, 0.66, 1.0), 0.35, 0.7),
        "shutter": mat("ArchShutter", (0.22, 0.36, 0.30, 1.0), 0.4, 0.35),
        "rail": mat("ArchRail", (0.25, 0.25, 0.24, 1.0), 0.4, 0.5),
    }


def add_box(bm, center, size, mat_idx):
    geom = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, verts=geom["verts"], vec=Vector(size))
    bmesh.ops.translate(bm, verts=geom["verts"], vec=Vector(center))
    faces = set()
    for v in geom["verts"]:
        faces.update(v.link_faces)
    for f in faces:
        f.material_index = mat_idx
        f.smooth = False


def auto_uv(bm):
    uv = bm.loops.layers.uv.new("UVMap")
    for face in bm.faces:
        n = face.normal
        loops = list(face.loops)
        if abs(n.z) > 0.6:
            for loop in loops:
                loop[uv].uv = (loop.vert.co.x * 0.2, loop.vert.co.y * 0.2)
        else:
            origin = loops[0].vert.co
            edge = loops[1].vert.co - origin
            if edge.length < 1e-6:
                edge = Vector((1, 0, 0))
            edge = edge.normalized()
            for loop in loops:
                d = loop.vert.co - origin
                loop[uv].uv = (d.dot(edge) * 0.35, d.z * 0.35)


def new_object(name, bm, col, materials):
    mesh = bpy.data.meshes.new(name)
    auto_uv(bm)
    bm.to_mesh(mesh)
    bm.free()
    for m in materials:
        mesh.materials.append(m)
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    return obj


def style_for(b):
    tags = b["tags"]
    levels = tags.get("building:levels")
    if b["id"] == COURT:
        floors = int(levels) if levels and levels.isdigit() else 2
        return "civic", floors, "estimated" if not tags.get("height") else "known"
    if levels and str(levels).isdigit():
        floors = max(1, min(3, int(levels)))
        status = "known"
    else:
        floors = 1 if b["area"] < 70 else 2
        status = "estimated"
    kind = "house1" if floors == 1 else ("urban" if b["area"] >= 120 else "house2")
    if tags.get("building") not in ("yes", "house", "residential", "apartments"):
        kind = "civic"
    return kind, floors, status


def front_edge(poly, roads):
    best_i = 0
    best_d = 1e9
    road = next((r for r in roads if r["id"] == SPAWN_ROAD), None)
    targets = [road] if road else roads
    for i, a in enumerate(poly):
        b = poly[(i + 1) % len(poly)]
        mid = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        for r in targets:
            pts = r["xz"]
            for k in range(len(pts) - 1):
                d = seg_dist(mid, pts[k], pts[k + 1])
                if d < best_d:
                    best_d = d
                    best_i = i
    return best_i


def aim_face(face, ox, oz):
    face.normal_update()
    if face.normal.x * ox + (-face.normal.y) * oz < 0:
        face.normal_flip()


def wall_shell(bm, outer, inner, z0, z1, mat_idx):
    n = len(outer)
    for i in range(n):
        j = (i + 1) % n
        dx = outer[j][0] - outer[i][0]
        dz = outer[j][1] - outer[i][1]
        length = hypot(dx, dz) or 1.0
        ox, oz = dz / length, -dx / length
        ob0 = bm.verts.new(B(outer[i][0], outer[i][1], z0))
        ob1 = bm.verts.new(B(outer[j][0], outer[j][1], z0))
        ot0 = bm.verts.new(B(outer[i][0], outer[i][1], z1))
        ot1 = bm.verts.new(B(outer[j][0], outer[j][1], z1))
        ib0 = bm.verts.new(B(inner[i][0], inner[i][1], z0))
        ib1 = bm.verts.new(B(inner[j][0], inner[j][1], z0))
        it0 = bm.verts.new(B(inner[i][0], inner[i][1], z1))
        it1 = bm.verts.new(B(inner[j][0], inner[j][1], z1))
        specs = (
            ((ob0, ob1, ot1, ot0), ox, oz, False),
            ((ib1, ib0, it0, it1), -ox, -oz, False),
            ((ot0, ot1, it1, it0), 0.0, 0.0, True),
        )
        for verts, ax, az, top in specs:
            try:
                face = bm.faces.new(verts)
                face.material_index = mat_idx
                face.smooth = False
                if top:
                    face.normal_update()
                    if face.normal.z < 0:
                        face.normal_flip()
                else:
                    aim_face(face, ax, az)
            except ValueError:
                pass


def slab(bm, poly, z0, z1, mat_idx):
    n = len(poly)
    bot = [bm.verts.new(B(p[0], p[1], z0)) for p in poly]
    top = [bm.verts.new(B(p[0], p[1], z1)) for p in poly]
    try:
        f = bm.faces.new(list(reversed(bot)))
        f.material_index = mat_idx
        f.normal_update()
        if f.normal.z > 0:
            f.normal_flip()
        f = bm.faces.new(top)
        f.material_index = mat_idx
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    except ValueError:
        return
    for i in range(n):
        j = (i + 1) % n
        try:
            f = bm.faces.new((bot[i], bot[j], top[j], top[i]))
            f.material_index = mat_idx
            f.smooth = False
            dx = poly[j][0] - poly[i][0]
            dz = poly[j][1] - poly[i][1]
            length = hypot(dx, dz) or 1.0
            aim_face(f, dz / length, -dx / length)
        except ValueError:
            pass


def place_windows(bm, outer, floors, floor_h, plinth, door_i, mats, idx, spacing=2.15):
    for i, a in enumerate(outer):
        b = outer[(i + 1) % len(outer)]
        dx, dz = b[0] - a[0], b[1] - a[1]
        length = hypot(dx, dz)
        if length < 2.6:
            continue
        ux, uz = dx / length, dz / length
        nx, nz = uz, -ux
        door_center = length * 0.5 if i == door_i else None
        cursor = 1.15
        while cursor < length - 1.15:
            if door_center is not None and abs(cursor - door_center) < 1.15:
                cursor += 1.7
                continue
            px = a[0] + ux * cursor
            pz = a[1] + uz * cursor
            for fl in range(floors):
                sill = plinth + fl * floor_h + 0.85
                win_w = 1.05
                win_h = 1.15
                along_x = abs(ux) >= abs(uz)
                for side in (-1.0, 1.0):
                    c = B(px + ux * side * win_w * 0.5 + nx * 0.05, pz + uz * side * win_w * 0.5 + nz * 0.05, sill + win_h * 0.5)
                    add_box(bm, (c.x, c.y, c.z), (0.08, 0.1, win_h) if along_x else (0.1, 0.08, win_h), idx["frame"])
                for zoff in (0.0, win_h):
                    c = B(px + nx * 0.05, pz + nz * 0.05, sill + zoff)
                    add_box(bm, (c.x, c.y, c.z), (win_w, 0.1, 0.07) if along_x else (0.1, win_w, 0.07), idx["frame"])
                glass_c = B(px - nx * 0.03, pz - nz * 0.03, sill + win_h * 0.5)
                add_box(bm, (glass_c.x, glass_c.y, glass_c.z), (win_w - 0.18, 0.03, win_h - 0.16) if along_x else (0.03, win_w - 0.18, win_h - 0.16), idx["glass"])
                chajja = B(px + nx * 0.2, pz + nz * 0.2, sill + win_h + 0.05)
                add_box(bm, (chajja.x, chajja.y, chajja.z), (win_w + 0.28, 0.36, 0.06) if along_x else (0.36, win_w + 0.28, 0.06), idx["roof"])
            cursor += spacing


def place_door(bm, outer, door_i, plinth, mats_idx, wide=1.0):
    a = outer[door_i]
    b = outer[(door_i + 1) % len(outer)]
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = hypot(dx, dz) or 1.0
    ux, uz = dx / length, dz / length
    nx, nz = uz, -ux
    px = (a[0] + b[0]) * 0.5
    pz = (a[1] + b[1]) * 0.5
    along = wide
    depth = 0.08
    sx = depth if abs(ux) < abs(uz) else along
    sy = along if abs(ux) < abs(uz) else depth
    # The test above mixes axes. Orient by the wall normal in Blender: X=east (ux), Y=north (-uz).
    center = B(px + nx * 0.03, pz + nz * 0.03, plinth + 1.05)
    size_x = abs(ux) * along + abs(nx) * depth
    size_y = abs(uz) * along + abs(nz) * depth
    add_box(bm, (center.x, center.y, center.z), (max(size_x, 0.06), max(size_y, 0.06), 2.1), mats_idx["door"])
    frame_c = B(px + nx * 0.07, pz + nz * 0.07, plinth + 1.15)
    add_box(bm, (frame_c.x, frame_c.y, frame_c.z), (max(size_x, 0.06) + 0.12, max(size_y, 0.06) + 0.12, 2.35), mats_idx["frame"])


def place_balcony(bm, outer, door_i, z, idx):
    a = outer[door_i]
    b = outer[(door_i + 1) % len(outer)]
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = hypot(dx, dz)
    if length < 3.2:
        return
    ux, uz = dx / length, dz / length
    nx, nz = uz, -ux
    px = (a[0] + b[0]) * 0.5 + nx * 0.55
    pz = (a[1] + b[1]) * 0.5 + nz * 0.55
    span = min(3.2, length * 0.45)
    sx = abs(ux) * span + abs(nx) * 1.0
    sy = abs(uz) * span + abs(nz) * 1.0
    c = B(px, pz, z)
    add_box(bm, (c.x, c.y, c.z), (max(sx, 0.2), max(sy, 0.2), 0.12), idx["roof"])
    rail_z = z + 0.85
    for t in (-0.4, 0.4):
        rx = px + ux * span * t
        rz = pz + uz * span * t
        rc = B(rx, rz, rail_z)
        add_box(bm, (rc.x, rc.y, rc.z), (0.06, 0.06, 0.7), idx["rail"])


def place_tank_and_stair(bm, poly, roof_z, idx):
    cx, cz = centroid(poly)
    c = B(cx, cz, roof_z + 0.7)
    geom = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.62, radius2=0.62, depth=1.05)
    bmesh.ops.translate(bm, verts=geom["verts"], vec=c)
    for v in geom["verts"]:
        for f in v.link_faces:
            f.material_index = idx["metal"]
            f.smooth = False
    corner = poly[0]
    s = B((cx + corner[0]) * 0.5, (cz + corner[1]) * 0.5, roof_z + 1.15)
    add_box(bm, (s.x, s.y, s.z), (1.25, 1.15, 2.2), idx["plaster"])
    for step in range(4):
        st = B(s.x + 0.9, s.y, roof_z + 0.12 + step * 0.18)
        add_box(bm, (st.x, st.y, st.z), (0.7, 0.28, 0.08), idx["roof"])


def build_building(b, roads, cols, mats, idx, library=False, kind=None, floors=None):
    poly = ensure_ccw(b["poly"])
    if kind is None:
        kind, floors, status = style_for(b)
    else:
        status = "library"
    outer = inset_poly(poly, 0.06) or poly
    courtyard = kind == "civic" and b["area"] > 2000
    inner = inset_poly(outer, 14.0 if courtyard else 0.23)
    floor_h = 3.55 if kind == "civic" else (3.25 if kind == "urban" else 3.05)
    plinth = 0.55 if kind == "civic" else 0.42
    parapet = 0.45 if kind == "civic" else 0.78
    wall_top = plinth + floors * floor_h
    roof_top = wall_top + 0.14
    total_h = roof_top + parapet
    try:
        sand = int(str(b["id"])) % 2 == 0
    except ValueError:
        sand = False
    plaster_key = "civic" if kind == "civic" else ("sand" if sand else "plaster")
    if kind in ("kirana", "commercial"):
        plaster_key = "plaster"
    bm = bmesh.new()
    if courtyard and inner:
        wall_shell(bm, outer, inner, 0.0, plinth, idx["plinth"])
        wall_shell(bm, outer, inner, plinth, wall_top, idx[plaster_key])
        wall_shell(bm, outer, inner, wall_top, roof_top, idx["roof"])
    else:
        slab(bm, outer, 0.0, plinth, idx["plinth"])
        if inner:
            wall_shell(bm, outer, inner, plinth, wall_top, idx[plaster_key])
            slab(bm, inner, wall_top, roof_top, idx["roof"])
        else:
            slab(bm, outer, plinth, wall_top, idx[plaster_key])
            slab(bm, outer, wall_top, roof_top, idx["roof"])
    parapet_outer = outer
    parapet_inner = inset_poly(outer, 0.12) or inner or outer
    if parapet_inner is not outer:
        wall_shell(bm, parapet_outer, parapet_inner, roof_top, roof_top + parapet, idx[plaster_key])
    door_i = 2 if library else front_edge(outer, roads)
    if kind in ("kirana", "commercial"):
        place_shutter(bm, outer, door_i, plinth, wall_top, idx)
    else:
        place_door(bm, outer, door_i, plinth, idx, 1.5 if kind == "civic" else 0.96)
        place_windows(bm, outer, floors, floor_h, plinth, door_i, mats, idx, 4.8 if courtyard else 2.15)
    if kind in ("house2", "urban") and floors >= 2:
        place_balcony(bm, outer, door_i, plinth + floor_h, idx)
    if kind in ("house2", "urban", "house1") and b["area"] > 35:
        place_tank_and_stair(bm, outer, roof_top, idx)
    name = "lib_" + kind if library else "bld_" + b["id"]
    obj = new_object(name, bm, cols["visual"], [mats[k] for k in (
        "plaster", "sand", "civic", "plinth", "roof", "door", "frame", "glass", "metal", "shutter", "rail"
    )])
    # material index must match the list order used by idx
    obj["osm_id"] = b["id"]
    obj["kind"] = kind
    obj["status"] = status
    obj["height_m"] = round(total_h, 2)
    if not library:
        cbm = bmesh.new()
        if courtyard and inner:
            wall_shell(cbm, poly, inset_poly(poly, 14.0) or inner, 0.0, total_h, 0)
            b["built_note"] = "large OSM outline built as a 14 m courtyard wing; interior left open; height estimated"
        else:
            slab(cbm, poly, 0.0, total_h, 0)
        col = new_object("col_" + b["id"], cbm, cols["collision"], [])
        col["osm_id"] = b["id"]
        col.hide_render = True
    return total_h, status, kind, floors


def place_shutter(bm, outer, door_i, plinth, wall_top, idx):
    a = outer[door_i]
    bpt = outer[(door_i + 1) % len(outer)]
    dx, dz = bpt[0] - a[0], bpt[1] - a[1]
    length = hypot(dx, dz) or 1.0
    ux, uz = dx / length, dz / length
    nx, nz = uz, -ux
    width = min(2.4, length * 0.55)
    px = (a[0] + bpt[0]) * 0.5
    pz = (a[1] + bpt[1]) * 0.5
    for s in range(7):
        z = plinth + 0.35 + s * 0.28
        c = B(px + nx * 0.08, pz + nz * 0.08, z)
        sx = abs(ux) * width + abs(nx) * 0.05
        sy = abs(uz) * width + abs(nz) * 0.05
        add_box(bm, (c.x, c.y, c.z), (max(sx, 0.05), max(sy, 0.05), 0.08), idx["shutter"])
    place_door(bm, outer, (door_i + 1) % len(outer), plinth, idx, 0.9)


def rect(cx, cz, sx, sz):
    return [
        (cx - sx * 0.5, cz - sz * 0.5),
        (cx + sx * 0.5, cz - sz * 0.5),
        (cx + sx * 0.5, cz + sz * 0.5),
        (cx - sx * 0.5, cz + sz * 0.5),
    ]


def component_objects(cols, mats, idx):
    made = []
    specs = {
        "door": (0.12, 0.96, 2.15, idx["door"]),
        "window": (0.12, 1.15, 1.25, idx["frame"]),
        "balcony": (1.1, 3.0, 0.12, idx["roof"]),
        "parapet": (0.15, 2.4, 0.8, idx["plaster"]),
        "compound_wall": (0.23, 4.0, 1.7, idx["plinth"]),
        "gate": (0.08, 2.6, 2.0, idx["metal"]),
        "rooftop_tank": (1.2, 1.2, 1.05, idx["metal"]),
        "stair_access": (1.3, 1.2, 2.3, idx["plaster"]),
        "roof_detail": (1.6, 1.6, 0.16, idx["roof"]),
        "shutter_storefront": (0.08, 2.4, 2.1, idx["shutter"]),
    }
    x = 4300.0
    for i, (name, (sx, sy, sz, mi)) in enumerate(specs.items()):
        bm = bmesh.new()
        add_box(bm, (x + i * 3.2, 12.0, sz * 0.5), (sx, sy, sz), mi)
        if name == "window":
            add_box(bm, (x + i * 3.2, 12.0, sz * 0.5), (0.04, 0.85, 0.95), idx["glass"])
        obj = new_object("component_" + name, bm, cols["components"], list(mats.values()))
        obj["kit"] = name
        made.append(obj)
    return made


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


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    buildings = load_osm()
    roads = load_roads()
    picked, pool, court = choose(buildings, roads)
    mats = ensure_mats()
    order = ["plaster", "sand", "civic", "plinth", "roof", "door", "frame", "glass", "metal", "shutter", "rail"]
    idx = {name: i for i, name in enumerate(order)}
    cols = {
        "visual": bpy.data.collections.new("PrototypeBuildings"),
        "collision": bpy.data.collections.new("Collision"),
        "library": bpy.data.collections.new("ReusableLibrary"),
        "components": bpy.data.collections.new("Components"),
    }
    for c in cols.values():
        bpy.context.scene.collection.children.link(c)
    rows = []
    meta = []
    for b in pool:
        height = ""
        status = "estimated"
        mesh_status = "not_built"
        collision_status = "not_built"
        kind = ""
        floors = ""
        if b.get("included"):
            height, status, kind, floors = build_building(b, roads, cols, mats, idx)
            mesh_status = "built"
            collision_status = "trimesh_prism"
        elif b["id"] == COURT and b["clearance"] < 0:
            mesh_status = "reported_not_built"
            collision_status = "reported_not_built"
        rows.append({
            "osm_id": b["id"],
            "footprint_area_m2": round(b["area"], 2),
            "height_m": round(height, 2) if height != "" else "",
            "status": status if b.get("included") else "estimated",
            "osm_building": b["tags"].get("building", ""),
            "osm_name": b["tags"].get("name", ""),
            "road_clearance_m": round(b["clearance"], 2),
            "nearest_road": b["nearest_road"],
            "collision_status": collision_status,
            "mesh_status": mesh_status,
            "included": "yes" if b.get("included") else "no",
            "note": b.get("built_note") or b.get("reject") or kind,
        })
        if b.get("included"):
            meta.append({
                "osm_id": b["id"],
                "kind": kind,
                "floors": floors,
                "height_m": round(height, 2),
                "status": status,
                "osm_building": b["tags"].get("building", ""),
                "osm_name": b["tags"].get("name", ""),
                "godot_x": round(b["c"][0], 2),
                "godot_z": round(b["c"][1], 2),
                "area_m2": round(b["area"], 2),
                "clearance_m": round(b["clearance"], 2),
            })
    shops = json.loads(SHOPS.read_text(encoding="utf-8"))["shops"]
    shop_notes = []
    for shop in shops:
        d = hypot(shop["x"] - court["c"][0], shop["z"] - court["c"][1])
        shop_notes.append({"id": shop["id"], "name": shop["name"], "distance_to_court_m": round(d, 1)})

    lib_specs = [
        ("house1", 1, 8.0, 6.0),
        ("house2", 2, 8.0, 7.0),
        ("urban", 2, 10.0, 8.0),
        ("kirana", 1, 5.4, 4.2),
        ("commercial", 1, 8.0, 6.0),
    ]
    lib_objs = []
    for i, (kind, floors, sx, sz) in enumerate(lib_specs):
        item = {
            "id": "library_" + kind,
            "poly": rect(4500 + i * 16, 40, sx, sz),
            "tags": {"building": "library"},
            "area": sx * sz,
            "c": (4500 + i * 16, 40),
        }
        build_building(item, roads, cols, mats, idx, library=True, kind=kind, floors=floors)
        obj = bpy.data.objects["lib_" + kind]
        cols["visual"].objects.unlink(obj)
        cols["library"].objects.link(obj)
        lib_objs.append(obj)
    components = component_objects(cols, mats, idx)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in list(cols["visual"].objects) + list(cols["collision"].objects):
        obj.select_set(True)
    export_selected(EXPORT / "dhule_architecture_test.glb")

    bpy.ops.object.select_all(action="DESELECT")
    for obj in lib_objs + components:
        obj.select_set(True)
    export_selected(ASSETS / "reusable_library.glb")
    for obj in lib_objs + components:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        export_selected(ASSETS / ((obj.get("kit") or obj.get("kind") or obj.name) + ".glb"))

    OUT.mkdir(parents=True, exist_ok=True)
    with (OUT / "validation.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    payload = {
        "projection": {"lat": LAT0, "lon": LON0, "metres_per_degree": M_LAT, "x": "east", "y": "up", "z": "south"},
        "court_osm_id": COURT,
        "spawn_road": SPAWN_ROAD,
        "court_godot": {"x": round(court["c"][0], 2), "z": round(court["c"][1], 2)},
        "shops_not_placed": shop_notes,
        "buildings": meta,
        "library_godot_origin_x": 4500,
        "note": "Library meshes are not placed on OSM footprints. building=yes stays estimated and is not treated as a shop.",
    }
    (OUT / "building_metadata.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "architecture_source.blend"))
    print("ARCH_DONE", len(meta), "built", sum(1 for r in rows if r["mesh_status"] != "built"), "reported")


if __name__ == "__main__":
    main()
