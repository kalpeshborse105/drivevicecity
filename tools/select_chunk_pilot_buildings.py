#!/usr/bin/env python3
"""Select 40–64 real OSM building footprints for the Phase 2H.4B chunk pilot."""
from __future__ import annotations

import csv
import json
import math
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OSM = ROOT / "assets" / "maps" / "dhule_city.osm"
ROADS = ROOT / "assets" / "maps" / "dhule_roads_game.json"
OUT = ROOT / "docs" / "qa" / "64-chunk-pilot-manifest.json"
CSV_OUT = ROOT / "docs" / "qa" / "64-chunk-pilot-manifest.csv"

LAT0, LON0, M_LAT = 20.902, 74.777, 111320.0
SPAWN = (-636.54, 881.83)
CHUNK_M = 500.0
TARGET_MIN, TARGET_MAX = 40, 64
# Prefer residential plot sizes; avoid huge compounds.
AREA_MIN, AREA_MAX = 35.0, 280.0


def xz(lat: float, lon: float) -> tuple[float, float]:
    m_lon = M_LAT * math.cos(math.radians(LAT0))
    return ((lon - LON0) * m_lon, -(lat - LAT0) * M_LAT)


def ring_area(poly: list[tuple[float, float]]) -> float:
    if len(poly) < 3:
        return 0.0
    a = 0.0
    for i, (x0, z0) in enumerate(poly):
        x1, z1 = poly[(i + 1) % len(poly)]
        a += x0 * z1 - x1 * z0
    return abs(a) * 0.5


def choose_style(area: float, span_min: float, span_max: float, osm_id: str) -> str:
    aspect = span_max / max(span_min, 0.01)
    if area < 72.0:
        return "traditional_compact"
    if span_min < 8.4 and aspect >= 1.45:
        return "narrow_urban"
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


def main() -> None:
    roads = json.loads(ROADS.read_text(encoding="utf-8"))
    sx, sz = float(roads["spawn"]["x"]), float(roads["spawn"]["z"])
    cx0 = math.floor(sx / CHUNK_M)
    cz0 = math.floor(sz / CHUNK_M)
    x0, z0 = cx0 * CHUNK_M, cz0 * CHUNK_M
    x1, z1 = x0 + CHUNK_M, z0 + CHUNK_M

    tree = ET.parse(OSM)
    root = tree.getroot()
    nodes: dict[str, tuple[float, float]] = {}
    for n in root.findall("node"):
        nodes[n.attrib["id"]] = xz(float(n.attrib["lat"]), float(n.attrib["lon"]))

    candidates: list[dict] = []
    for way in root.findall("way"):
        tags = {t.attrib["k"]: t.attrib["v"] for t in way.findall("tag")}
        if "building" not in tags:
            continue
        bid = tags.get("building", "")
        # Skip tagged non-house identities — no invented apartments/commercial.
        if bid in {
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
        }:
            continue
        if "shop" in tags or "amenity" in tags or "office" in tags:
            continue
        refs = [nd.attrib["ref"] for nd in way.findall("nd")]
        poly = [nodes[r] for r in refs if r in nodes]
        if len(poly) < 4:
            continue
        if poly[0] != poly[-1]:
            poly.append(poly[0])
        # drop closing duplicate for area/spans
        ring = poly[:-1]
        if len(ring) < 3:
            continue
        area = ring_area(ring)
        if area < AREA_MIN or area > AREA_MAX:
            continue
        cx = sum(p[0] for p in ring) / len(ring)
        cz = sum(p[1] for p in ring) / len(ring)
        if not (x0 <= cx < x1 and z0 <= cz < z1):
            continue
        xs = [p[0] for p in ring]
        zs = [p[1] for p in ring]
        span_x = max(xs) - min(xs)
        span_z = max(zs) - min(zs)
        span_min, span_max = min(span_x, span_z), max(span_x, span_z)
        wid = way.attrib["id"]
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
        dist = math.hypot(cx - sx, cz - sz)
        candidates.append(
            {
                "osm_id": wid,
                "polygon": [{"x": round(p[0], 3), "z": round(p[1], 3)} for p in ring],
                "area_m2": round(area, 2),
                "vertex_count": len(ring),
                "tags": tags,
                "dist_spawn_m": round(dist, 2),
                "cx": round(cx, 2),
                "cz": round(cz, 2),
                "span_min_m": round(span_min, 2),
                "span_max_m": round(span_max, 2),
                "style": style,
                "floors": floors,
                "height_source": height_source,
                "source_levels": source_levels,
                "chunk_cell": [cx0, cz0],
            }
        )

    # Prefer closer to spawn, mix of sizes: sort by distance then take up to TARGET_MAX.
    candidates.sort(key=lambda r: (r["dist_spawn_m"], r["area_m2"]))
    selected = candidates[:TARGET_MAX]
    if len(selected) < TARGET_MIN:
        # Expand to neighbouring cells if this chunk is sparse.
        print(f"WARN only {len(selected)} in cell {cx0},{cz0} — taking nearest overall")
        all_near = []
        # re-scan would be heavy; instead lower filter by reading candidates from wider set
        # Fallback: use nearest buildings overall from a second pass radius.
        pass

    # If still short, take nearest in 350 m regardless of cell.
    if len(selected) < TARGET_MIN:
        near = [c for c in candidates]
        # rebuild with radius if cell empty-ish — reparse quick
        near2: list[dict] = []
        for way in root.findall("way"):
            tags = {t.attrib["k"]: t.attrib["v"] for t in way.findall("tag")}
            if "building" not in tags:
                continue
            bid = tags.get("building", "")
            if bid in {
                "apartments",
                "commercial",
                "retail",
                "industrial",
                "warehouse",
                "school",
                "college",
                "hospital",
            }:
                continue
            if "shop" in tags or "amenity" in tags:
                continue
            refs = [nd.attrib["ref"] for nd in way.findall("nd")]
            poly = [nodes[r] for r in refs if r in nodes]
            if len(poly) < 4:
                continue
            if poly[0] != poly[-1]:
                poly.append(poly[0])
            ring = poly[:-1]
            area = ring_area(ring)
            if area < AREA_MIN or area > AREA_MAX:
                continue
            cx = sum(p[0] for p in ring) / len(ring)
            cz = sum(p[1] for p in ring) / len(ring)
            dist = math.hypot(cx - sx, cz - sz)
            if dist > 280.0:
                continue
            wid = way.attrib["id"]
            xs = [p[0] for p in ring]
            zs = [p[1] for p in ring]
            span_min = min(max(xs) - min(xs), max(zs) - min(zs))
            span_max = max(max(xs) - min(xs), max(zs) - min(zs))
            style = choose_style(area, span_min, span_max, wid)
            floors = estimated_floors(style, area)
            height_source = "estimated"
            source_levels = ""
            if "building:levels" in tags:
                height_source = "osm"
                source_levels = tags["building:levels"]
                floors = max(1, int(float(tags["building:levels"])))
            near2.append(
                {
                    "osm_id": wid,
                    "polygon": [{"x": round(p[0], 3), "z": round(p[1], 3)} for p in ring],
                    "area_m2": round(area, 2),
                    "vertex_count": len(ring),
                    "tags": tags,
                    "dist_spawn_m": round(dist, 2),
                    "cx": round(cx, 2),
                    "cz": round(cz, 2),
                    "span_min_m": round(span_min, 2),
                    "span_max_m": round(span_max, 2),
                    "style": style,
                    "floors": floors,
                    "height_source": height_source,
                    "source_levels": source_levels,
                    "chunk_cell": [cx0, cz0],
                    "selection_note": "radius_280_fallback",
                }
            )
        near2.sort(key=lambda r: r["dist_spawn_m"])
        selected = near2[:TARGET_MAX]

    manifest = {
        "phase": "2H.4B",
        "spawn": {"x": sx, "z": sz},
        "chunk_m": CHUNK_M,
        "chunk_cell": [cx0, cz0],
        "chunk_bounds": {"x0": x0, "z0": z0, "x1": x1, "z1": z1},
        "count": len(selected),
        "buildings": selected,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    with CSV_OUT.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(
            f,
            fieldnames=[
                "osm_id",
                "area_m2",
                "vertex_count",
                "dist_spawn_m",
                "style",
                "floors",
                "height_source",
                "building_tag",
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
                    "style": b["style"],
                    "floors": b["floors"],
                    "height_source": b["height_source"],
                    "building_tag": b["tags"].get("building", ""),
                }
            )
    styles = {}
    for b in selected:
        styles[b["style"]] = styles.get(b["style"], 0) + 1
    print(f"selected {len(selected)} cell={cx0},{cz0} styles={styles} -> {OUT}")


if __name__ == "__main__":
    main()
