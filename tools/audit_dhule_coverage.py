"""Read-only Dhule coverage audit. Writes docs/qa/30-* and prints a summary.

Does not edit OSM, the road JSON, scenes, or the vehicle.
"""
from __future__ import annotations

import csv
import json
import math
import struct
import xml.etree.ElementTree as ET
import zlib
from collections import defaultdict
from pathlib import Path

ROOT = Path(r"D:\drivevicecity")
OUT = ROOT / "docs" / "qa"
ORIGIN_LAT = 20.902
ORIGIN_LON = 74.777
M_LAT = 111320.0
M_LON = 111320.0 * math.cos(math.radians(ORIGIN_LAT))
GODOT_LAT = 6371000.0 * math.pi / 180.0
GODOT_LON = GODOT_LAT * math.cos(math.radians(ORIGIN_LAT))
CELL = 250.0
SPAWN = (-13.09, -86.21)
MISSING_ROADS = (880887781, 887725190, 1426345742)
UNMATCHED = (
    1485903708,
    1527760215,
    1527760232,
    1527760270,
    1527760283,
    1527816133,
    1527858168,
    1527858172,
    1527858312,
)
RESIDENTIAL = {"house", "residential", "apartments", "detached", "semidetached_house", "terrace", "bungalow"}
COMMERCIAL = {"commercial", "retail", "supermarket", "office", "kiosk", "industrial", "warehouse", "hotel"}
DRIVE = {"motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential", "living_street", "service", "trunk_link", "primary_link", "secondary_link", "tertiary_link"}


def to_xz(lat: float, lon: float) -> tuple[float, float]:
    return ((lon - ORIGIN_LON) * M_LON, -(lat - ORIGIN_LAT) * M_LAT)


def godot_xz(lat: float, lon: float) -> tuple[float, float]:
    return ((lon - ORIGIN_LON) * GODOT_LON, -(lat - ORIGIN_LAT) * GODOT_LAT)


def dist_point_seg(px, pz, ax, az, bx, bz) -> float:
    dx, dz = bx - ax, bz - az
    len2 = dx * dx + dz * dz
    if len2 < 1e-8:
        return math.hypot(px - ax, pz - az)
    t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / len2))
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))


def seg_seg_dist(ax, az, bx, bz, cx, cz, dx, dz) -> float:
    # Sample the shorter edge. Building edges are short; this stays within ~0.5 m.
    ab = math.hypot(bx - ax, bz - az)
    cd = math.hypot(dx - cx, dz - cz)
    if ab >= cd:
        n = max(1, int(ab / 2.0))
        best = 1e18
        for i in range(n + 1):
            t = i / n
            best = min(best, dist_point_seg(ax + (bx - ax) * t, az + (bz - az) * t, cx, cz, dx, dz))
        return best
    n = max(1, int(cd / 2.0))
    best = 1e18
    for i in range(n + 1):
        t = i / n
        best = min(best, dist_point_seg(cx + (dx - cx) * t, cz + (dz - cz) * t, ax, az, bx, bz))
    return best


def segments_cross(ax, az, bx, bz, cx, cz, dx, dz) -> bool:
    def cross(x1, z1, x2, z2, x3, z3) -> float:
        return (x2 - x1) * (z3 - z1) - (z2 - z1) * (x3 - x1)

    d1 = cross(ax, az, bx, bz, cx, cz)
    d2 = cross(ax, az, bx, bz, dx, dz)
    d3 = cross(cx, cz, dx, dz, ax, az)
    d4 = cross(cx, cz, dx, dz, bx, bz)
    return d1 * d2 < 0 and d3 * d4 < 0


def point_in_poly(x: float, z: float, poly: list[tuple[float, float]]) -> bool:
    inside = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, zi = poly[i]
        xj, zj = poly[j]
        if ((zi > z) != (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi + 1e-18) + xi):
            inside = not inside
        j = i
    return inside


def ring_area(poly: list[tuple[float, float]]) -> float:
    a = 0.0
    for i in range(len(poly) - 1):
        a += poly[i][0] * poly[i + 1][1] - poly[i + 1][0] * poly[i][1]
    return abs(a) * 0.5


def cell_of(x: float, z: float) -> tuple[int, int]:
    return (math.floor(x / CELL), math.floor(z / CELL))


class Union:
    def __init__(self) -> None:
        self.p: dict[tuple[int, int], tuple[int, int]] = {}

    def find(self, a: tuple[int, int]) -> tuple[int, int]:
        self.p.setdefault(a, a)
        while self.p[a] != a:
            self.p[a] = self.p[self.p[a]]
            a = self.p[a]
        return a

    def union(self, a: tuple[int, int], b: tuple[int, int]) -> None:
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.p[rb] = ra


def snap(x: float, z: float, metres: float) -> tuple[int, int]:
    return (round(x / metres), round(z / metres))


def load_osm_buildings() -> list[dict]:
    tree = ET.parse(ROOT / "assets" / "maps" / "dhule_city.osm")
    root = tree.getroot()
    nodes = {}
    for node in root.findall("node"):
        nodes[node.get("id")] = (float(node.get("lat")), float(node.get("lon")))
    buildings = []
    for way in root.findall("way"):
        tags = {t.get("k"): t.get("v") for t in way.findall("tag")}
        if "building" not in tags:
            continue
        refs = [nd.get("ref") for nd in way.findall("nd")]
        ll = [nodes[r] for r in refs if r in nodes]
        if len(ll) < 4:
            continue
        poly = [to_xz(lat, lon) for lat, lon in ll]
        if poly[0] != poly[-1]:
            poly.append(poly[0])
        cx = sum(p[0] for p in poly[:-1]) / (len(poly) - 1)
        cz = sum(p[1] for p in poly[:-1]) / (len(poly) - 1)
        buildings.append({
            "id": int(way.get("id")),
            "kind": tags.get("building", "yes"),
            "name": tags.get("name", ""),
            "levels": tags.get("building:levels", ""),
            "height": tags.get("height", ""),
            "poly": poly,
            "x": cx,
            "z": cz,
            "area": ring_area(poly),
        })
    return buildings


def load_geo_roads() -> dict[int, dict]:
    data = json.loads((ROOT / "data" / "dhule" / "roads.geojson").read_text(encoding="utf-8"))
    out = {}
    for feat in data["features"]:
        osm_id = int(str(feat.get("id", "")).split("/")[-1])
        props = feat.get("properties") or {}
        tags = props.get("tags") or props
        coords = feat["geometry"]["coordinates"]
        pts = [to_xz(lat, lon) for lon, lat in coords]
        out[osm_id] = {
            "id": osm_id,
            "highway": tags.get("highway", ""),
            "name": tags.get("name", ""),
            "bridge": tags.get("bridge", ""),
            "layer": tags.get("layer", ""),
            "pts": pts,
        }
    return out


def load_places() -> list[dict]:
    places = []
    path = ROOT / "data" / "dhule" / "places.geojson"
    data = json.loads(path.read_text(encoding="utf-8"))
    for feat in data["features"]:
        props = feat.get("properties") or {}
        tags = props.get("tags") or props
        lon, lat = feat["geometry"]["coordinates"][:2]
        x, z = to_xz(lat, lon)
        places.append({
            "id": props.get("osm_id") or str(feat.get("id", "")),
            "name": tags.get("name", ""),
            "place": tags.get("place", tags.get("amenity", "")),
            "x": x,
            "z": z,
        })
    return places


def glb_building_vertices() -> list[tuple[float, float, float]]:
    data = (ROOT / "assets" / "models" / "environments" / "dhule_blosm_city.glb").read_bytes()
    off = 12
    length, ctype = struct.unpack_from("<II", data, off)
    gltf = json.loads(data[off + 8:off + 8 + length])
    off = off + 8 + length
    blen, btype = struct.unpack_from("<II", data, off)
    blob = data[off + 8:off + 8 + blen]
    verts: list[tuple[float, float, float]] = []
    for mesh in gltf.get("meshes", []):
        name = mesh.get("name", "")
        if "building" not in name:
            continue
        for prim in mesh.get("primitives", []):
            acc = gltf["accessors"][prim["attributes"]["POSITION"]]
            view = gltf["bufferViews"][acc["bufferView"]]
            start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
            count = acc["count"]
            stride = view.get("byteStride", 12)
            for i in range(count):
                x, y, z = struct.unpack_from("<fff", blob, start + i * stride)
                verts.append((x, y, z))
    return verts


def nearest_road(x: float, z: float, segs, index, reach: float = 80.0):
    best = None
    ix, iz = int(math.floor(x / 50)), int(math.floor(z / 50))
    span = int(math.ceil(reach / 50)) + 1
    for gx in range(ix - span, ix + span + 1):
        for gz in range(iz - span, iz + span + 1):
            for seg in index.get((gx, gz), ()):
                d = dist_point_seg(x, z, seg["ax"], seg["az"], seg["bx"], seg["bz"])
                if best is None or d < best[0]:
                    best = (d, seg)
    return best


def poly_centerline_dist(poly, segs) -> tuple[float, dict | None, bool]:
    xs = [p[0] for p in poly]
    zs = [p[1] for p in poly]
    minx, maxx, minz, maxz = min(xs), max(xs), min(zs), max(zs)
    # Start from the centroid's nearest segment so a far road is not reported as missing.
    cx = sum(xs[:-1]) / max(1, len(xs) - 1)
    cz = sum(zs[:-1]) / max(1, len(zs) - 1)
    hint = nearest_road(cx, cz, segs, ROAD_INDEX, 2000.0)
    radius = max(math.hypot(x - cx, z - cz) for x, z in poly)
    if hint is None:
        return 9999.0, None, False
    # The wall cannot be closer than centroid distance minus the footprint radius.
    if hint[0] - radius > 80.0:
        return hint[0] - radius, hint[1], False
    reach = max(40.0, min(hint[0] + radius + 25.0, 160.0))
    best = 1e18
    best_seg = None
    crossed = False
    ix0, ix1 = int(math.floor((minx - reach) / 50)), int(math.floor((maxx + reach) / 50))
    iz0, iz1 = int(math.floor((minz - reach) / 50)), int(math.floor((maxz + reach) / 50))
    seen = set()
    for gx in range(ix0, ix1 + 1):
        for gz in range(iz0, iz1 + 1):
            for seg in ROAD_INDEX.get((gx, gz), ()):
                key = (seg["id"], seg["i"])
                if key in seen:
                    continue
                seen.add(key)
                if segments_cross(seg["ax"], seg["az"], seg["bx"], seg["bz"], poly[0][0], poly[0][1], poly[1][0], poly[1][1]):
                    pass
                hit = False
                for i in range(len(poly) - 1):
                    if segments_cross(seg["ax"], seg["az"], seg["bx"], seg["bz"], poly[i][0], poly[i][1], poly[i + 1][0], poly[i + 1][1]):
                        hit = True
                        break
                if hit or point_in_poly(seg["ax"], seg["az"], poly) or point_in_poly(seg["bx"], seg["bz"], poly):
                    crossed = True
                    return 0.0, seg, True
                d = 1e18
                for i in range(len(poly) - 1):
                    d = min(d, seg_seg_dist(seg["ax"], seg["az"], seg["bx"], seg["bz"], poly[i][0], poly[i][1], poly[i + 1][0], poly[i + 1][1]))
                if d < best:
                    best = d
                    best_seg = seg
    return best, best_seg, crossed


ROAD_INDEX: dict[tuple[int, int], list] = defaultdict(list)


def write_png(path: Path, pixels: bytearray, w: int, h: int) -> None:
    def chunk(tag: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    raw = bytearray()
    stride = w * 3
    for y in range(h):
        raw.append(0)
        raw.extend(pixels[y * stride:(y + 1) * stride])
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    game = json.loads((ROOT / "assets" / "maps" / "dhule_roads_game.json").read_text(encoding="utf-8"))
    buildings = load_osm_buildings()
    geo_roads = load_geo_roads()
    places = load_places()
    shops = json.loads((ROOT / "data" / "dhule" / "city_shops.json").read_text(encoding="utf-8"))["shops"]

    # Playable segments.
    segs = []
    id_counts = defaultdict(int)
    uf = Union()
    degree = defaultdict(int)
    road_comp = {}
    for road in game["roads"]:
        rid = int(road["id"])
        id_counts[rid] += 1
        pts = road["points"]
        half = float(road.get("width", 7.0)) * 0.5
        for i in range(len(pts) - 1):
            ax, az = float(pts[i][0]), float(pts[i][1])
            bx, bz = float(pts[i + 1][0]), float(pts[i + 1][1])
            if math.hypot(bx - ax, bz - az) < 0.2:
                continue
            seg = {
                "id": rid,
                "i": i,
                "ax": ax,
                "az": az,
                "bx": bx,
                "bz": bz,
                "half": half,
                "highway": road.get("highway", ""),
                "name": road.get("name", ""),
            }
            segs.append(seg)
            a = snap(ax, az, 3.0)
            b = snap(bx, bz, 3.0)
            uf.union(a, b)
            degree[a] += 1
            degree[b] += 1
            mx, mz = (ax + bx) * 0.5, (az + bz) * 0.5
            ROAD_INDEX[(int(math.floor(mx / 50)), int(math.floor(mz / 50)))].append(seg)
    for seg in segs:
        seg["comp"] = uf.find(snap(seg["ax"], seg["az"], 3.0))
    comp_len = defaultdict(float)
    for seg in segs:
        comp_len[seg["comp"]] += math.hypot(seg["bx"] - seg["ax"], seg["bz"] - seg["az"])
    main_comp = max(comp_len, key=comp_len.get)
    junctions = {node for node, deg in degree.items() if deg >= 3}

    # Second snap sensitivity.
    uf1, uf8 = Union(), Union()
    for seg in segs:
        uf1.union(snap(seg["ax"], seg["az"], 1.0), snap(seg["bx"], seg["bz"], 1.0))
        uf8.union(snap(seg["ax"], seg["az"], 8.0), snap(seg["bx"], seg["bz"], 8.0))
    comps1 = {uf1.find(snap(s["ax"], s["az"], 1.0)) for s in segs}
    comps8 = {uf8.find(snap(s["ax"], s["az"], 8.0)) for s in segs}

    # Building vs road.
    bindex = defaultdict(list)
    for bi, b in enumerate(buildings):
        bindex[cell_of(b["x"], b["z"])].append(bi)
    rows = []
    bands = defaultdict(int)
    centerline_hits = []
    for b in buildings:
        dist_cl, seg, crossed = poly_centerline_dist(b["poly"], segs)
        half = seg["half"] if seg else 0.0
        edge = dist_cl - half if seg else 9999.0
        if crossed:
            kind = "centerline_inside"
        elif edge < -0.25:
            kind = "carriageway_overlap"
        elif edge < 1:
            kind = "within_1m"
        elif edge < 2:
            kind = "within_2m"
        elif edge < 5:
            kind = "within_5m"
        elif edge < 15:
            kind = "frontage"
        elif edge < 40:
            kind = "nearby_access"
        else:
            kind = "no_road_access"
        bands[kind] += 1
        b["edge"] = edge
        b["dist_cl"] = dist_cl
        b["road_id"] = seg["id"] if seg else ""
        b["road_hw"] = seg["highway"] if seg else ""
        b["relation"] = kind
        b["comp"] = seg["comp"] if seg else None
        if crossed:
            centerline_hits.append(b["id"])
        rows.append(b)

    dup_ids = [i for i, n in id_counts.items() if n > 1]
    # Near-duplicate ways: same rounded endpoint pair and similar length.
    geom_key = defaultdict(list)
    for road in game["roads"]:
        pts = road["points"]
        if len(pts) < 2:
            continue
        a = (round(pts[0][0], 0), round(pts[0][1], 0))
        b = (round(pts[-1][0], 0), round(pts[-1][1], 0))
        key = tuple(sorted((a, b)))
        geom_key[key].append(int(road["id"]))
    geom_dups = {str(k): v for k, v in geom_key.items() if len(set(v)) > 1}

    bcount = defaultdict(int)
    for b in buildings:
        bcount[b["id"]] += 1
    dup_buildings = [i for i, n in bcount.items() if n > 1]

    # Grid.
    cells: dict[tuple[int, int], dict] = {}

    def cell(ix, iz) -> dict:
        key = (ix, iz)
        if key not in cells:
            cells[key] = {
                "ix": ix,
                "iz": iz,
                "x0": ix * CELL,
                "z0": iz * CELL,
                "buildings": 0,
                "residential_tags": 0,
                "commercial_tags": 0,
                "unknown_tags": 0,
                "named_buildings": 0,
                "road_segments": 0,
                "road_ids": set(),
                "junctions": 0,
                "main_component_segments": 0,
                "shops": 0,
                "named_places": 0,
                "place_names": [],
                "min_edge_m": None,
                "median_hint_edges": [],
            }
        return cells[key]

    for seg in segs:
        mx, mz = (seg["ax"] + seg["bx"]) * 0.5, (seg["az"] + seg["bz"]) * 0.5
        c = cell(*cell_of(mx, mz))
        c["road_segments"] += 1
        c["road_ids"].add(seg["id"])
        if seg["comp"] == main_comp:
            c["main_component_segments"] += 1
    for node in junctions:
        x, z = node[0] * 3.0, node[1] * 3.0
        cell(*cell_of(x, z))["junctions"] += 1
    for b in buildings:
        c = cell(*cell_of(b["x"], b["z"]))
        c["buildings"] += 1
        c["median_hint_edges"].append(b["edge"])
        if b["kind"] in RESIDENTIAL:
            c["residential_tags"] += 1
        elif b["kind"] in COMMERCIAL:
            c["commercial_tags"] += 1
        else:
            c["unknown_tags"] += 1
        if b["name"]:
            c["named_buildings"] += 1
    for shop in shops:
        c = cell(*cell_of(shop["x"], shop["z"]))
        c["shops"] += 1
        c["place_names"].append(shop.get("name") or shop.get("kind"))
    for place in places:
        if not place["name"]:
            continue
        c = cell(*cell_of(place["x"], place["z"]))
        c["named_places"] += 1
        c["place_names"].append(place["name"])

    grid_out = []
    for c in cells.values():
        edges = sorted(e for e in c["median_hint_edges"] if e < 9000)
        c["min_edge_m"] = round(edges[0], 2) if edges else None
        c["median_edge_m"] = round(edges[len(edges) // 2], 2) if edges else None
        reachable = c["main_component_segments"] > 0
        if c["buildings"] == 0 and c["road_segments"] > 0:
            klass = "roads_no_buildings"
        elif c["buildings"] > 0 and c["road_segments"] == 0 and (c["min_edge_m"] is None or c["min_edge_m"] > 40):
            klass = "buildings_no_playable_road"
        elif c["shops"] > 0 and c["buildings"] > 0 and c["road_segments"] > 0:
            klass = "mixed_shop_street"
        elif c["commercial_tags"] > 0 and c["residential_tags"] > 0:
            klass = "mixed_tagged"
        elif c["buildings"] >= 8 and c["road_segments"] > 0:
            klass = "dense_footprints"
        elif c["buildings"] > 0 and c["road_segments"] > 0:
            klass = "sparse_street"
        elif c["buildings"] > 0:
            klass = "buildings_near_edge"
        else:
            klass = "empty"
        record = {
            "ix": c["ix"],
            "iz": c["iz"],
            "x0": c["x0"],
            "z0": c["z0"],
            "x1": c["x0"] + CELL,
            "z1": c["z0"] + CELL,
            "buildings": c["buildings"],
            "residential_tags": c["residential_tags"],
            "commercial_tags": c["commercial_tags"],
            "unknown_building_tags": c["unknown_tags"],
            "named_buildings": c["named_buildings"],
            "road_segments": c["road_segments"],
            "distinct_roads": len(c["road_ids"]),
            "junctions": c["junctions"],
            "segments_on_main_component": c["main_component_segments"],
            "reachable_from_main_network": reachable,
            "shops": c["shops"],
            "named_places": c["named_places"],
            "names": c["place_names"][:12],
            "min_building_to_road_edge_m": c["min_edge_m"],
            "median_building_to_road_edge_m": c["median_edge_m"],
            "class": klass,
        }
        grid_out.append(record)
    grid_out.sort(key=lambda r: (-r["buildings"], -r["road_segments"]))

    # Spawn candidates on the main network.
    poly_index = defaultdict(list)
    for b in buildings:
        poly_index[cell_of(b["x"], b["z"])].append(b)

    def polys_near(x, z, metres=60.0):
        ix, iz = cell_of(x, z)
        span = int(math.ceil(metres / CELL)) + 1
        found = []
        for gx in range(ix - span, ix + span + 1):
            for gz in range(iz - span, iz + span + 1):
                found.extend(poly_index.get((gx, gz), ()))
        return found

    def inside_any(x, z, metres=0.0) -> bool:
        for b in polys_near(x, z, 80):
            if math.hypot(b["x"] - x, b["z"] - z) > 80:
                continue
            if point_in_poly(x, z, b["poly"]):
                return True
        return False

    def count_within(x, z, radius) -> int:
        n = 0
        for b in polys_near(x, z, radius):
            if math.hypot(b["x"] - x, b["z"] - z) <= radius:
                n += 1
        return n

    def both_sides(ax, az, bx, bz, x, z) -> tuple[int, int]:
        dx, dz = bx - ax, bz - az
        left = right = 0
        for b in polys_near(x, z, 70):
            lat = (b["x"] - x) * dz - (b["z"] - z) * dx
            along = (b["x"] - x) * dx + (b["z"] - z) * dz
            norm = math.hypot(dx, dz) or 1.0
            lateral = abs(lat) / norm
            along_m = abs(along) / norm
            if lateral < 8 or lateral > 45 or along_m > 70:
                continue
            if lat > 0:
                left += 1
            else:
                right += 1
        return left, right

    candidates = []
    for road in game["roads"]:
        hw = road.get("highway", "")
        if hw not in DRIVE or "link" in hw:
            continue
        pts = road["points"]
        acc = 0.0
        next_at = 20.0
        for i in range(len(pts) - 1):
            ax, az = float(pts[i][0]), float(pts[i][1])
            bx, bz = float(pts[i + 1][0]), float(pts[i + 1][1])
            seglen = math.hypot(bx - ax, bz - az)
            if seglen < 0.5:
                continue
            if uf.find(snap(ax, az, 3.0)) != main_comp:
                acc += seglen
                continue
            while acc + seglen >= next_at:
                t = (next_at - acc) / seglen
                x = ax + (bx - ax) * t
                z = az + (bz - az) * t
                next_at += 40.0
                if inside_any(x, z):
                    continue
                left, right = both_sides(ax, az, bx, bz, x, z)
                b100 = count_within(x, z, 100)
                if b100 < 6 or min(left, right) < 1:
                    continue
                b250 = count_within(x, z, 250)
                b500 = count_within(x, z, 500)
                jn = sum(1 for node in junctions if math.hypot(node[0] * 3 - x, node[1] * 3 - z) < 80)
                shop_n = sum(1 for s in shops if math.hypot(s["x"] - x, s["z"] - z) < 500)
                name_n = [p["name"] for p in places if p["name"] and math.hypot(p["x"] - x, p["z"] - z) < 500]
                named_b = [b["name"] for b in polys_near(x, z, 500) if b["name"] and math.hypot(b["x"] - x, b["z"] - z) < 500]
                overlap = sum(1 for b in polys_near(x, z, 50) if b["edge"] < -0.25 and math.hypot(b["x"] - x, b["z"] - z) < 50)
                score = b100 * 3 + min(left, right) * 8 + jn * 5 + shop_n * 12 + b250 * 0.15 - overlap * 15
                hlen = math.hypot(bx - ax, bz - az) or 1
                candidates.append({
                    "x": round(x, 2),
                    "z": round(z, 2),
                    "hx": round((bx - ax) / hlen, 4),
                    "hz": round((bz - az) / hlen, 4),
                    "road_id": int(road["id"]),
                    "highway": hw,
                    "road_name": road.get("name", ""),
                    "buildings_100m": b100,
                    "buildings_250m": b250,
                    "buildings_500m": b500,
                    "buildings_left": left,
                    "buildings_right": right,
                    "junctions_80m": jn,
                    "shops_500m": shop_n,
                    "named_places_500m": name_n[:8],
                    "named_buildings_500m": named_b[:8],
                    "overlaps_within_50m": overlap,
                    "score": round(score, 2),
                })
            acc += seglen
    candidates.sort(key=lambda c: c["score"], reverse=True)
    # Keep spatially distinct top options.
    picked = []
    for cand in candidates:
        if all(math.hypot(cand["x"] - p["x"], cand["z"] - p["z"]) > 180 for p in picked):
            picked.append(cand)
        if len(picked) == 5:
            break
    recommended = next(
        (c for c in picked if c["junctions_80m"] >= 2 and c["overlaps_within_50m"] == 0 and min(c["buildings_left"], c["buildings_right"]) >= 4),
        picked[0] if picked else None,
    )

    def describe_point(x, z) -> dict:
        hit = nearest_road(x, z, segs, ROAD_INDEX, 200)
        return {
            "x": x,
            "z": z,
            "inside_building": inside_any(x, z),
            "nearest_road_id": hit[1]["id"] if hit else None,
            "nearest_highway": hit[1]["highway"] if hit else None,
            "distance_to_centreline_m": round(hit[0], 2) if hit else None,
            "on_main_component": bool(hit and hit[1]["comp"] == main_comp),
            "buildings_100m": count_within(x, z, 100),
            "buildings_250m": count_within(x, z, 250),
            "buildings_500m": count_within(x, z, 500),
            "shops_500m": [s for s in shops if math.hypot(s["x"] - x, s["z"] - z) < 500],
            "named_places_500m": [p["name"] for p in places if p["name"] and math.hypot(p["x"] - x, p["z"] - z) < 500][:12],
            "named_buildings_500m": [b["name"] for b in buildings if b["name"] and math.hypot(b["x"] - x, b["z"] - z) < 500][:12],
        }

    current = describe_point(*SPAWN)

    # Missing roads and unmatched buildings.
    game_ids = {int(r["id"]) for r in game["roads"]}
    missing_info = []
    for rid in MISSING_ROADS:
        src = geo_roads.get(rid)
        if not src:
            missing_info.append({"id": rid, "in_canonical_geojson": False})
            continue
        pts = src["pts"]
        length = sum(math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]) for i in range(len(pts) - 1))
        ends = []
        for px, pz in (pts[0], pts[-1]):
            hit = nearest_road(px, pz, segs, ROAD_INDEX, 150)
            ends.append({
                "x": round(px, 2),
                "z": round(pz, 2),
                "nearest_playable_road": hit[1]["id"] if hit else None,
                "distance_m": round(hit[0], 2) if hit else None,
            })
        missing_info.append({
            "id": rid,
            "in_canonical_geojson": True,
            "in_game_json": rid in game_ids,
            "highway": src["highway"],
            "name": src["name"],
            "bridge": src["bridge"],
            "layer": src["layer"],
            "points": len(pts),
            "length_m": round(length, 2),
            "ends": ends,
        })
    canonical_not_in_game = sorted(set(geo_roads) - game_ids)
    game_not_in_canonical = sorted(game_ids - set(geo_roads))

    # Projection check against a shared road.
    shared = sorted(game_ids & set(geo_roads))
    proj_samples = []
    game_by_id = {int(r["id"]): r for r in game["roads"]}
    for rid in shared[:8]:
        gpts = game_by_id[rid]["points"]
        epts = geo_roads[rid]["pts"]
        d0 = math.hypot(gpts[0][0] - epts[0][0], gpts[0][1] - epts[0][1])
        proj_samples.append({"id": rid, "first_point_delta_m": round(d0, 3), "game_points": len(gpts), "geojson_points": len(epts)})

    # Godot sphere vs 111320 at a district corner.
    corner_lat = ORIGIN_LAT + 0.04
    corner_lon = ORIGIN_LON + 0.04
    a = to_xz(corner_lat, corner_lon)
    g = godot_xz(corner_lat, corner_lon)
    scale_note = {
        "tool_metres_per_deg_lat": M_LAT,
        "tool_metres_per_deg_lon": round(M_LON, 3),
        "godot_latlon_to_xz_lat": round(GODOT_LAT, 3),
        "godot_latlon_to_xz_lon": round(GODOT_LON, 3),
        "delta_at_0_04_deg_m": [round(a[0] - g[0], 2), round(a[1] - g[1], 2)],
        "shared_road_samples": proj_samples,
        "game_clip_radius_m": game.get("clip_radius_m"),
        "game_bbox_m": game.get("bbox_m"),
        "game_origin": [game.get("origin_lat"), game.get("origin_lon")],
    }

    unmatched = []
    by_id = {b["id"]: b for b in buildings}
    verts = []
    try:
        verts = glb_building_vertices()
    except Exception as exc:  # noqa: BLE001
        unmatched.append({"error": str(exc)})
        verts = []
    xs = [v[0] for v in verts] or [0]
    ys = [v[1] for v in verts] or [0]
    zs = [v[2] for v in verts] or [0]
    mesh_bounds = {
        "vertices": len(verts),
        "x": [round(min(xs), 2), round(max(xs), 2)],
        "y": [round(min(ys), 2), round(max(ys), 2)],
        "z": [round(min(zs), 2), round(max(zs), 2)],
    }
    bxs = [b["x"] for b in buildings]
    bzs = [b["z"] for b in buildings]
    osm_bounds = {
        "footprints": len(buildings),
        "x": [round(min(bxs), 2), round(max(bxs), 2)],
        "z": [round(min(bzs), 2), round(max(bzs), 2)],
    }
    for uid in UNMATCHED:
        b = by_id.get(uid)
        if not b:
            unmatched.append({"id": uid, "in_city_osm": False})
            continue
        inside = 0
        nearest = 1e18
        # Bound the vertex test to the footprint neighbourhood.
        minx = min(p[0] for p in b["poly"]) - 20
        maxx = max(p[0] for p in b["poly"]) + 20
        minz = min(p[1] for p in b["poly"]) - 20
        maxz = max(p[1] for p in b["poly"]) + 20
        for x, y, z in verts:
            if x < minx or x > maxx or z < minz or z > maxz:
                continue
            d = math.hypot(x - b["x"], z - b["z"])
            if d < nearest:
                nearest = d
            if point_in_poly(x, z, b["poly"]):
                inside += 1
                if inside > 3:
                    break
        unmatched.append({
            "id": uid,
            "in_city_osm": True,
            "kind": b["kind"],
            "name": b["name"],
            "area_m2": round(b["area"], 2),
            "x": round(b["x"], 2),
            "z": round(b["z"], 2),
            "relation": b["relation"],
            "dist_to_road_edge_m": round(b["edge"], 2),
            "nearest_road_id": b["road_id"],
            "mesh_vertices_inside": inside,
            "nearest_tested_vertex_m": None if nearest > 1e17 else round(nearest, 2),
        })

    # CSV
    csv_path = OUT / "30-building-road-validation.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=[
            "osm_id", "kind", "name", "x", "z", "area_m2", "nearest_road_id", "nearest_highway",
            "dist_to_centreline_m", "dist_to_road_edge_m", "relation", "on_main_network",
        ])
        writer.writeheader()
        for b in buildings:
            writer.writerow({
                "osm_id": b["id"],
                "kind": b["kind"],
                "name": b["name"],
                "x": round(b["x"], 2),
                "z": round(b["z"], 2),
                "area_m2": round(b["area"], 2),
                "nearest_road_id": b["road_id"],
                "nearest_highway": b["road_hw"],
                "dist_to_centreline_m": round(b["dist_cl"], 2),
                "dist_to_road_edge_m": round(b["edge"], 2),
                "relation": b["relation"],
                "on_main_network": b["comp"] == main_comp,
            })

    (OUT / "30-grid-coverage.json").write_text(json.dumps({
        "cell_m": CELL,
        "origin": {"lat": ORIGIN_LAT, "lon": ORIGIN_LON, "x": "east", "y": "up", "z": "south"},
        "attribution": "© OpenStreetMap contributors",
        "cells": grid_out,
    }, ensure_ascii=False, indent=2), encoding="utf-8")

    class_counts = defaultdict(int)
    for rec in grid_out:
        class_counts[rec["class"]] += 1

    summary = {
        "scale_note": scale_note,
        "roads_game": len(game["roads"]),
        "segments": len(segs),
        "components_snap_1m": len(comps1),
        "components_snap_3m": len(comp_len),
        "components_snap_8m": len(comps8),
        "main_component_length_m": round(comp_len[main_comp], 1),
        "component_lengths_m": sorted((round(v, 1) for v in comp_len.values()), reverse=True)[:12],
        "orphan_components": [
            {"length_m": round(comp_len[comp], 1), "road_ids": sorted({s["id"] for s in segs if s["comp"] == comp})}
            for comp in comp_len if comp != main_comp
        ],
        "duplicate_road_ids": dup_ids,
        "endpoint_duplicate_groups": len(geom_dups),
        "duplicate_building_ids": dup_buildings,
        "bands": dict(bands),
        "centerline_inside_ids": centerline_hits,
        "class_counts": dict(class_counts),
        "canonical_roads": len(geo_roads),
        "canonical_not_in_game": len(canonical_not_in_game),
        "game_not_in_canonical": len(game_not_in_canonical),
        "missing_roads": missing_info,
        "unmatched": unmatched,
        "mesh_bounds": mesh_bounds,
        "osm_bounds": osm_bounds,
        "current_spawn": current,
        "candidates": picked,
        "recommended": recommended,
        "candidate_pool": len(candidates),
        "shops": shops,
        "named_building_count": sum(1 for b in buildings if b["name"]),
        "tag_counts": dict(defaultdict(int, {b["kind"]: 0 for b in buildings})),
    }
    tags = defaultdict(int)
    for b in buildings:
        tags[b["kind"]] += 1
    summary["tag_counts"] = dict(sorted(tags.items(), key=lambda kv: -kv[1]))
    (OUT / "30-coverage-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")

    # Map. North is up (negative Z).
    pad = 80
    rxs = [float(p[0]) for r in game["roads"] for p in r["points"]]
    rzs = [float(p[1]) for r in game["roads"] for p in r["points"]]
    minx = min(rxs + bxs) - pad
    maxx = max(rxs + bxs) + pad
    minz = min(rzs + bzs) - pad
    maxz = max(rzs + bzs) + pad
    scale = 0.12
    w = int((maxx - minx) * scale) + 1
    h = int((maxz - minz) * scale) + 1
    pix = bytearray([32, 36, 28] * w * h)

    def plot(x, z, rgb):
        px = int((x - minx) * scale)
        py = int((maxz - z) * scale)
        if 0 <= px < w and 0 <= py < h:
            i = (py * w + px) * 3
            pix[i:i + 3] = bytes(rgb)

    colors = {
        "roads_no_buildings": (58, 72, 84),
        "buildings_no_playable_road": (120, 64, 48),
        "mixed_shop_street": (46, 110, 72),
        "mixed_tagged": (46, 110, 72),
        "dense_footprints": (150, 118, 64),
        "sparse_street": (92, 84, 58),
        "buildings_near_edge": (110, 70, 54),
    }
    for rec in grid_out:
        rgb = colors.get(rec["class"])
        if not rgb:
            continue
        x = rec["x0"]
        while x < rec["x1"]:
            z = rec["z0"]
            while z < rec["z1"]:
                plot(x, z, rgb)
                z += 8
            x += 8
    for seg in segs:
        n = max(1, int(math.hypot(seg["bx"] - seg["ax"], seg["bz"] - seg["az"]) * scale))
        for i in range(n + 1):
            t = i / n
            plot(seg["ax"] + (seg["bx"] - seg["ax"]) * t, seg["az"] + (seg["bz"] - seg["az"]) * t, (210, 210, 204))
    for b in buildings:
        plot(b["x"], b["z"], (220, 140, 70))
    def cross(x, z, rgb, arm=5):
        for d in range(-arm, arm + 1):
            plot(x + d / scale, z, rgb)
            plot(x, z + d / scale, rgb)

    cross(SPAWN[0], SPAWN[1], (220, 60, 60), 4)
    if recommended:
        cross(recommended["x"], recommended["z"], (80, 220, 120), 6)
    write_png(OUT / "30-coverage-map.png", pix, w, h)
    print("cells", len(grid_out))
    print("bands", dict(bands))
    print("classes", dict(class_counts))
    print("components", len(comps1), len(comp_len), len(comps8))
    print("current", current["buildings_100m"], current["buildings_250m"], current["buildings_500m"], current["nearest_road_id"])
    if picked:
        print("best", picked[0])
    print("wrote", OUT)


if __name__ == "__main__":
    main()
