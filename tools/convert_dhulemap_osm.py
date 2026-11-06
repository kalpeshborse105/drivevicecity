"""
convert_dhulemap_osm.py
=======================
Replaces the existing map with the complete city map from dhulemap.osm.
- Reads: D:/drivevicecity/assets/maps/dhulemap.osm (OSM XML with 6,979 nodes, 799 road ways)
- Generates: D:/drivevicecity/assets/maps/dhule_roads_game.json (Godot game map)
"""

import xml.etree.ElementTree as ET
import json
import math
import os
import shutil

ROOT = "D:/drivevicecity"
OSM_PATH = f"{ROOT}/assets/maps/dhulemap.osm"
GAME_JSON = f"{ROOT}/assets/maps/dhule_roads_game.json"
BACKUP_JSON = f"{ROOT}/assets/maps/dhule_roads_game_pre_new_map.json"

ORIGIN_LAT = 20.902
ORIGIN_LON = 74.777
METERS_PER_DEG_LAT = 111320.0
METERS_PER_DEG_LON = 111320.0 * math.cos(math.radians(ORIGIN_LAT))

CLIP_RADIUS = 2000.0  # covers full extent of the provided Dhule map clip

WIDTH = {
    "motorway": 14.0,
    "trunk": 12.0,
    "trunk_link": 9.0,
    "primary": 11.0,
    "primary_link": 9.0,
    "secondary": 9.5,
    "secondary_link": 8.0,
    "tertiary": 8.0,
    "tertiary_link": 7.0,
    "unclassified": 7.5,
    "residential": 7.0,
    "living_street": 6.5,
    "service": 5.5,
}

PRIORITY = {
    "motorway": 0,
    "trunk": 1,
    "trunk_link": 1,
    "primary": 2,
    "primary_link": 2,
    "secondary": 3,
    "secondary_link": 3,
    "tertiary": 4,
    "tertiary_link": 4,
    "unclassified": 5,
    "residential": 6,
    "living_street": 7,
    "service": 8,
}

def to_xz(lat: float, lon: float) -> list[float]:
    x = (lon - ORIGIN_LON) * METERS_PER_DEG_LON
    z = -(lat - ORIGIN_LAT) * METERS_PER_DEG_LAT
    return [round(x, 2), round(z, 2)]

def heading_at(pts: list[list[float]], idx: int) -> list[float]:
    if len(pts) < 2:
        return [0.0, -1.0]
    i0 = max(0, min(idx, len(pts) - 2))
    dx = pts[i0 + 1][0] - pts[i0][0]
    dz = pts[i0 + 1][1] - pts[i0][1]
    length = math.hypot(dx, dz)
    if length < 0.001:
        return [0.0, -1.0]
    return [round(dx / length, 4), round(dz / length, 4)]

def main():
    print("Loading dhulemap.osm ...")
    tree = ET.parse(OSM_PATH)
    root = tree.getroot()

    # Backup existing game map
    if os.path.exists(GAME_JSON):
        shutil.copyfile(GAME_JSON, BACKUP_JSON)
        print(f"Backed up existing game map to: {BACKUP_JSON}")
        with open(GAME_JSON, "r", encoding="utf-8") as f:
            prev_data = json.load(f)
    else:
        prev_data = {}

    # 1. Parse all nodes
    nodes = {}
    node_tags = {}
    for n in root.findall("node"):
        nid = n.attrib["id"]
        lat = float(n.attrib["lat"])
        lon = float(n.attrib["lon"])
        nodes[nid] = (lat, lon)
        tags = {t.attrib["k"]: t.attrib["v"] for t in n.findall("tag")}
        if tags:
            node_tags[nid] = tags

    print(f"Nodes loaded: {len(nodes)}")

    # 2. Parse ways: roads, buildings, water, flyovers
    roads = []
    buildings = []
    waters = []
    landuses = []
    flyovers = []
    pois = []

    min_x = min_z = 1e9
    max_x = max_z = -1e9

    for w in root.findall("way"):
        tags = {t.attrib["k"]: t.attrib["v"] for t in w.findall("tag")}
        refs = [nd.attrib["ref"] for nd in w.findall("nd")]
        coords = [nodes[r] for r in refs if r in nodes]
        if len(coords) < 2:
            continue

        xz_pts = [to_xz(lat, lon) for lat, lon in coords]

        # Filter duplicates / zero-length segments
        clean_pts = [xz_pts[0]]
        for p in xz_pts[1:]:
            if math.hypot(p[0] - clean_pts[-1][0], p[1] - clean_pts[-1][1]) > 0.3:
                clean_pts.append(p)

        if len(clean_pts) < 2:
            continue

        # Roads
        hw = tags.get("highway")
        if hw in WIDTH:
            # Calculate length
            total_len = sum(math.hypot(clean_pts[i][0] - clean_pts[i-1][0], clean_pts[i][1] - clean_pts[i-1][1]) for i in range(1, len(clean_pts)))
            if total_len >= 8.0:
                for p in clean_pts:
                    min_x = min(min_x, p[0])
                    max_x = max(max_x, p[0])
                    min_z = min(min_z, p[1])
                    max_z = max(max_z, p[1])

                road_name = tags.get("name") or tags.get("name:en") or tags.get("name:mr") or ""
                road_id = int(w.attrib["id"])
                width = WIDTH[hw]
                roads.append({
                    "id": road_id,
                    "run": 0,
                    "name": road_name,
                    "highway": hw,
                    "width": width,
                    "points": clean_pts,
                    "length": round(total_len, 1)
                })

                # Check if bridge / flyover
                if tags.get("bridge") == "yes" or int(tags.get("layer", 0)) > 0:
                    flyovers.append({
                        "kind": hw,
                        "width": int(round(width)),
                        "points": clean_pts
                    })

        # Buildings
        if "building" in tags and len(clean_pts) >= 3:
            xs = [p[0] for p in clean_pts]
            zs = [p[1] for p in clean_pts]
            cx = round(sum(xs) / len(xs), 2)
            cz = round(sum(zs) / len(zs), 2)
            bw = round(max(xs) - min(xs), 2)
            bd = round(max(zs) - min(zs), 2)
            if 4.0 <= bw <= 120.0 and 4.0 <= bd <= 120.0:
                bkind = tags.get("building") or "yes"
                bname = tags.get("name") or tags.get("name:en") or ""
                try:
                    levels = float(tags.get("building:levels", 0))
                    height = max(4.0, levels * 3.1)
                except ValueError:
                    height = 8.0 if bkind in ("yes", "residential") else 10.0
                buildings.append({
                    "id": int(w.attrib["id"]),
                    "kind": bkind,
                    "name": bname,
                    "x": cx,
                    "z": cz,
                    "w": bw,
                    "d": bd,
                    "h": round(min(height, 24.0), 2)
                })

        # Water / Panzara River
        if tags.get("natural") == "water" or tags.get("waterway") in ("river", "riverbank", "stream", "canal"):
            xs = [p[0] for p in clean_pts]
            zs = [p[1] for p in clean_pts]
            cx = round(sum(xs) / len(xs), 2)
            cz = round(sum(zs) / len(zs), 2)
            ww = round(max(xs) - min(xs), 2)
            wd = round(max(zs) - min(zs), 2)
            waters.append({
                "x": cx,
                "z": cz,
                "w": max(ww, 30.0),
                "d": max(wd, 30.0)
            })

        # Landuse
        lu = tags.get("landuse")
        if lu in ("residential", "commercial", "retail", "grass", "farmland"):
            xs = [p[0] for p in clean_pts]
            zs = [p[1] for p in clean_pts]
            cx = round(sum(xs) / len(xs), 2)
            cz = round(sum(zs) / len(zs), 2)
            landuses.append({
                "kind": lu,
                "x": cx,
                "z": cz,
                "w": round(min(max(xs) - min(xs), 140.0), 2),
                "d": round(min(max(zs) - min(zs), 140.0), 2)
            })

    # 3. Parse POIs from nodes
    for nid, tags in node_tags.items():
        name = tags.get("name") or tags.get("name:en") or tags.get("name:mr") or ""
        amenity = tags.get("amenity")
        shop = tags.get("shop")
        tourism = tags.get("tourism")
        if not (name or amenity or shop or tourism):
            continue
        lat, lon = nodes[nid]
        xz = to_xz(lat, lon)
        kind = amenity or shop or tourism or "landmark"
        pois.append({
            "name": name if name else kind.replace("_", " ").title(),
            "kind": kind,
            "x": xz[0],
            "z": xz[1]
        })

    # Sort roads: major highways first, then long residential roads
    roads.sort(key=lambda r: (PRIORITY.get(r["highway"], 9), -r["length"]))
    for r in roads:
        r.pop("length", None)

    print(f"Total Roads extracted: {len(roads)}")
    print(f"Total Buildings extracted: {len(buildings)}")
    print(f"Total POIs extracted: {len(pois)}")
    print(f"Total Flyovers extracted: {len(flyovers)}")
    print(f"Total Water bodies: {len(waters)}")

    # Merge existing rich POIs if any are not present
    existing_pois = prev_data.get("pois", [])
    poi_keys = {(round(p["x"], 1), round(p["z"], 1)) for p in pois}
    for ep in existing_pois:
        k = (round(ep["x"], 1), round(ep["z"], 1))
        if k not in poi_keys:
            pois.append(ep)
            poi_keys.add(k)

    # Merge existing buildings if needed
    existing_blds = prev_data.get("buildings", [])
    bld_keys = {(round(b["x"], 1), round(b["z"], 1)) for b in buildings}
    for eb in existing_blds:
        k = (round(eb["x"], 1), round(eb["z"], 1))
        if k not in bld_keys:
            buildings.append(eb)
            bld_keys.add(k)

    # Spawn configuration
    spawn = prev_data.get("spawn", {
        "x": -13.09,
        "z": -86.21,
        "hx": 0.1523,
        "hz": -0.9883,
        "road": "secondary",
        "highway": "secondary"
    })

    # Generate / select 24 spaced delivery anchors across the road network
    anchors = []
    candidate_anchors = []
    for r in roads:
        pts = r["points"]
        if len(pts) < 2:
            continue
        # Pick mid points
        mid_idx = len(pts) // 2
        p = pts[mid_idx]
        hx, hz = heading_at(pts, mid_idx)
        dist_spawn = math.hypot(p[0] - spawn["x"], p[1] - spawn["z"])
        if 40.0 < dist_spawn < 1600.0:
            candidate_anchors.append({
                "x": p[0],
                "z": p[1],
                "hx": hx,
                "hz": hz,
                "road": r.get("name") or r["highway"],
                "highway": r["highway"],
                "dist": dist_spawn
            })

    candidate_anchors.sort(key=lambda a: a["dist"])
    for ca in candidate_anchors:
        if all(math.hypot(ca["x"] - a["x"], ca["z"] - a["z"]) > 90.0 for a in anchors):
            anchors.append({
                "x": ca["x"],
                "z": ca["z"],
                "hx": ca["hx"],
                "hz": ca["hz"],
                "road": ca["road"],
                "highway": ca["highway"]
            })
            if len(anchors) >= 28:
                break

    if len(anchors) < 24 and prev_data.get("delivery_anchors"):
        anchors = prev_data["delivery_anchors"]

    # Final Payload
    payload = {
        "attribution": "© OpenStreetMap contributors (ODbL)",
        "source": "dhulemap.osm-user-export-full-city",
        "origin_lat": ORIGIN_LAT,
        "origin_lon": ORIGIN_LON,
        "clip_radius_m": CLIP_RADIUS,
        "bbox_m": {
            "min_x": round(min_x, 2),
            "max_x": round(max_x, 2),
            "min_z": round(min_z, 2),
            "max_z": round(max_z, 2)
        },
        "road_count": len(roads),
        "spawn": spawn,
        "roads": roads,
        "delivery_anchors": anchors,
        "buildings": buildings,
        "water": waters if waters else prev_data.get("water", []),
        "landuse": landuses if landuses else prev_data.get("landuse", []),
        "pois": pois,
        "flyovers": flyovers if flyovers else prev_data.get("flyovers", [])
    }

    with open(GAME_JSON, "w", encoding="utf-8") as f:
        json.dump(payload, f, separators=(",", ":"))

    file_size_kb = os.path.getsize(GAME_JSON) / 1024.0
    print(f"\nSuccessfully replaced Dhule map with full city export!")
    print(f"File: {GAME_JSON} ({file_size_kb:.1f} KB)")
    print(f"Total Roads: {len(roads)} (was 420)")
    print(f"Total Buildings: {len(buildings)}")
    print(f"Total POIs: {len(pois)}")
    print(f"Total Delivery Anchors: {len(anchors)}")
    print(f"Total Flyovers: {len(payload['flyovers'])}")
    print(f"City Bounding Box: X=[{min_x:.1f}, {max_x:.1f}]m, Z=[{min_z:.1f}, {max_z:.1f}]m")

if __name__ == "__main__":
    main()

