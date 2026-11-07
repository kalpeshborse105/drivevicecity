#!/usr/bin/env python3
"""Phase 2H.1 — complete Dhule building data audit (read-only).

Reads OSM, playable JSON, Blosm partition manifests, and building-related GLBs.
Writes JSON under blender_work/dhule_city_pipeline/audit/ and prints a summary.
Does not modify production meshes, roads, spawn, or vehicle scripts.
"""
from __future__ import annotations

import hashlib
import json
import math
import struct
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(r"D:\drivevicecity")
CITY_OSM = ROOT / "assets" / "maps" / "dhule_city.osm"
MAP_OSM = ROOT / "assets" / "maps" / "dhulemap.osm"
GAME_JSON = ROOT / "assets" / "maps" / "dhule_roads_game.json"
BLOSM_GLB = ROOT / "assets" / "models" / "environments" / "dhule_blosm_city.glb"
MANIFEST = ROOT / "blender_work" / "dhule_city_pipeline" / "manifests" / "building_manifest.json"
EXPORT_MANIFEST = ROOT / "blender_work" / "dhule_city_pipeline" / "manifests" / "export_manifest.json"
OUT_DIR = ROOT / "blender_work" / "dhule_city_pipeline" / "audit"
OUT_JSON = OUT_DIR / "complete_building_data_audit.json"
OUT_CSV = OUT_DIR / "complete_building_ways.csv"
OUT_NAMED = OUT_DIR / "named_buildings.csv"
OUT_ASSETS = OUT_DIR / "building_glb_inventory.csv"

LAT0 = 20.902
LON0 = 74.777
M_LAT = 111320.0
M_LON = M_LAT * math.cos(math.radians(LAT0))
SPAWN = (-636.54, 881.83)

# Explicit tag → category. Name alone never creates shop/public categories.
CATEGORY_BY_BUILDING = {
    "house": "small_residential_house",
    "detached": "family_house",
    "semidetached_house": "family_house",
    "terrace": "row_house",
    "bungalow": "family_house",
    "apartments": "apartment",
    # Generic residential with no further tags — not enough evidence for apartment vs house.
    "residential": "family_house",
    "commercial": "commercial_building",
    "retail": "commercial_shop",
    "kiosk": "commercial_shop",
    "office": "office",
    "industrial": "industrial",
    "warehouse": "industrial",
    "factory": "industrial",
    "school": "school",
    "college": "school",
    "university": "school",
    "hospital": "hospital",
    "clinic": "hospital",
    "church": "religious",
    "mosque": "religious",
    "temple": "religious",
    "chapel": "religious",
    "cathedral": "religious",
    "synagogue": "religious",
    "gurdwara": "religious",
    "public": "other_public",
    "civic": "other_public",
    "government": "other_public",
    "yes": "unknown_or_unclassified",
}


def xz(lat: float, lon: float) -> tuple[float, float]:
    return (lon - LON0) * M_LON, -(lat - LAT0) * M_LAT


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def ring_area(poly: list[tuple[float, float]]) -> float:
    if len(poly) < 3:
        return 0.0
    a = 0.0
    for i, (x0, z0) in enumerate(poly):
        x1, z1 = poly[(i + 1) % len(poly)]
        a += x0 * z1 - x1 * z0
    return abs(a) * 0.5


def ring_bbox(poly: list[tuple[float, float]]) -> tuple[float, float, float, float]:
    xs = [p[0] for p in poly]
    zs = [p[1] for p in poly]
    return min(xs), max(xs), min(zs), max(zs)


def self_intersects(poly: list[tuple[float, float]]) -> bool:
    def orient(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    def on_seg(a, b, c):
        return (
            min(a[0], b[0]) - 1e-9 <= c[0] <= max(a[0], b[0]) + 1e-9
            and min(a[1], b[1]) - 1e-9 <= c[1] <= max(a[1], b[1]) + 1e-9
        )

    def intersects(a, b, c, d):
        o1, o2 = orient(a, b, c), orient(a, b, d)
        o3, o4 = orient(c, d, a), orient(c, d, b)
        if o1 == 0 and on_seg(a, b, c):
            return True
        if o2 == 0 and on_seg(a, b, d):
            return True
        if o3 == 0 and on_seg(c, d, a):
            return True
        if o4 == 0 and on_seg(c, d, b):
            return True
        return (o1 > 0) != (o2 > 0) and (o3 > 0) != (o4 > 0)

    n = len(poly)
    if n < 4:
        return False
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        for j in range(i + 1, n):
            if abs(i - j) <= 1 or (i == 0 and j == n - 1):
                continue
            c, d = poly[j], poly[(j + 1) % n]
            if intersects(a, b, c, d):
                return True
    return False


def categorize(tags: dict[str, str]) -> str:
    """Evidence-based category. Do not invent shop/public from name alone."""
    b = tags.get("building", "").strip().lower()
    amenity = tags.get("amenity", "").strip().lower()
    shop = tags.get("shop", "").strip().lower()
    office = tags.get("office", "").strip().lower()
    industrial = tags.get("industrial", "").strip().lower()
    leisure = tags.get("leisure", "").strip().lower()
    tourism = tags.get("tourism", "").strip().lower()

    if shop:
        return "commercial_shop"
    if office or amenity in {"office", "townhall", "courthouse", "police", "post_office", "community_centre"}:
        return "office" if office or amenity == "office" else "other_public"
    if industrial or amenity in {"warehouse"}:
        return "industrial"
    if amenity in {"school", "college", "university", "kindergarten"} or b in {"school", "college", "university"}:
        return "school"
    if amenity in {"hospital", "clinic", "doctors", "dentist"} or b in {"hospital", "clinic"}:
        return "hospital"
    if amenity in {"place_of_worship"} or b in {
        "church", "mosque", "temple", "chapel", "cathedral", "synagogue", "gurdwara", "religious"
    }:
        return "religious"
    if amenity in {"library", "theatre", "cinema", "arts_centre", "fire_station", "courthouse"}:
        return "other_public"
    if leisure or tourism in {"museum", "attraction"}:
        return "other_public"
    if b in CATEGORY_BY_BUILDING:
        return CATEGORY_BY_BUILDING[b]
    if b and b != "yes":
        return "unknown_or_unclassified"
    return "unknown_or_unclassified"


def area_band(area: float) -> str:
    if area < 40:
        return "under_40"
    if area < 72:
        return "40_to_72_small_house"
    if area < 180:
        return "72_to_180_family"
    if area < 500:
        return "180_to_500"
    if area < 2000:
        return "500_to_2000"
    return "over_2000"


def load_osm(path: Path) -> dict:
    nodes: dict[str, tuple[float, float]] = {}
    buildings: list[dict] = []
    duplicates: list[str] = []
    seen: set[str] = set()
    missing_nodes = 0
    all_tag_keys: Counter = Counter()
    building_vals: Counter = Counter()
    invalid_rings = 0

    for _ev, elem in ET.iterparse(path, events=("end",)):
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
                poly: list[tuple[float, float]] = []
                for nd in elem.findall("nd"):
                    ll = nodes.get(nd.attrib["ref"])
                    if ll is None:
                        missing_nodes += 1
                        continue
                    poly.append(xz(*ll))
                if len(poly) >= 4 and poly[0] == poly[-1]:
                    poly = poly[:-1]
                ok = len(poly) >= 3
                area = ring_area(poly) if ok else 0.0
                if not ok or area <= 0.01 or self_intersects(poly):
                    invalid_rings += 1
                    geom_ok = False
                else:
                    geom_ok = True
                minx = maxx = minz = maxz = 0.0
                cx = cz = 0.0
                if poly:
                    minx, maxx, minz, maxz = ring_bbox(poly)
                    cx = sum(p[0] for p in poly) / len(poly)
                    cz = sum(p[1] for p in poly) / len(poly)
                for k in tags:
                    all_tag_keys[k] += 1
                building_vals[tags.get("building", "")] += 1
                row = {
                    "osm_id": wid,
                    "source": path.name,
                    "vertices": len(poly),
                    "area_m2": round(area, 3),
                    "min_x": round(minx, 3),
                    "max_x": round(maxx, 3),
                    "min_z": round(minz, 3),
                    "max_z": round(maxz, 3),
                    "cx": round(cx, 3),
                    "cz": round(cz, 3),
                    "span_x": round(maxx - minx, 3),
                    "span_z": round(maxz - minz, 3),
                    "building": tags.get("building", ""),
                    "building_levels": tags.get("building:levels", ""),
                    "height": tags.get("height", ""),
                    "roof_shape": tags.get("roof:shape", ""),
                    "roof_levels": tags.get("roof:levels", ""),
                    "name": tags.get("name", ""),
                    "shop": tags.get("shop", ""),
                    "amenity": tags.get("amenity", ""),
                    "office": tags.get("office", ""),
                    "industrial": tags.get("industrial", ""),
                    "category": categorize(tags),
                    "area_band": area_band(area) if geom_ok else "invalid",
                    "geom_ok": geom_ok,
                    "dist_spawn_m": round(math.hypot(cx - SPAWN[0], cz - SPAWN[1]), 2) if poly else None,
                    "tags": tags,
                }
                buildings.append(row)
            elem.clear()
        elif elem.tag == "relation":
            elem.clear()

    return {
        "path": str(path),
        "sha256": sha256(path) if path.exists() else "",
        "node_count": len(nodes),
        "building_count": len(buildings),
        "duplicate_way_ids": duplicates,
        "missing_node_refs": missing_nodes,
        "invalid_rings": invalid_rings,
        "building_tag_values": dict(building_vals.most_common()),
        "tag_keys_on_buildings": dict(all_tag_keys.most_common()),
        "buildings": buildings,
    }


def percentile(sorted_vals: list[float], p: float) -> float:
    if not sorted_vals:
        return 0.0
    if len(sorted_vals) == 1:
        return sorted_vals[0]
    k = (len(sorted_vals) - 1) * p
    f = math.floor(k)
    c = math.ceil(k)
    if f == c:
        return sorted_vals[int(k)]
    return sorted_vals[f] * (c - k) + sorted_vals[c] * (k - f)


def geometry_stats(buildings: list[dict]) -> dict:
    areas = sorted(b["area_m2"] for b in buildings if b["geom_ok"])
    spans = [(b["span_x"], b["span_z"]) for b in buildings if b["geom_ok"]]
    verts = Counter(b["vertices"] for b in buildings if b["geom_ok"])
    with_levels = [b for b in buildings if b["building_levels"]]
    with_height = [b for b in buildings if b["height"]]
    with_name = [b for b in buildings if b["name"]]
    with_roof = [b for b in buildings if b["roof_shape"] or b["roof_levels"]]
    cats = Counter(b["category"] for b in buildings)
    bands = Counter(b["area_band"] for b in buildings)
    level_vals = Counter(b["building_levels"] for b in with_levels)
    return {
        "geom_ok": len(areas),
        "geom_invalid": sum(1 for b in buildings if not b["geom_ok"]),
        "area_min": areas[0] if areas else 0,
        "area_max": areas[-1] if areas else 0,
        "area_mean": round(sum(areas) / len(areas), 2) if areas else 0,
        "area_median": round(percentile(areas, 0.5), 2),
        "area_p10": round(percentile(areas, 0.1), 2),
        "area_p25": round(percentile(areas, 0.25), 2),
        "area_p75": round(percentile(areas, 0.75), 2),
        "area_p90": round(percentile(areas, 0.9), 2),
        "typical_span_x_median": round(percentile(sorted(s[0] for s in spans), 0.5), 2) if spans else 0,
        "typical_span_z_median": round(percentile(sorted(s[1] for s in spans), 0.5), 2) if spans else 0,
        "vertex_histogram": dict(sorted(verts.items())),
        "quad_count": sum(1 for b in buildings if b["geom_ok"] and b["vertices"] == 4),
        "non_quad_count": sum(1 for b in buildings if b["geom_ok"] and b["vertices"] != 4),
        "named_count": len(with_name),
        "levels_count": len(with_levels),
        "levels_pct": round(100.0 * len(with_levels) / max(len(buildings), 1), 3),
        "height_count": len(with_height),
        "height_pct": round(100.0 * len(with_height) / max(len(buildings), 1), 3),
        "unknown_height_pct": round(100.0 * (len(buildings) - len(with_height)) / max(len(buildings), 1), 3),
        "roof_tag_count": len(with_roof),
        "level_values": dict(level_vals),
        "categories": dict(cats.most_common()),
        "area_bands": dict(bands.most_common()),
        "named_buildings": [
            {
                "osm_id": b["osm_id"],
                "name": b["name"],
                "building": b["building"],
                "category": b["category"],
                "area_m2": b["area_m2"],
                "building_levels": b["building_levels"],
                "shop": b["shop"],
                "amenity": b["amenity"],
                "office": b["office"],
                "cx": b["cx"],
                "cz": b["cz"],
                "dist_spawn_m": b["dist_spawn_m"],
            }
            for b in sorted(with_name, key=lambda r: r["name"].lower())
        ],
        "levels_buildings": [
            {
                "osm_id": b["osm_id"],
                "name": b["name"],
                "building": b["building"],
                "building_levels": b["building_levels"],
                "area_m2": b["area_m2"],
                "category": b["category"],
            }
            for b in with_levels
        ],
    }


def blosm_correspondence(city_ids: set[str]) -> dict:
    if not MANIFEST.exists():
        return {"error": "building_manifest.json missing"}
    rows = json.loads(MANIFEST.read_text(encoding="utf-8"))
    status = Counter(r.get("status", "") for r in rows)
    man_ids = {str(r["osm_id"]) for r in rows}
    exported = [r for r in rows if r.get("status") == "exported"]
    missing = [r for r in rows if r.get("status") == "no_confident_triangles"]
    export_info = {}
    if EXPORT_MANIFEST.exists():
        export_info = json.loads(EXPORT_MANIFEST.read_text(encoding="utf-8"))
    unresolved_tris = None
    if isinstance(export_info, dict):
        unresolved_tris = export_info.get("unresolved_triangles") or export_info.get("unresolved")
        if unresolved_tris is None and "triangle_assignment" in export_info:
            unresolved_tris = export_info["triangle_assignment"].get("unresolved")
    return {
        "manifest_rows": len(rows),
        "status_counts": dict(status),
        "matched_exported": len(exported),
        "no_confident_triangles": len(missing),
        "ids_in_osm_not_manifest": sorted(city_ids - man_ids)[:50],
        "ids_in_manifest_not_osm": sorted(man_ids - city_ids)[:50],
        "osm_manifest_id_sets_equal": city_ids == man_ids,
        "production_glb_has_way_ids": False,
        "production_glb_nodes": ["dhule_city.osm_buildings", "dhule_city.osm_water"],
        "note": "Correspondence comes from partition rule (0.20 m). Production GLB stores no per-building extras.",
        "export_manifest_keys": sorted(export_info.keys()) if isinstance(export_info, dict) else [],
        "export_manifest_summary": {
            k: export_info.get(k)
            for k in (
                "assigned_triangles",
                "unresolved_triangles",
                "source_building_triangles",
                "exported_ids",
                "sha256_glb",
                "sha256_osm",
            )
            if isinstance(export_info, dict) and k in export_info
        },
        "no_confident_sample": [
            {"osm_id": r["osm_id"], "godot_x": r.get("godot_x"), "godot_z": r.get("godot_z")}
            for r in missing[:12]
        ],
        "prior_docs": {
            "assigned_triangles": 20329,
            "unresolved_triangles": 4922,
            "source_building_triangles": 25251,
            "matched_ids": 1730,
            "no_confident_ids": 136,
        },
    }


def read_glb_info(path: Path) -> dict:
    data = path.read_bytes()
    info = {
        "path": str(path.relative_to(ROOT)).replace("\\", "/"),
        "bytes": len(data),
        "ok": False,
        "meshes": 0,
        "nodes": 0,
        "materials": 0,
        "textures": 0,
        "images": 0,
        "size_m": None,
        "origin": None,
        "generator": "",
        "title": "",
        "license": "",
        "error": "",
    }
    try:
        if data[:4] != b"glTF":
            info["error"] = "not_glb"
            return info
        json_len = struct.unpack_from("<I", data, 12)[0]
        js = json.loads(data[20 : 20 + json_len])
        info["ok"] = True
        info["meshes"] = len(js.get("meshes", []))
        info["nodes"] = len(js.get("nodes", []))
        info["materials"] = len(js.get("materials", []))
        info["textures"] = len(js.get("textures", []))
        info["images"] = len(js.get("images", []))
        asset = js.get("asset", {})
        info["generator"] = str(asset.get("generator", ""))
        extras = asset.get("extras") or {}
        info["title"] = str(extras.get("title", ""))
        info["license"] = str(extras.get("license", extras.get("source", "")))
        mins = []
        maxs = []
        for mesh in js.get("meshes", []):
            for prim in mesh.get("primitives", []):
                pos = prim.get("attributes", {}).get("POSITION")
                if pos is None:
                    continue
                acc = js["accessors"][pos]
                if "min" in acc and "max" in acc:
                    mins.append(acc["min"])
                    maxs.append(acc["max"])
        if mins and maxs:
            mn = [min(m[i] for m in mins) for i in range(3)]
            mx = [max(m[i] for m in maxs) for i in range(3)]
            info["size_m"] = [round(mx[i] - mn[i], 4) for i in range(3)]
            info["origin"] = {
                "min": [round(v, 4) for v in mn],
                "max": [round(v, 4) for v in mx],
                "center": [round((mn[i] + mx[i]) * 0.5, 4) for i in range(3)],
            }
    except Exception as exc:  # noqa: BLE001 — audit must continue
        info["error"] = str(exc)
    return info


def classify_asset(path: Path, info: dict) -> dict:
    rel = path.as_posix().lower()
    name = path.name.lower()
    category = "unknown"
    role = "unknown"
    complete_building = False
    suitable_for_osm_footprints = "no"
    notes = []

    if "dhule_blosm_city" in name:
        category = "city_mesh"
        role = "production_joined_city"
        notes.append("Joined Blosm walls+roofs; no per-way ids.")
    elif "dhule_blosm" in name or "dhule_block" in name or "mumbai_city" in name or "city_map" in name:
        category = "city_or_block_mesh"
        role = "reference_or_incoming"
        notes.append("Not a single OSM footprint asset.")
    elif "junction" in name or "streetscape" in name:
        category = "streetscape"
        role = "environment_set"
    elif "bhelpuri" in name or "shop" in name:
        category = "commercial_shop_prop"
        role = "complete_shop_cart_or_stall"
        complete_building = True
        suitable_for_osm_footprints = "limited_small_footprints_only"
        notes.append("Normalized as cart/stall, not a full plot building.")
    elif "indian_house" in name or ("house" in name and "building" in rel):
        category = "residential_house"
        role = "complete_building"
        complete_building = True
        suitable_for_osm_footprints = "candidate_with_fitter"
        notes.append("Requires footprint fitter + road clearance (Phase 2F).")
    elif "architecture" in rel:
        category = "architecture_prototype"
        role = "detailed_replacement_mesh"
        complete_building = True
        suitable_for_osm_footprints = "matched_ids_only"
    elif any(k in rel for k in ("vehicle", "autorickshaw", "bus", "safari", "camry", "carnival", "truck")):
        category = "vehicle_not_building"
        role = "vehicle"
    elif any(k in rel for k in ("road", "avenue", "sidewalk", "barrier", "planter", "street_light", "bus_stop", "props")):
        category = "street_prop_or_road"
        role = "non_building"
    else:
        category = "other_asset"
        role = "review"

    size = info.get("size_m") or [0, 0, 0]
    plan = max(size[0], size[2]) if size else 0
    height = size[1] if size else 0
    if complete_building and plan > 40:
        notes.append("Plan span large vs typical Dhule house (~8–12 m); check scale.")
    if complete_building and 2.0 <= height <= 12.0 and 3.0 <= plan <= 25.0:
        if suitable_for_osm_footprints.startswith("no"):
            suitable_for_osm_footprints = "candidate_with_fitter"

    return {
        **info,
        "filename": path.name,
        "asset_category": category,
        "asset_role": role,
        "complete_building": complete_building,
        "suitable_for_osm_footprints": suitable_for_osm_footprints,
        "notes": "; ".join(notes),
    }


def inventory_glbs() -> list[dict]:
    roots = [
        ROOT / "assets" / "kit" / "buildings",
        ROOT / "assets" / "models" / "buildings",
        ROOT / "assets" / "models" / "environments",
        ROOT / "assets" / "prototypes",
        ROOT / "assets" / "incoming",
        ROOT / "assets" / "maps",
    ]
    # Also architecture exports if present (not imported by Godot).
    arch = ROOT / "blender_work" / "dhule_architecture" / "export"
    if arch.exists():
        roots.append(arch)
    seen: set[Path] = set()
    rows: list[dict] = []
    for base in roots:
        if not base.exists():
            continue
        for path in sorted(base.rglob("*.glb")):
            # Skip partition per-id archive (thousands of files); summarize separately.
            if "dhule_city_pipeline" in path.as_posix() and "/buildings/" in path.as_posix().replace("\\", "/"):
                continue
            rp = path.resolve()
            if rp in seen:
                continue
            seen.add(rp)
            # Prefer building-related paths; still list environments and incoming city meshes.
            rel = path.as_posix().lower()
            buildingish = any(
                k in rel
                for k in (
                    "/buildings/",
                    "house",
                    "shop",
                    "blosm",
                    "architecture",
                    "junction",
                    "city_map",
                    "mumbai_city",
                    "dhule_block",
                )
            )
            if not buildingish and base.name in {"incoming", "maps"}:
                # incoming has many vehicles/roads — only keep if name suggests building/city.
                if not any(k in path.name.lower() for k in ("house", "shop", "building", "city", "block", "junction")):
                    continue
            info = read_glb_info(path)
            rows.append(classify_asset(path, info))
    return rows


def game_json_buildings() -> dict:
    data = json.loads(GAME_JSON.read_text(encoding="utf-8"))
    buildings = data.get("buildings", [])
    kinds = Counter(str(b.get("kind", "")) for b in buildings)
    named = [b for b in buildings if b.get("name")]
    return {
        "count": len(buildings),
        "kinds": dict(kinds.most_common()),
        "named_count": len(named),
        "format": "axis-aligned boxes {id,kind,name,x,z,w,d,h} — not OSM rings",
        "origin_lat": data.get("origin_lat"),
        "origin_lon": data.get("origin_lon"),
        "spawn": data.get("spawn"),
        "note": "Playable JSON boxes cannot drive irregular footprints; prototypes read OSM rings.",
    }


def write_csv(path: Path, rows: list[dict], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [",".join(fields)]
    for r in rows:
        vals = []
        for f in fields:
            v = r.get(f, "")
            if isinstance(v, (list, dict)):
                v = json.dumps(v, ensure_ascii=False)
            s = str(v).replace('"', '""')
            if any(c in s for c in ",\n\r\""):
                s = f'"{s}"'
            vals.append(s)
        lines.append(",".join(vals))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    city = load_osm(CITY_OSM)
    mmap = load_osm(MAP_OSM)
    city_stats = geometry_stats(city["buildings"])
    map_stats = geometry_stats(mmap["buildings"])
    city_ids = {b["osm_id"] for b in city["buildings"]}
    map_ids = {b["osm_id"] for b in mmap["buildings"]}
    blosm = blosm_correspondence(city_ids)
    assets = inventory_glbs()
    game = game_json_buildings()

    # Partition archive count (not imported).
    archive_dir = ROOT / "blender_work" / "dhule_city_pipeline" / "export" / "buildings"
    archive_count = len(list(archive_dir.glob("*.glb"))) if archive_dir.exists() else 0

    blosm_hash = sha256(BLOSM_GLB) if BLOSM_GLB.exists() else ""
    report = {
        "phase": "2H.1",
        "projection": {
            "lat0": LAT0,
            "lon0": LON0,
            "m_per_deg_lat": M_LAT,
            "m_per_deg_lon": round(M_LON, 6),
            "x": "east",
            "z": "south",
            "spawn_xz": list(SPAWN),
        },
        "sources": {
            "dhule_city.osm": {
                "sha256": city["sha256"],
                "node_count": city["node_count"],
                "building_count": city["building_count"],
                "duplicate_way_ids": city["duplicate_way_ids"],
                "missing_node_refs": city["missing_node_refs"],
                "invalid_rings": city["invalid_rings"],
                "building_tag_values": city["building_tag_values"],
                "tag_keys_on_buildings": city["tag_keys_on_buildings"],
            },
            "dhulemap.osm": {
                "sha256": mmap["sha256"],
                "node_count": mmap["node_count"],
                "building_count": mmap["building_count"],
                "duplicate_way_ids": mmap["duplicate_way_ids"],
                "missing_node_refs": mmap["missing_node_refs"],
                "invalid_rings": mmap["invalid_rings"],
                "building_tag_values": mmap["building_tag_values"],
                "tag_keys_on_buildings": mmap["tag_keys_on_buildings"],
                "ids_also_in_city": len(map_ids & city_ids),
                "ids_only_in_map": len(map_ids - city_ids),
                "ids_only_in_city": len(city_ids - map_ids),
            },
            "dhule_roads_game.json_buildings": game,
            "dhule_blosm_city.glb": {
                "sha256": blosm_hash,
                "bytes": BLOSM_GLB.stat().st_size if BLOSM_GLB.exists() else 0,
            },
        },
        "dhule_city_geometry": city_stats,
        "dhulemap_geometry": map_stats,
        "blosm_correspondence": blosm,
        "partition_archive_glb_count": archive_count,
        "asset_inventory": assets,
        "asset_summary": {
            "count": len(assets),
            "by_category": dict(Counter(a["asset_category"] for a in assets).most_common()),
            "complete_buildings": sum(1 for a in assets if a["complete_building"]),
            "candidate_fitters": sum(
                1 for a in assets if "candidate" in a["suitable_for_osm_footprints"] or a["suitable_for_osm_footprints"] == "matched_ids_only"
            ),
        },
        "validation": {
            "city_building_count_reproducible_expected": 1866,
            "city_building_count_actual": city["building_count"],
            "duplicate_ids_city": len(city["duplicate_way_ids"]),
            "missing_nodes_city": city["missing_node_refs"],
            "invalid_rings_city": city["invalid_rings"],
            "manifest_matches_city_ids": blosm.get("osm_manifest_id_sets_equal"),
            "source_files_unchanged_policy": "audit read-only; no writes to OSM/GLB/JSON production paths",
        },
    }

    # Strip heavy tag dicts from CSV rows.
    csv_rows = []
    for b in city["buildings"]:
        csv_rows.append({k: b[k] for k in b if k != "tags"})
    write_csv(
        OUT_CSV,
        csv_rows,
        [
            "osm_id", "source", "vertices", "area_m2", "span_x", "span_z", "cx", "cz",
            "building", "building_levels", "height", "roof_shape", "roof_levels",
            "name", "shop", "amenity", "office", "industrial", "category", "area_band",
            "geom_ok", "dist_spawn_m",
        ],
    )
    write_csv(
        OUT_NAMED,
        city_stats["named_buildings"],
        [
            "osm_id", "name", "building", "category", "area_m2", "building_levels",
            "shop", "amenity", "office", "cx", "cz", "dist_spawn_m",
        ],
    )
    write_csv(
        OUT_ASSETS,
        assets,
        [
            "filename", "path", "bytes", "asset_category", "asset_role", "complete_building",
            "suitable_for_osm_footprints", "meshes", "materials", "textures", "images",
            "size_m", "generator", "title", "notes", "error",
        ],
    )

    # Compact JSON: drop per-building poly payloads (already in CSV).
    slim = dict(report)
    OUT_JSON.write_text(json.dumps(slim, indent=2), encoding="utf-8")

    print("AUDIT_OK city_buildings", city["building_count"])
    print("AUDIT_OK map_buildings", mmap["building_count"])
    print("AUDIT_OK categories", json.dumps(city_stats["categories"]))
    print("AUDIT_OK area_median", city_stats["area_median"], "max", city_stats["area_max"])
    print("AUDIT_OK levels", city_stats["levels_count"], "height", city_stats["height_count"], "named", city_stats["named_count"])
    print("AUDIT_OK blosm matched", blosm.get("matched_exported"), "no_confident", blosm.get("no_confident_triangles"))
    print("AUDIT_OK assets", len(assets), "complete", slim["asset_summary"]["complete_buildings"])
    print("AUDIT_OK wrote", OUT_JSON)


if __name__ == "__main__":
    main()
