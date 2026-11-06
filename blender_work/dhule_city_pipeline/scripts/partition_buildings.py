"""Partition the joined Blosm city mesh by OSM way id.

Reads the production GLB and dhule_city.osm. Writes a test export only.
Does not modify the production mesh, roads, or spawn.

A triangle is assigned only when every vertex is inside one footprint, or
within 0.20 m of that footprint and at least 0.50 m farther from every other
footprint. Triangles that meet two footprints, or that cross an edge by more
than 0.20 m, are not split. They are written to unresolved_geometry.glb.
"""
import hashlib
import json
import math
import struct
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

ROOT = Path(r"D:\drivevicecity")
GLB = ROOT / "assets" / "models" / "environments" / "dhule_blosm_city.glb"
OSM = ROOT / "assets" / "maps" / "dhule_city.osm"
ARCH = ROOT / "blender_work" / "dhule_architecture" / "export" / "dhule_architecture_test.glb"
OUT = ROOT / "blender_work" / "dhule_city_pipeline"
EXPORT = OUT / "export"
BUILDINGS = EXPORT / "buildings"
LAT0 = 20.902
LON0 = 74.777
M_LAT = 111320.0
M_LON = M_LAT * math.cos(math.radians(LAT0))
EDGE = 0.20
MARGIN = 0.50
REPLACE = ("1337951722", "1337953905", "482794524")
COURT = "482794524"


def xz(lat, lon):
    return (lon - LON0) * M_LON, -(lat - LAT0) * M_LAT


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
        best = min(best, math.hypot(x - (a[0] + dx * t), z - (a[1] + dz * t)))
    return best


def load_buildings():
    nodes = {}
    buildings = []
    seen = set()
    duplicates = []
    for _ev, elem in ET.iterparse(OSM, events=("end",)):
        if elem.tag == "node":
            nodes[elem.attrib["id"]] = (float(elem.attrib["lat"]), float(elem.attrib["lon"]))
            elem.clear()
        elif elem.tag == "way":
            tags = {t.attrib["k"]: t.attrib["v"] for t in elem.findall("tag")}
            if "building" in tags:
                wid = elem.attrib["id"]
                if wid in seen:
                    duplicates.append(wid)
                seen.add(wid)
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
                        "id": wid,
                        "name": tags.get("name", ""),
                        "building": tags.get("building", ""),
                        "poly": poly,
                        "minx": min(xs), "maxx": max(xs),
                        "minz": min(zs), "maxz": max(zs),
                        "cx": sum(xs) / len(xs),
                        "cz": sum(zs) / len(zs),
                    })
            elem.clear()
    return buildings, duplicates


class Grid:
    def __init__(self, buildings, cell=40.0):
        self.cell = cell
        self.bins = {}
        self.buildings = buildings
        for index, building in enumerate(buildings):
            x0 = int(building["minx"] // cell)
            x1 = int(building["maxx"] // cell)
            z0 = int(building["minz"] // cell)
            z1 = int(building["maxz"] // cell)
            for ix in range(x0, x1 + 1):
                for iz in range(z0, z1 + 1):
                    self.bins.setdefault((ix, iz), []).append(index)

    def hits(self, x, z):
        found = []
        for index in self.bins.get((int(x // self.cell), int(z // self.cell)), []):
            building = self.buildings[index]
            if building["minx"] <= x <= building["maxx"] and building["minz"] <= z <= building["maxz"]:
                if point_in(x, z, building["poly"]):
                    found.append(index)
        return found

    def nearest(self, x, z):
        ix = int(x // self.cell)
        iz = int(z // self.cell)
        ranked = []
        seen = set()
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for index in self.bins.get((ix + dx, iz + dz), []):
                    if index in seen:
                        continue
                    seen.add(index)
                    building = self.buildings[index]
                    ranked.append((edge_distance(x, z, building["poly"]), building["id"]))
        ranked.sort()
        return ranked


def read_glb(path):
    data = path.read_bytes()
    clen = struct.unpack_from("<I", data, 12)[0]
    js = json.loads(data[20:20 + clen])
    off = 20 + clen
    if off % 4:
        off += 4 - (off % 4)
    blen = struct.unpack_from("<I", data, off)[0]
    return js, data[off + 8:off + 8 + blen]


def read_accessor(js, buf, index):
    acc = js["accessors"][index]
    view = js["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    comp = {"SCALAR": 1, "VEC3": 3}[acc["type"]]
    fmt = {5123: "H", 5125: "I", 5126: "f"}[acc["componentType"]]
    size = struct.calcsize(fmt)
    stride = view.get("byteStride", size * comp)
    out = []
    for i in range(acc["count"]):
        out.append(struct.unpack_from("<" + fmt * comp, buf, start + i * stride))
    return out


def pad4(blob):
    return blob + b"\x00" * ((4 - (len(blob) % 4)) % 4)


def write_glb(path, meshes, materials):
    """meshes: list of {name, extras, prims:[{material, positions, normals, indices}]}"""
    bin_blob = bytearray()
    views = []
    accessors = []
    gltf_meshes = []
    nodes = []

    def push(values, fmt, comp_type, acc_type, target=None):
        raw = bytearray()
        for value in values:
            if isinstance(value, tuple):
                raw += struct.pack("<" + fmt * len(value), *value)
            else:
                raw += struct.pack("<" + fmt, value)
        raw = pad4(raw)
        offset = len(bin_blob)
        bin_blob.extend(raw)
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(raw), **({"target": target} if target else {})})
        view_index = len(views) - 1
        acc = {"bufferView": view_index, "componentType": comp_type, "count": len(values), "type": acc_type}
        if acc_type == "VEC3" and values:
            xs = [v[0] for v in values]
            ys = [v[1] for v in values]
            zs = [v[2] for v in values]
            acc["min"] = [min(xs), min(ys), min(zs)]
            acc["max"] = [max(xs), max(ys), max(zs)]
        accessors.append(acc)
        return len(accessors) - 1

    mat_index = {mat["name"]: i for i, mat in enumerate(materials)}
    for mesh in meshes:
        prims = []
        for prim in mesh["prims"]:
            if not prim["indices"]:
                continue
            ipos = push(prim["positions"], "f", 5126, "VEC3", 34962)
            inorm = push(prim["normals"], "f", 5126, "VEC3", 34962)
            use_short = len(prim["positions"]) <= 65535
            iidx = push(prim["indices"], "H" if use_short else "I", 5123 if use_short else 5125, "SCALAR", 34963)
            prims.append({
                "attributes": {"POSITION": ipos, "NORMAL": inorm},
                "indices": iidx,
                "material": mat_index[prim["material"]],
            })
        if not prims:
            continue
        gltf_meshes.append({"name": mesh["name"], "primitives": prims})
        node = {"name": mesh["name"], "mesh": len(gltf_meshes) - 1}
        if mesh.get("extras"):
            node["extras"] = mesh["extras"]
        nodes.append(node)
    if not nodes:
        raise RuntimeError("no meshes to write " + str(path))
    gltf = {
        "asset": {"version": "2.0", "generator": "drivevicecity-partition"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": gltf_meshes,
        "materials": materials,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(bin_blob)}],
    }
    payload = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    while len(payload) % 4:
        payload += b" "
    blob = pad4(bin_blob)
    out = bytearray()
    out += struct.pack("<4sII", b"glTF", 2, 0)
    out += struct.pack("<I4s", len(payload), b"JSON")
    out += payload
    out += struct.pack("<I4s", len(blob), b"BIN\x00")
    out += blob
    struct.pack_into("<I", out, 8, len(out))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(out)


def empty_bucket():
    return {"wall": [], "roof": []}


def add_tri(bucket, material, positions, normals, indices):
    slot = bucket[material]
    base = len(slot) // 2
    # store interleaved later; keep parallel lists on the bucket via attributes
    if not hasattr(add_tri, "_skip"):
        pass
    bucket.setdefault("_pos_" + material, [])
    bucket.setdefault("_nrm_" + material, [])
    bucket.setdefault("_idx_" + material, [])
    remap = {}
    for index in indices:
        if index not in remap:
            remap[index] = len(bucket["_pos_" + material])
            bucket["_pos_" + material].append(positions[index])
            bucket["_nrm_" + material].append(normals[index])
        bucket["_idx_" + material].append(remap[index])


def prims_from_bucket(bucket):
    prims = []
    for material in ("wall", "roof", "water"):
        positions = bucket.get("_pos_" + material)
        if not positions:
            continue
        prims.append({
            "material": material,
            "positions": positions,
            "normals": bucket["_nrm_" + material],
            "indices": bucket["_idx_" + material],
        })
    return prims


def copy_named_meshes(path, names):
    js, buf = read_glb(path)
    wanted = []
    for node in js["nodes"]:
        if node.get("name") in names and node.get("mesh") is not None:
            mesh = js["meshes"][node["mesh"]]
            prims = []
            for prim in mesh["primitives"]:
                pos = read_accessor(js, buf, prim["attributes"]["POSITION"])
                nrm = read_accessor(js, buf, prim["attributes"]["NORMAL"])
                idx = read_accessor(js, buf, prim["indices"])
                indices = [item[0] if isinstance(item, tuple) else item for item in idx]
                if "material" in prim:
                    mat = js["materials"][prim["material"]]["name"]
                else:
                    mat = "collision"
                prims.append({
                    "material": mat,
                    "positions": pos,
                    "normals": nrm,
                    "indices": indices,
                })
            wanted.append({"name": node["name"], "extras": node.get("extras") or {}, "prims": prims})
    materials = js["materials"]
    return wanted, materials


def main():
    buildings, duplicate_ids = load_buildings()
    by_id = {b["id"]: b for b in buildings}
    grid = Grid(buildings)
    js, buf = read_glb(GLB)
    wall_mat = {"name": "wall", "doubleSided": True, "pbrMetallicRoughness": {"baseColorFactor": [1, 0.5, 0.2, 1], "metallicFactor": 0, "roughnessFactor": 0.4}}
    roof_mat = {"name": "roof", "doubleSided": True, "pbrMetallicRoughness": {"baseColorFactor": [0.29, 0.25, 0.21, 1], "metallicFactor": 0, "roughnessFactor": 0.4}}
    water_mat = {"name": "water", "doubleSided": True, "pbrMetallicRoughness": {"baseColorFactor": [0.009, 0.002, 0.8, 1], "metallicFactor": 0, "roughnessFactor": 0.4}}

    owned = defaultdict(lambda: {"wall": 0, "roof": 0, "positions": {"wall": [], "roof": []}, "normals": {"wall": [], "roof": []}, "indices": {"wall": [], "roof": []}, "remap": {"wall": {}, "roof": {}}})
    unresolved = {"positions": defaultdict(list), "normals": defaultdict(list), "indices": defaultdict(list), "remap": defaultdict(dict), "counts": defaultdict(int)}
    reasons = defaultdict(int)
    source_tris = 0

    def take(store, material, positions, normals, vertex_index):
        remap = store["remap"][material]
        if vertex_index not in remap:
            remap[vertex_index] = len(store["positions"][material])
            store["positions"][material].append(positions[vertex_index])
            store["normals"][material].append(normals[vertex_index])
        store["indices"][material].append(remap[vertex_index])

    building_mesh = next(mesh for mesh in js["meshes"] if mesh["name"] == "dhule_city.osm_buildings")
    for prim in building_mesh["primitives"]:
        positions = read_accessor(js, buf, prim["attributes"]["POSITION"])
        normals = read_accessor(js, buf, prim["attributes"]["NORMAL"])
        raw_index = read_accessor(js, buf, prim["indices"])
        material = js["materials"][prim["material"]]["name"]
        for tri in range(0, len(raw_index), 3):
            source_tris += 1
            indices = []
            verts = []
            for k in range(3):
                vertex = raw_index[tri + k]
                vertex = vertex[0] if isinstance(vertex, tuple) else vertex
                indices.append(vertex)
                x, y, z = positions[vertex]
                verts.append((x, z, y))
            per_vertex = [set(grid.hits(v[0], v[1])) for v in verts]
            ids = set()
            for group in per_vertex:
                ids |= group
            cx = sum(v[0] for v in verts) / 3.0
            cz = sum(v[1] for v in verts) / 3.0
            owner = None
            reason = "unmatched"
            if len(ids) > 1:
                reason = "ambiguous_multi_footprint"
            elif len(ids) == 1:
                index = next(iter(ids))
                dmax = 0.0
                for (x, z, _y), group in zip(verts, per_vertex):
                    if not group:
                        dmax = max(dmax, edge_distance(x, z, buildings[index]["poly"]))
                if dmax <= EDGE:
                    owner = buildings[index]["id"]
                    reason = "inside" if dmax == 0 else "boundary"
                else:
                    reason = "crosses_boundary"
            else:
                ranked = grid.nearest(cx, cz)
                if ranked:
                    d0, id0 = ranked[0]
                    d1 = ranked[1][0] if len(ranked) > 1 else 1e9
                    if d0 <= EDGE and d1 - d0 >= MARGIN:
                        owner = id0
                        reason = "nearest_edge"
                    else:
                        reason = "unmatched" if d0 > EDGE else "ambiguous_margin"
            reasons[reason if owner else reason] += 1
            if owner:
                store = owned[owner]
                store[material] += 1
                take(store, material, positions, normals, indices[0])
                take(store, material, positions, normals, indices[1])
                take(store, material, positions, normals, indices[2])
            else:
                unresolved["counts"][reason] += 1
                take(unresolved, material, positions, normals, indices[0])
                take(unresolved, material, positions, normals, indices[1])
                take(unresolved, material, positions, normals, indices[2])

    assigned = sum(item["wall"] + item["roof"] for item in owned.values())
    unresolved_tris = sum(unresolved["counts"].values())
    if assigned + unresolved_tris != source_tris:
        raise SystemExit("triangle mismatch %s + %s != %s" % (assigned, unresolved_tris, source_tris))

    BUILDINGS.mkdir(parents=True, exist_ok=True)
    (BUILDINGS / ".gdignore").write_text("Pipeline archive. Godot loads the grouped exports.\n", encoding="utf-8")
    shared = [wall_mat, roof_mat]
    manifest_rows = []
    exported_ids = []
    for building in buildings:
        item = owned.get(building["id"])
        tris = 0 if item is None else item["wall"] + item["roof"]
        row = {
            "osm_id": building["id"],
            "osm_building": building["building"],
            "osm_name": building["name"],
            "triangles": tris,
            "wall_triangles": 0 if item is None else item["wall"],
            "roof_triangles": 0 if item is None else item["roof"],
            "godot_x": round(building["cx"], 2),
            "godot_z": round(building["cz"], 2),
            "file": None,
            "status": "exported" if tris else "no_confident_triangles",
        }
        if tris:
            prims = []
            for material in ("wall", "roof"):
                if item["indices"][material]:
                    prims.append({
                        "material": material,
                        "positions": item["positions"][material],
                        "normals": item["normals"][material],
                        "indices": item["indices"][material],
                    })
            write_glb(BUILDINGS / (building["id"] + ".glb"), [{
                "name": building["id"],
                "extras": {"osm_id": building["id"]},
                "prims": prims,
            }], shared)
            row["file"] = "buildings/" + building["id"] + ".glb"
            exported_ids.append(building["id"])
        manifest_rows.append(row)

    unresolved_prims = []
    for material in ("wall", "roof"):
        if unresolved["indices"][material]:
            unresolved_prims.append({
                "material": material,
                "positions": unresolved["positions"][material],
                "normals": unresolved["normals"][material],
                "indices": unresolved["indices"][material],
            })
    write_glb(EXPORT / "unresolved_geometry.glb", [{
        "name": "unresolved",
        "extras": {"counts": dict(unresolved["counts"])},
        "prims": unresolved_prims,
    }], shared)

    water_mesh = next(mesh for mesh in js["meshes"] if mesh["name"] == "dhule_city.osm_water")
    water_prims = []
    water_tris = 0
    for prim in water_mesh["primitives"]:
        positions = read_accessor(js, buf, prim["attributes"]["POSITION"])
        normals = read_accessor(js, buf, prim["attributes"]["NORMAL"])
        raw_index = read_accessor(js, buf, prim["indices"])
        indices = [item[0] if isinstance(item, tuple) else item for item in raw_index]
        water_tris += len(indices) // 3
        water_prims.append({"material": "water", "positions": positions, "normals": normals, "indices": indices})
    write_glb(EXPORT / "city_water.glb", [{"name": "city_water", "extras": {}, "prims": water_prims}], [water_mat])

    joined_pos = {"wall": [], "roof": []}
    joined_nrm = {"wall": [], "roof": []}
    joined_idx = {"wall": [], "roof": []}
    by_id_meshes = []
    for building in buildings:
        item = owned.get(building["id"])
        if not item or item["wall"] + item["roof"] == 0:
            continue
        prims = []
        for material in ("wall", "roof"):
            if not item["indices"][material]:
                continue
            base = len(joined_pos[material])
            joined_pos[material].extend(item["positions"][material])
            joined_nrm[material].extend(item["normals"][material])
            joined_idx[material].extend(index + base for index in item["indices"][material])
            prims.append({
                "material": material,
                "positions": item["positions"][material],
                "normals": item["normals"][material],
                "indices": item["indices"][material],
            })
        by_id_meshes.append({"name": building["id"], "extras": {"osm_id": building["id"]}, "prims": prims})
    by_id_meshes.append({"name": "unresolved", "extras": {"osm_id": ""}, "prims": unresolved_prims})
    write_glb(EXPORT / "grouped_by_id.glb", by_id_meshes, shared)
    joined_prims = []
    for material in ("wall", "roof"):
        if joined_idx[material]:
            joined_prims.append({
                "material": material,
                "positions": joined_pos[material],
                "normals": joined_nrm[material],
                "indices": joined_idx[material],
            })
    write_glb(EXPORT / "grouped_joined.glb", [
        {"name": "assigned_joined", "extras": {}, "prims": joined_prims},
        {"name": "unresolved", "extras": {}, "prims": unresolved_prims},
    ], shared)

    court = by_id[COURT]
    neighbour_ids = []
    for building in buildings:
        if math.hypot(building["cx"] - court["cx"], building["cz"] - court["cz"]) <= 160.0:
            neighbour_ids.append(building["id"])
    local_meshes = []
    for building_id in neighbour_ids:
        if building_id in REPLACE:
            continue
        item = owned.get(building_id)
        if not item or item["wall"] + item["roof"] == 0:
            continue
        prims = []
        for material in ("wall", "roof"):
            if item["indices"][material]:
                prims.append({
                    "material": material,
                    "positions": item["positions"][material],
                    "normals": item["normals"][material],
                    "indices": item["indices"][material],
                })
        local_meshes.append({"name": building_id, "extras": {"osm_id": building_id}, "prims": prims})
    detail_names = []
    for building_id in REPLACE:
        detail_names.append("bld_" + building_id)
        detail_names.append("col_" + building_id)
    details, detail_materials = copy_named_meshes(ARCH, set(detail_names))
    # Keep Blosm wall/roof and append only the materials the detailed meshes use.
    mat_names = {mat["name"] for mat in shared}
    materials = list(shared)
    materials.append({"name": "collision", "doubleSided": True, "pbrMetallicRoughness": {"baseColorFactor": [0.4, 0.4, 0.4, 1], "metallicFactor": 0, "roughnessFactor": 0.8}})
    for mat in detail_materials:
        if mat["name"] not in mat_names:
            materials.append(mat)
            mat_names.add(mat["name"])
    local_meshes.extend(details)
    write_glb(EXPORT / "neighbourhood_replaced.glb", local_meshes, materials)

    export_manifest = {
        "source_glb": "assets/models/environments/dhule_blosm_city.glb",
        "source_sha256": hashlib.sha256(GLB.read_bytes()).hexdigest(),
        "projection": {"lat": LAT0, "lon": LON0, "x": "east", "y": "up", "z": "south"},
        "source_building_triangles": source_tris,
        "assigned_triangles": assigned,
        "unresolved_triangles": unresolved_tris,
        "unresolved_reasons": dict(unresolved["counts"]),
        "reason_counts": dict(reasons),
        "water_triangles": water_tris,
        "triangle_sum_matches_source": assigned + unresolved_tris == source_tris,
        "footprints": len(buildings),
        "duplicate_osm_ids_in_source": duplicate_ids,
        "exported_building_ids": len(exported_ids),
        "duplicate_exported_ids": len(exported_ids) - len(set(exported_ids)),
        "footprints_without_confident_triangles": sum(1 for row in manifest_rows if row["triangles"] == 0),
        "split_policy": "Boundary-crossing triangles are kept whole in unresolved_geometry.glb. They are not cut.",
        "assignment": "All vertices inside one way, or within 0.20 m of that way and 0.50 m farther from every other way. Way id is the only key.",
        "neighbour_of_1337953905": {
            "osm_id": "1337953919",
            "godot_bounds": {
                "min_x": round(by_id["1337953919"]["minx"], 2),
                "max_x": round(by_id["1337953919"]["maxx"], 2),
                "min_z": round(by_id["1337953919"]["minz"], 2),
                "max_z": round(by_id["1337953919"]["maxz"], 2),
            },
            "target_bounds": {
                "min_x": round(by_id["1337953905"]["minx"], 2),
                "max_x": round(by_id["1337953905"]["maxx"], 2),
            },
            "gap_m": round(by_id["1337953919"]["minx"] - by_id["1337953905"]["maxx"], 2),
            "note": "The east approach hits 1337953919 before 1337953905. The gap between their footprints is under 2 m. Spawning inside 1337953919 throws the vehicle.",
        },
        "runtime_note": "buildings/<id>.glb is the archive. grouped_joined.glb is one mesh. grouped_by_id.glb keeps one node per way id. The preview uses neighbourhood_replaced.glb.",
    }
    text = json.dumps(export_manifest, indent=2)
    (EXPORT / "export_manifest.json").write_text(text, encoding="utf-8")
    (OUT / "manifests").mkdir(parents=True, exist_ok=True)
    (OUT / "manifests" / "export_manifest.json").write_text(text, encoding="utf-8")
    building_text = json.dumps(manifest_rows, indent=2)
    (EXPORT / "building_manifest.json").write_text(building_text, encoding="utf-8")
    (OUT / "manifests" / "building_manifest.json").write_text(building_text, encoding="utf-8")
    (OUT / "validation").mkdir(parents=True, exist_ok=True)
    (OUT / "source").mkdir(parents=True, exist_ok=True)
    (OUT / "source" / "inputs.json").write_text(json.dumps({
        "blosm": str(GLB),
        "osm": str(OSM),
        "roads_not_modified": "assets/maps/dhule_roads_game.json",
        "sha256": export_manifest["source_sha256"],
    }, indent=2), encoding="utf-8")
    print("PARTITION", "assigned", assigned, "unresolved", unresolved_tris, "files", len(exported_ids), "empty", export_manifest["footprints_without_confident_triangles"])
    print("REASONS", dict(reasons))
    for building_id in list(REPLACE) + ["1337953919"]:
        row = next(item for item in manifest_rows if item["osm_id"] == building_id)
        print("ID", building_id, row["triangles"], row["status"])


if __name__ == "__main__":
    main()
