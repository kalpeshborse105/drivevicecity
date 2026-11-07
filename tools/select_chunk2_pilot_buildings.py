#!/usr/bin/env python3
"""Select 40–64 real OSM footprints for Phase 2H.4C second neighbourhood pilot."""
from __future__ import annotations

import csv
import json
import math
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OSM = ROOT / "assets" / "maps" / "dhule_city.osm"
ROADS = ROOT / "assets" / "maps" / "dhule_roads_game.json"
FIRST = ROOT / "docs" / "qa" / "64-chunk-pilot-manifest.json"
OUT = ROOT / "docs" / "qa" / "76-chunk2-pilot-manifest.json"
CSV_OUT = ROOT / "docs" / "qa" / "76-chunk2-pilot-manifest.csv"
REJECT_OUT = ROOT / "docs" / "qa" / "76-chunk2-selection-rejects.json"

LAT0, LON0, M_LAT = 20.902, 74.777, 111320.0
CHUNK_M = 500.0
# Distinct from first pilot cell (-2, 1); continuous band immediately north.
TARGET_CELL = (-2, 2)
EXPAND_CELLS = [(-2, 2), (-1, 2), (-3, 2), (-2, 3), (-1, 3)]
TARGET_MIN, TARGET_MAX = 40, 64
AREA_MIN, AREA_MAX = 28.0, 320.0
ROAD_MARGIN = 0.5
CLUSTER_RADIUS_START_M = 180.0
CLUSTER_RADIUS_MAX_M = 480.0
SKIP_BUILDING = {
    "apartments",
    "commercial",
    "retail",
    "industrial",
    "warehouse",
    "school",
    "college",
    "hospital",
    "mosque",
    "temple",
    "church",
    "public",
    "garage",
}


def xz(lat: float, lon: float) -> tuple[float, float]:
    m_lon = M_LAT * math.cos(math.radians(LAT0))
    return ((lon - LON0) * m_lon, -(lat - LAT0) * M_LAT)


def ring_area(poly: list[tuple[float, float]]) -> float:
    a = 0.0
    for i, (x0, z0) in enumerate(poly):
        x1, z1 = poly[(i + 1) % len(poly)]
        a += x0 * z1 - x1 * z0
    return abs(a) * 0.5


def choose_style(area: float, span_min: float, span_max: float, osm_id: str) -> str:
    aspect = span_max / max(span_min, 0.01)
    # Narrow first so elongated small plots are not swallowed by compact.
    if span_min < 8.4 and aspect >= 1.45:
        return "narrow_urban"
    if area < 72.0:
        return "traditional_compact"
    bucket = abs(int(osm_id)) % 4
    if bucket == 0:
        return "traditional_compact"
    if bucket == 1 and span_min < 9.0:
        return "narrow_urban"
    return "plastered_house"


def estimated_floors(style: str, area: float) -> int:
    if style == "traditional_compact":
        return 1
    if style == "narrow_urban":
        return 2 if area >= 70.0 else 1
    return 2 if area >= 72.0 else 1


def load_road_segments(roads: dict) -> list[tuple[tuple[float, float], tuple[float, float], float]]:
    segs: list[tuple[tuple[float, float], tuple[float, float], float]] = []
    for road in roads.get("roads", []):
        pts = road.get("points", [])
        half = float(road.get("width", 7.0)) * 0.5
        for i in range(len(pts) - 1):
            a = (float(pts[i][0]), float(pts[i][1]))
            b = (float(pts[i + 1][0]), float(pts[i + 1][1]))
            segs.append((a, b, half))
    return segs


def point_seg_clear(p: tuple[float, float], a: tuple[float, float], b: tuple[float, float], half: float) -> float:
    ab = (b[0] - a[0], b[1] - a[1])
    den = ab[0] * ab[0] + ab[1] * ab[1]
    t = 0.0 if den == 0.0 else max(0.0, min(1.0, ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / den))
    q = (a[0] + ab[0] * t, a[1] + ab[1] * t)
    return math.hypot(p[0] - q[0], p[1] - q[1]) - half


def aabb_road_clearance(ring: list[tuple[float, float]], segs: list) -> float:
    ## Match Godot AssetPlacementValidator.asphalt_clearance on the plan AABB.
    xs = [p[0] for p in ring]
    zs = [p[1] for p in ring]
    x0, x1 = min(xs), max(xs)
    z0, z1 = min(zs), max(zs)
    samples = [
        (x0, z0),
        (x1, z0),
        (x0, z1),
        (x1, z1),
        ((x0 + x1) * 0.5, (z0 + z1) * 0.5),
    ]
    best = 1.0e9
    for p in samples:
        for a, b, half in segs:
            best = min(best, point_seg_clear(p, a, b, half))
    return best


def nearest_road(p: tuple[float, float], segs: list) -> tuple[float, float]:
    best_d = 1.0e9
    best_half = 3.5
    for a, b, half in segs:
        ab = (b[0] - a[0], b[1] - a[1])
        den = ab[0] * ab[0] + ab[1] * ab[1]
        t = 0.0 if den == 0.0 else max(0.0, min(1.0, ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / den))
        q = (a[0] + ab[0] * t, a[1] + ab[1] * t)
        d = math.hypot(p[0] - q[0], p[1] - q[1])
        if d < best_d:
            best_d = d
            best_half = half
    return best_d, best_half


def front_edge_clearance(ring: list[tuple[float, float]], segs: list) -> float:
    ## Match dhule_building_chunk_2_pilot._front_edge.
    best_d = 1.0e9
    best_clear = 0.0
    n = len(ring)
    for i in range(n):
        a = ring[i]
        b = ring[(i + 1) % n]
        if math.hypot(b[0] - a[0], b[1] - a[1]) < 1.6:
            continue
        mid = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        dist, half = nearest_road(mid, segs)
        if dist < best_d:
            best_d = dist
            best_clear = dist - half
    return best_clear


def polys_overlap(a: list[tuple[float, float]], b: list[tuple[float, float]], margin: float = 0.2) -> bool:
    ax0, ax1 = min(p[0] for p in a) - margin, max(p[0] for p in a) + margin
    az0, az1 = min(p[1] for p in a) - margin, max(p[1] for p in a) + margin
    bx0, bx1 = min(p[0] for p in b), max(p[0] for p in b)
    bz0, bz1 = min(p[1] for p in b), max(p[1] for p in b)
    return not (ax1 < bx0 or bx1 < ax0 or az1 < bz0 or bz1 < az0)


def main() -> None:
    roads = json.loads(ROADS.read_text(encoding="utf-8"))
    road_segs = load_road_segments(roads)
    sx, sz = float(roads["spawn"]["x"]), float(roads["spawn"]["z"])
    first = json.loads(FIRST.read_text(encoding="utf-8"))
    first_ids = {str(b["osm_id"]) for b in first.get("buildings", [])}
    first_cx = sum(float(b["cx"]) for b in first["buildings"]) / max(len(first["buildings"]), 1)
    first_cz = sum(float(b["cz"]) for b in first["buildings"]) / max(len(first["buildings"]), 1)

    tree = ET.parse(OSM)
    root = tree.getroot()
    nodes = {
        n.attrib["id"]: xz(float(n.attrib["lat"]), float(n.attrib["lon"]))
        for n in root.findall("node")
    }

    rejects: list[dict] = []
    candidates: list[dict] = []
    for way in root.findall("way"):
        tags = {t.attrib["k"]: t.attrib["v"] for t in way.findall("tag")}
        wid = way.attrib["id"]
        if "building" not in tags:
            continue
        if wid in first_ids:
            rejects.append({"osm_id": wid, "reason": "in_first_pilot"})
            continue
        bid = tags.get("building", "")
        if bid in SKIP_BUILDING:
            rejects.append({"osm_id": wid, "reason": f"building_tag_{bid}"})
            continue
        if "shop" in tags or "amenity" in tags or "office" in tags:
            rejects.append({"osm_id": wid, "reason": "shop_amenity_or_office"})
            continue
        refs = [nd.attrib["ref"] for nd in way.findall("nd")]
        poly = [nodes[r] for r in refs if r in nodes]
        if len(poly) < 4:
            rejects.append({"osm_id": wid, "reason": "too_few_nodes"})
            continue
        if poly[0] != poly[-1]:
            poly = poly + [poly[0]]
        ring = poly[:-1]
        if len(ring) < 3:
            rejects.append({"osm_id": wid, "reason": "degenerate_ring"})
            continue
        area = ring_area(ring)
        if area < AREA_MIN or area > AREA_MAX:
            rejects.append({"osm_id": wid, "reason": "area_out_of_range", "area_m2": round(area, 2)})
            continue
        cx = sum(p[0] for p in ring) / len(ring)
        cz = sum(p[1] for p in ring) / len(ring)
        cell = (math.floor(cx / CHUNK_M), math.floor(cz / CHUNK_M))
        if cell not in EXPAND_CELLS:
            rejects.append({"osm_id": wid, "reason": "outside_target_cells", "cell": list(cell)})
            continue
        xs = [p[0] for p in ring]
        zs = [p[1] for p in ring]
        span_x = max(xs) - min(xs)
        span_z = max(zs) - min(zs)
        span_min, span_max = min(span_x, span_z), max(span_x, span_z)
        style = choose_style(area, span_min, span_max, wid)
        height_source = "estimated"
        floors = estimated_floors(style, area)
        source_levels = ""
        if "height" in tags:
            height_source = "osm"
            source_levels = tags["height"]
            try:
                floors = max(1, int(math.ceil(float(tags["height"]) / 3.1)))
            except ValueError:
                pass
        elif "building:levels" in tags:
            height_source = "osm"
            source_levels = tags["building:levels"]
            try:
                floors = max(1, int(float(tags["building:levels"])))
            except ValueError:
                pass
        dist_spawn = math.hypot(cx - sx, cz - sz)
        dist_first = math.hypot(cx - first_cx, cz - first_cz)
        aabb_clear = aabb_road_clearance(ring, road_segs)
        front_clear = front_edge_clearance(ring, road_segs)
        if aabb_clear < ROAD_MARGIN or front_clear < ROAD_MARGIN:
            rejects.append(
                {
                    "osm_id": wid,
                    "reason": "road_clearance",
                    "aabb_clear_m": round(aabb_clear, 2),
                    "front_clear_m": round(front_clear, 2),
                    "cell": list(cell),
                }
            )
            continue
        cell_rank = 0 if cell == TARGET_CELL else (1 if cell[1] == TARGET_CELL[1] else 2)
        candidates.append(
            {
                "osm_id": wid,
                "polygon": [{"x": round(p[0], 3), "z": round(p[1], 3)} for p in ring],
                "area_m2": round(area, 2),
                "vertex_count": len(ring),
                "tags": tags,
                "dist_spawn_m": round(dist_spawn, 2),
                "dist_first_pilot_m": round(dist_first, 2),
                "road_clear_m": round(min(aabb_clear, front_clear), 2),
                "aabb_clear_m": round(aabb_clear, 2),
                "front_clear_m": round(front_clear, 2),
                "cx": round(cx, 2),
                "cz": round(cz, 2),
                "span_min_m": round(span_min, 2),
                "span_max_m": round(span_max, 2),
                "style": style,
                "floors": floors,
                "height_source": height_source,
                "source_levels": source_levels,
                "chunk_cell": list(cell),
                "asset": "",
                "asset_assignment": "procedural_shell",
                "_ring": ring,
                "_rank": (cell_rank, dist_first, -min(aabb_clear, front_clear), area),
            }
        )

    candidates.sort(key=lambda r: r["_rank"])

    def pick_nonoverlapping(pool: list[dict]) -> tuple[list[dict], list[dict]]:
        chosen: list[dict] = []
        local_rejects: list[dict] = []
        for c in pool:
            if len(chosen) >= TARGET_MAX:
                local_rejects.append({"osm_id": c["osm_id"], "reason": "over_target_cap"})
                continue
            if any(polys_overlap(c["_ring"], prev["_ring"], 0.2) for prev in chosen):
                local_rejects.append({"osm_id": c["osm_id"], "reason": "neighbour_overlap_prefilter"})
                continue
            chosen.append(c)
        return chosen, local_rejects

    # Seed = densest building within a mid radius, then grow radius until >= TARGET_MIN.
    probe_r = min(260.0, CLUSTER_RADIUS_MAX_M)

    def neighbour_count(seed: dict) -> int:
        return sum(
            1
            for o in candidates
            if math.hypot(o["cx"] - seed["cx"], o["cz"] - seed["cz"]) <= probe_r
        )

    seed = max(candidates, key=neighbour_count) if candidates else None
    selected: list[dict] = []
    used_radius = CLUSTER_RADIUS_START_M
    cluster_meta: dict = {}
    if seed is not None:
        radius = CLUSTER_RADIUS_START_M
        while radius <= CLUSTER_RADIUS_MAX_M:
            pool = [
                c
                for c in candidates
                if math.hypot(c["cx"] - seed["cx"], c["cz"] - seed["cz"]) <= radius
            ]
            pool.sort(
                key=lambda r: (
                    math.hypot(r["cx"] - seed["cx"], r["cz"] - seed["cz"]),
                    r["_rank"],
                )
            )
            selected, _ = pick_nonoverlapping(pool)
            used_radius = radius
            if len(selected) >= TARGET_MIN:
                break
            radius += 40.0
        pool_ids = {c["osm_id"] for c in selected}
        for c in candidates:
            if c["osm_id"] in pool_ids:
                continue
            dist = math.hypot(c["cx"] - seed["cx"], c["cz"] - seed["cz"])
            if dist > used_radius:
                rejects.append(
                    {
                        "osm_id": c["osm_id"],
                        "reason": "outside_dense_cluster",
                        "cluster_seed": seed["osm_id"],
                        "cluster_radius_m": used_radius,
                    }
                )
            else:
                rejects.append({"osm_id": c["osm_id"], "reason": "neighbour_overlap_prefilter"})
        cluster_meta = {
            "seed_osm_id": seed["osm_id"],
            "radius_m": used_radius,
            "seed_xz": {"x": seed["cx"], "z": seed["cz"]},
        }
    else:
        selected, extra = pick_nonoverlapping(candidates)
        rejects.extend(extra)

    for b in selected:
        b.pop("_rank", None)
        b.pop("_ring", None)

    x0, z0 = TARGET_CELL[0] * CHUNK_M, TARGET_CELL[1] * CHUNK_M
    nest_cx = sum(b["cx"] for b in selected) / max(len(selected), 1)
    nest_cz = sum(b["cz"] for b in selected) / max(len(selected), 1)
    styles = {}
    for b in selected:
        styles[b["style"]] = styles.get(b["style"], 0) + 1

    manifest = {
        "phase": "2H.4C",
        "spawn": {"x": sx, "z": sz},
        "neighbourhood_origin": {"x": round(nest_cx, 2), "z": round(nest_cz, 2)},
        "chunk_m": CHUNK_M,
        "chunk_cell": list(TARGET_CELL),
        "expand_cells": [list(c) for c in EXPAND_CELLS],
        "chunk_bounds": {"x0": x0, "z0": z0, "x1": x0 + CHUNK_M, "z1": z0 + CHUNK_M},
        "cluster": cluster_meta,
        "first_pilot_cell": first.get("chunk_cell"),
        "excluded_first_pilot_ids": len(first_ids),
        "count": len(selected),
        "style_counts": styles,
        "buildings": selected,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    REJECT_OUT.write_text(
        json.dumps({"rejected": len(rejects), "rows": rejects[:500], "note": "truncated_if_over_500"}, indent=2),
        encoding="utf-8",
    )
    with CSV_OUT.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(
            f,
            fieldnames=[
                "osm_id",
                "area_m2",
                "vertex_count",
                "dist_spawn_m",
                "dist_first_pilot_m",
                "style",
                "floors",
                "height_source",
                "building_tag",
                "chunk_cell",
                "asset_assignment",
            ],
        )
        w.writeheader()
        for b in selected:
            w.writerow(
                {
                    "osm_id": b["osm_id"],
                    "area_m2": b["area_m2"],
                    "vertex_count": b["vertex_count"],
                    "dist_spawn_m": b["dist_spawn_m"],
                    "dist_first_pilot_m": b["dist_first_pilot_m"],
                    "style": b["style"],
                    "floors": b["floors"],
                    "height_source": b["height_source"],
                    "building_tag": b["tags"].get("building", ""),
                    "chunk_cell": b["chunk_cell"],
                    "asset_assignment": b["asset_assignment"],
                }
            )
    print(
        f"selected {len(selected)} primary={TARGET_CELL} styles={styles} "
        f"med_dist_first={sorted(b['dist_first_pilot_m'] for b in selected)[len(selected)//2]:.1f} -> {OUT}"
    )
    if len(selected) < TARGET_MIN:
        raise SystemExit(f"FAIL need >= {TARGET_MIN}, got {len(selected)}")


if __name__ == "__main__":
    main()
