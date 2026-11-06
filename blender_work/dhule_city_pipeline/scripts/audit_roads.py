"""Compare playable Dhule roads with the canonical GeoJSON and the city OSM extract.

Writes blender_work/dhule_city_pipeline/audit/road_audit.json.
Does not modify the road JSON, the GeoJSON, or the OSM file.
"""
import json
import math
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(r"D:\drivevicecity")
GAME = ROOT / "assets" / "maps" / "dhule_roads_game.json"
GEO = ROOT / "data" / "dhule" / "roads.geojson"
OSM = ROOT / "assets" / "maps" / "dhule_city.osm"
OUT = ROOT / "blender_work" / "dhule_city_pipeline" / "audit" / "road_audit.json"

NAME_KEYS = ("name", "ref", "official_name", "alt_name")
KEEP = NAME_KEYS + ("highway", "oneway", "lanes", "width", "surface", "bridge", "tunnel", "junction")


def load_osm_highways():
    ways = {}
    for _ev, elem in ET.iterparse(OSM, events=("end",)):
        if elem.tag != "way":
            if elem.tag == "node":
                elem.clear()
            continue
        tags = {t.attrib["k"]: t.attrib["v"] for t in elem.findall("tag")}
        if "highway" in tags:
            ways[elem.attrib["id"]] = {
                "tags": {k: tags[k] for k in KEEP if k in tags},
                "nodes": [nd.attrib["ref"] for nd in elem.findall("nd")],
            }
        elem.clear()
    return ways


def main():
    game = json.loads(GAME.read_text(encoding="utf-8"))
    geo = json.loads(GEO.read_text(encoding="utf-8"))
    osm = load_osm_highways()
    roads = game["roads"]
    by_id = {}
    dup = []
    for road in roads:
        rid = str(road["id"])
        if rid in by_id:
            dup.append(rid)
        by_id[rid] = road
    geo_by = {}
    for feat in geo["features"]:
        props = feat.get("properties") or {}
        tags = props.get("tags") or {}
        oid = str(props.get("osm_id") or feat.get("id", "").split("/")[-1])
        geo_by[oid] = {
            "highway": props.get("highway") or tags.get("highway", ""),
            "name": tags.get("name", ""),
            "ref": tags.get("ref", ""),
            "official_name": tags.get("official_name", ""),
            "alt_name": tags.get("alt_name", ""),
            "oneway": tags.get("oneway", ""),
            "lanes": tags.get("lanes", ""),
            "width": tags.get("width", ""),
            "surface": tags.get("surface", ""),
            "bridge": tags.get("bridge", ""),
            "tunnel": tags.get("tunnel", ""),
            "junction": tags.get("junction", ""),
            "nodes": [str(n) for n in (props.get("node_ids") or [])],
            "ncoords": len((feat.get("geometry") or {}).get("coordinates") or []),
        }
    game_ids = set(by_id)
    geo_ids = set(geo_by)
    osm_ids = set(osm)
    named_game = [r for r in roads if str(r.get("name", "")).strip()]
    missing_name = []
    for rid, src in list(geo_by.items()) + [(i, {"name": o["tags"].get("name", ""), "ref": o["tags"].get("ref", ""), "official_name": o["tags"].get("official_name", ""), "alt_name": o["tags"].get("alt_name", ""), "highway": o["tags"].get("highway", "")}) for i, o in osm.items()]:
        if rid not in by_id:
            continue
        have = str(by_id[rid].get("name", "")).strip()
        verified = str(src.get("name") or "").strip()
        if verified and not have:
            missing_name.append({
                "osm_id": rid,
                "name": verified,
                "ref": src.get("ref", ""),
                "official_name": src.get("official_name", ""),
                "alt_name": src.get("alt_name", ""),
                "highway": src.get("highway") or by_id[rid].get("highway", ""),
            })
    # unique by id
    seen = set()
    missing_unique = []
    for row in missing_name:
        if row["osm_id"] in seen:
            continue
        seen.add(row["osm_id"])
        missing_unique.append(row)

    classes = Counter(str(r.get("highway", "")) for r in roads)
    named_by_class = Counter(str(r.get("highway", "")) for r in named_game)
    roundabouts = []
    for rid, src in geo_by.items():
        if src.get("junction") == "roundabout":
            roundabouts.append({
                "osm_id": rid,
                "in_game": rid in by_id,
                "highway": src.get("highway", ""),
                "name": src.get("name", ""),
                "lanes": src.get("lanes", ""),
                "nodes": len(src.get("nodes") or []),
            })
    for rid, src in osm.items():
        if src["tags"].get("junction") == "roundabout" and rid not in {r["osm_id"] for r in roundabouts}:
            roundabouts.append({
                "osm_id": rid,
                "in_game": rid in by_id,
                "highway": src["tags"].get("highway", ""),
                "name": src["tags"].get("name", ""),
                "lanes": src["tags"].get("lanes", ""),
                "nodes": len(src["nodes"]),
                "source": "dhule_city.osm",
            })

    # Connectivity on playable centre lines. An endpoint joins another when it is within 1.5 m.
    ends = []
    for road in roads:
        pts = road.get("points") or []
        if len(pts) < 2:
            continue
        ends.append((rid_of(road), 0, pts[0][0], pts[0][1]))
        ends.append((rid_of(road), 1, pts[-1][0], pts[-1][1]))
    cell = 8.0
    bins = defaultdict(list)
    for i, (_rid, _end, x, z) in enumerate(ends):
        bins[(int(x // cell), int(z // cell))].append(i)
    degree = [0] * len(ends)
    for i, (_rid, _end, x, z) in enumerate(ends):
        ix, iz = int(x // cell), int(z // cell)
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for j in bins.get((ix + dx, iz + dz), []):
                    if j <= i:
                        continue
                    if ends[j][0] == ends[i][0]:
                        continue
                    if math.hypot(ends[j][2] - x, ends[j][3] - z) <= 1.5:
                        degree[i] += 1
                        degree[j] += 1
    # An endpoint is connected when it meets another way's endpoint or its interior.
    segs = []
    for road in roads:
        pts = road.get("points") or []
        rid = rid_of(road)
        for a, b in zip(pts, pts[1:]):
            segs.append((rid, a[0], a[1], b[0], b[1]))
    def cells_along(x0, z0, x1, z1):
        dist = math.hypot(x1 - x0, z1 - z0)
        steps = max(1, int(dist / cell) + 1)
        found = set()
        for step in range(steps + 1):
            t = step / steps
            found.add((int((x0 + (x1 - x0) * t) // cell), int((z0 + (z1 - z0) * t) // cell)))
        return found

    seg_bins = defaultdict(list)
    for i, (_rid, x0, z0, x1, z1) in enumerate(segs):
        for key in cells_along(x0, z0, x1, z1):
            seg_bins[key].append(i)

    def near_other(rid, x, z):
        ix, iz = int(x // cell), int(z // cell)
        best = 1e9
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for j in seg_bins.get((ix + dx, iz + dz), []):
                    if segs[j][0] == rid:
                        continue
                    dist = _point_seg(x, z, segs[j][1], segs[j][2], segs[j][3], segs[j][4])
                    if dist < best:
                        best = dist
        return best

    connected_ends = 0
    dead_ends = 0
    for i, (rid, _end, x, z) in enumerate(ends):
        if degree[i] > 0 or near_other(rid, x, z) <= 2.0:
            connected_ends += 1
        else:
            dead_ends += 1

    # Overlapping consecutive duplicates: identical neighbour segments.
    overlap_pairs = 0
    short = 0
    for road in roads:
        pts = road.get("points") or []
        for a, b in zip(pts, pts[1:]):
            if math.hypot(b[0] - a[0], b[1] - a[1]) < 0.4:
                short += 1
    # Same id listed twice already counted. Segment hash collisions across ways.
    seg = Counter()
    for road in roads:
        pts = road.get("points") or []
        for a, b in zip(pts, pts[1:]):
            key = (round(a[0], 1), round(a[1], 1), round(b[0], 1), round(b[1], 1))
            rev = (key[2], key[3], key[0], key[1])
            seg[key if key <= rev else rev] += 1
    overlap_pairs = sum(1 for n in seg.values() if n > 1)

    squares = []
    for rid, src in list(geo_by.items()):
        if src.get("highway") in ("pedestrian",) and "square" in (src.get("name") or "").lower():
            squares.append(rid)
    report = {
        "game_roads": len(roads),
        "game_unique_ids": len(game_ids),
        "duplicate_ids_in_game": dup,
        "geojson_ways": len(geo_ids),
        "geojson_bounds": geo.get("source", {}).get("bounds", {}),
        "osm_highway_ways": len(osm_ids),
        "in_game_not_geojson": len(game_ids - geo_ids),
        "in_geojson_not_game": sorted(geo_ids - game_ids),
        "in_osm_not_game": sorted(osm_ids - game_ids),
        "in_game_and_osm": len(game_ids & osm_ids),
        "highway_class_counts": dict(classes),
        "named_in_game": len(named_game),
        "unnamed_in_game": len(roads) - len(named_game),
        "named_by_class": dict(named_by_class),
        "verified_names_missing_from_game": missing_unique,
        "roundabouts": roundabouts,
        "squares_named_in_geojson": squares,
        "endpoint_pairs": len(ends),
        "endpoints_joined_within_1_5m": sum(1 for d in degree if d > 0),
        "endpoints_meeting_another_way": connected_ends,
        "endpoints_with_no_neighbour": dead_ends,
        "duplicate_segment_keys": overlap_pairs,
        "sub_metre_segments": short,
        "game_has_name_ref_official_alt": {
            "name": sum(1 for r in roads if str(r.get("name", "")).strip()),
            "ref": sum(1 for r in roads if str(r.get("ref", "")).strip()),
            "official_name": sum(1 for r in roads if str(r.get("official_name", "")).strip()),
            "alt_name": sum(1 for r in roads if str(r.get("alt_name", "")).strip()),
            "oneway": sum(1 for r in roads if str(r.get("oneway", "")).strip()),
            "lanes": sum(1 for r in roads if str(r.get("lanes", "")).strip()),
            "surface": sum(1 for r in roads if str(r.get("surface", "")).strip()),
            "bridge": sum(1 for r in roads if r.get("bridge")),
            "tunnel": sum(1 for r in roads if r.get("tunnel")),
        },
        "sample_named": [
            {"osm_id": str(r["id"]), "name": r.get("name", ""), "highway": r.get("highway", ""), "width": r.get("width")}
            for r in named_game[:25]
        ],
        "spawn": game.get("spawn"),
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("roads", len(roads), "named", len(named_game), "geo_missing", len(geo_ids - game_ids), "names_to_add", len(missing_unique))
    print("roundabouts", roundabouts)
    print("dead_ends", dead_ends, "connected", connected_ends, "dup_segs", overlap_pairs)
    print("classes", dict(classes))


def rid_of(road):
    return str(road["id"])


def _point_seg(px, pz, x0, z0, x1, z1):
    dx, dz = x1 - x0, z1 - z0
    l2 = dx * dx + dz * dz
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((px - x0) * dx + (pz - z0) * dz) / l2))
    return math.hypot(px - (x0 + dx * t), pz - (z0 + dz * t))


if __name__ == "__main__":
    main()
