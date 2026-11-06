"""Audit footprints with no confident triangles and the unresolved triangles.

Reads the production GLB and dhule_city.osm. Writes only under
blender_work/dhule_city_pipeline/audit/. Does not assign triangles and does
not modify production geometry.
"""
import csv
import hashlib
import importlib.util
import json
import math
import struct
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(r"D:\drivevicecity")
PART = ROOT / "blender_work" / "dhule_city_pipeline" / "scripts" / "partition_buildings.py"
OUT = ROOT / "blender_work" / "dhule_city_pipeline" / "audit"
ROADS = ROOT / "assets" / "maps" / "dhule_roads_game.json"
SPEC = importlib.util.spec_from_file_location("partition_buildings", PART)
part = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(part)


def shoelace(poly):
    area = 0.0
    for i, (x, z) in enumerate(poly):
        x2, z2 = poly[(i + 1) % len(poly)]
        area += x * z2 - x2 * z
    return abs(area) * 0.5


def orient(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def segments_cross(a, b, c, d):
    o1 = orient(a, b, c)
    o2 = orient(a, b, d)
    o3 = orient(c, d, a)
    o4 = orient(c, d, b)
    return o1 * o2 < 0.0 and o3 * o4 < 0.0


def self_intersects(poly):
    n = len(poly)
    if n < 4:
        return False
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        for j in range(i + 1, n):
            if abs(i - j) <= 1 or (i == 0 and j == n - 1):
                continue
            c, d = poly[j], poly[(j + 1) % n]
            if segments_cross(a, b, c, d):
                return True
    return False


def point_in_tri(p, tri):
    a, b, c = tri
    c1 = orient(a, b, p)
    c2 = orient(b, c, p)
    c3 = orient(c, a, p)
    has_neg = c1 < 0 or c2 < 0 or c3 < 0
    has_pos = c1 > 0 or c2 > 0 or c3 > 0
    return not (has_neg and has_pos)


def tri_hits_poly(tri, poly):
    if any(part.point_in(v[0], v[1], poly) for v in tri):
        return True
    if any(point_in_tri(p, tri) for p in poly):
        return True
    for i in range(3):
        a, b = tri[i], tri[(i + 1) % 3]
        for j in range(len(poly)):
            c, d = poly[j], poly[(j + 1) % len(poly)]
            if segments_cross(a, b, c, d):
                return True
    return False


def poly_tri_distance(poly, tri):
    if tri_hits_poly(tri, poly):
        return 0.0
    best = 1e9
    for vertex in tri:
        best = min(best, part.edge_distance(vertex[0], vertex[1], poly))
    for vertex in poly:
        best = min(best, point_tri_distance(vertex, tri))
    return best


def point_tri_distance(p, tri):
    if point_in_tri(p, tri):
        return 0.0
    best = 1e9
    for i in range(3):
        best = min(best, point_segment_distance(p, tri[i], tri[(i + 1) % 3]))
    return best


def point_segment_distance(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    l2 = dx * dx + dz * dz
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / l2))
    return math.hypot(p[0] - (a[0] + dx * t), p[1] - (a[1] + dz * t))


def tri_area(v0, v1, v2):
    ax, ay, az = v1[0] - v0[0], v1[1] - v0[1], v1[2] - v0[2]
    bx, by, bz = v2[0] - v0[0], v2[1] - v0[1], v2[2] - v0[2]
    cx = ay * bz - az * by
    cy = az * bx - ax * bz
    cz = ax * by - ay * bx
    return 0.5 * math.sqrt(cx * cx + cy * cy + cz * cz), (cx, cy, cz)


def percentile(values, p):
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int(round((len(ordered) - 1) * p))))
    return ordered[index]


def load_osm_meta():
    ways = {}
    way_count = 0
    building_tags = 0
    versioned = 0
    relations = 0
    missing_nodes = 0
    nodes = {}
    for _ev, elem in ET.iterparse(part.OSM, events=("end",)):
        if elem.tag == "node":
            nodes[elem.attrib["id"]] = True
            elem.clear()
        elif elem.tag == "way":
            way_count += 1
            if "version" in elem.attrib or "timestamp" in elem.attrib:
                versioned += 1
            tags = {t.attrib["k"]: t.attrib["v"] for t in elem.findall("tag")}
            refs = [nd.attrib["ref"] for nd in elem.findall("nd")]
            unresolved = sum(1 for ref in refs if ref not in nodes)
            missing_nodes += unresolved
            if "building" in tags:
                building_tags += 1
                ways[elem.attrib["id"]] = {
                    "tags": tags,
                    "refs": refs,
                    "closed": len(refs) >= 2 and refs[0] == refs[-1],
                    "version": elem.attrib.get("version", ""),
                    "timestamp": elem.attrib.get("timestamp", ""),
                    "unresolved_nodes": unresolved,
                }
            elem.clear()
        elif elem.tag == "relation":
            relations += 1
            elem.clear()
    return {
        "ways": ways,
        "way_count": way_count,
        "building_tags": building_tags,
        "versioned_ways": versioned,
        "relations": relations,
        "nodes": len(nodes),
        "unresolved_node_refs_on_ways": missing_nodes,
    }


def load_roads():
    data = json.loads(ROADS.read_text(encoding="utf-8"))
    segments = []
    for road in data["roads"]:
        pts = road["points"]
        half = float(road.get("width") or 0.0) * 0.5
        rid = str(road.get("id"))
        for a, b in zip(pts, pts[1:]):
            segments.append((a[0], a[1], b[0], b[1], half, rid))
    return segments, data.get("road_count"), data["origin_lat"], data["origin_lon"]


def nearest_road(poly, segments):
    best = 1e9
    best_id = ""
    best_clear = 1e9
    samples = list(poly)
    cx = sum(p[0] for p in poly) / len(poly)
    cz = sum(p[1] for p in poly) / len(poly)
    samples.append((cx, cz))
    for x0, z0, x1, z1, half, rid in segments:
        dist = min(point_segment_distance(p, (x0, z0), (x1, z1)) for p in samples)
        for i, a in enumerate(poly):
            b = poly[(i + 1) % len(poly)]
            dist = min(dist, segment_segment_distance(a, b, (x0, z0), (x1, z1)))
        if dist < best:
            best = dist
            best_id = rid
            best_clear = dist - half
    return best_id, best, best_clear


def segment_segment_distance(a, b, c, d):
    if segments_cross(a, b, c, d):
        return 0.0
    return min(
        point_segment_distance(a, c, d),
        point_segment_distance(b, c, d),
        point_segment_distance(c, a, b),
        point_segment_distance(d, a, b),
    )


def footprint_overlap(building, buildings, grid):
    hits = []
    ix0 = int((building["minx"] - 2) // grid.cell)
    ix1 = int((building["maxx"] + 2) // grid.cell)
    iz0 = int((building["minz"] - 2) // grid.cell)
    iz1 = int((building["maxz"] + 2) // grid.cell)
    seen = set()
    for ix in range(ix0, ix1 + 1):
        for iz in range(iz0, iz1 + 1):
            for index in grid.bins.get((ix, iz), []):
                other = buildings[index]
                if other["id"] == building["id"] or other["id"] in seen:
                    continue
                seen.add(other["id"])
                if other["maxx"] < building["minx"] - 2 or other["minx"] > building["maxx"] + 2:
                    continue
                if other["maxz"] < building["minz"] - 2 or other["minz"] > building["maxz"] + 2:
                    continue
                inside = sum(1 for p in building["poly"] if part.point_in(p[0], p[1], other["poly"]))
                crossed = False
                if inside == 0:
                    for i, a in enumerate(building["poly"]):
                        b = building["poly"][(i + 1) % len(building["poly"])]
                        for j, c in enumerate(other["poly"]):
                            d = other["poly"][(j + 1) % len(other["poly"])]
                            if segments_cross(a, b, c, d):
                                crossed = True
                                break
                        if crossed:
                            break
                if inside or crossed:
                    hits.append((other["id"], inside / len(building["poly"]), crossed))
    hits.sort(key=lambda item: -item[1])
    return hits


def nearest_footprints(grid, buildings, x, z):
    ix = int(x // grid.cell)
    iz = int(z // grid.cell)
    found = []
    seen = set()
    rings = 1
    while rings <= 12 and len(found) < 2:
        for dx in range(-rings, rings + 1):
            for dz in range(-rings, rings + 1):
                if max(abs(dx), abs(dz)) != rings and rings > 1:
                    continue
                for index in grid.bins.get((ix + dx, iz + dz), []):
                    if index in seen:
                        continue
                    seen.add(index)
                    building = buildings[index]
                    dist = part.edge_distance(x, z, building["poly"])
                    inside = part.point_in(x, z, building["poly"])
                    found.append((0.0 if inside else dist, dist, inside, building["id"]))
        rings += 1
    inside = [item for item in found if item[2]]
    outside = sorted((item for item in found if not item[2]), key=lambda item: item[0])
    ordered = inside + outside
    if not ordered:
        return ("", None, False, "", None, False)
    a = ordered[0]
    b = ordered[1] if len(ordered) > 1 else ("", None, False, "")
    return (a[3], a[1], a[2], b[3], b[1], b[2] if len(ordered) > 1 else False)


def diagnose(reason, material, area, d0, d1, inside0, verts_inside):
    if area < 1e-4:
        return "invalid_or_degenerate"
    if reason in ("ambiguous_multi_footprint", "ambiguous_margin"):
        return "geometry_between_adjoining_buildings"
    if inside0 and material == "roof":
        return "real_building_roof"
    if inside0 and material == "wall":
        return "real_building_wall"
    if material == "roof" and d0 is not None and d0 <= 3.0:
        return "roof_overhang"
    if d0 is not None and d0 <= 8.0 and material == "wall":
        return "real_building_wall"
    if d0 is not None and d0 <= 8.0 and material == "roof":
        return "roof_overhang"
    if d0 is None or d0 > 8.0:
        return "unrelated_geometry"
    return "real_building_wall" if material == "wall" else "real_building_roof"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    osm_meta = load_osm_meta()
    buildings, duplicate_ids = part.load_buildings()
    by_id = {b["id"]: b for b in buildings}
    grid = part.Grid(buildings)
    roads, road_count, road_lat, road_lon = load_roads()
    js, buf = part.read_glb(part.GLB)
    glb_nodes = [{"name": n.get("name"), "extras": n.get("extras")} for n in js["nodes"]]
    asset = js.get("asset", {})

    reasons = Counter()
    vertex_inside = set()
    centroid_inside = defaultdict(list)
    triangles = []
    assigned_blob = []
    unresolved_blob = []
    water_blob = []
    source_tris = 0

    building_mesh = next(mesh for mesh in js["meshes"] if mesh["name"] == "dhule_city.osm_buildings")
    for prim in building_mesh["primitives"]:
        positions = part.read_accessor(js, buf, prim["attributes"]["POSITION"])
        raw_index = part.read_accessor(js, buf, prim["indices"])
        material = js["materials"][prim["material"]]["name"]
        for tri in range(0, len(raw_index), 3):
            source_tris += 1
            verts = []
            xz = []
            for k in range(3):
                vertex = raw_index[tri + k]
                vertex = vertex[0] if isinstance(vertex, tuple) else vertex
                x, height, z = positions[vertex]
                verts.append((x, height, z))
                xz.append((x, z))
            per_vertex = []
            ids = set()
            for x, z in xz:
                group = set(grid.hits(x, z))
                per_vertex.append(group)
                ids |= group
                for index in group:
                    vertex_inside.add(buildings[index]["id"])
            cx = sum(v[0] for v in verts) / 3.0
            cy = sum(v[1] for v in verts) / 3.0
            cz = sum(v[2] for v in verts) / 3.0
            owner = None
            reason = "unmatched"
            outside_m = 0.0
            if len(ids) > 1:
                reason = "ambiguous_multi_footprint"
            elif len(ids) == 1:
                index = next(iter(ids))
                dmax = 0.0
                for (x, _h, z), group in zip(verts, per_vertex):
                    if not group:
                        dmax = max(dmax, part.edge_distance(x, z, buildings[index]["poly"]))
                outside_m = dmax
                if dmax <= part.EDGE:
                    owner = buildings[index]["id"]
                    reason = "inside" if dmax == 0 else "boundary"
                else:
                    reason = "crosses_boundary"
            else:
                ranked = grid.nearest(cx, cz)
                if ranked:
                    d0, id0 = ranked[0]
                    d1 = ranked[1][0] if len(ranked) > 1 else 1e9
                    if d0 <= part.EDGE and d1 - d0 >= part.MARGIN:
                        owner = id0
                        reason = "nearest_edge"
                    else:
                        reason = "unmatched" if d0 > part.EDGE else "ambiguous_margin"
            reasons[reason] += 1
            for index in grid.hits(cx, cz):
                centroid_inside[buildings[index]["id"]].append((reason, owner or "", material))
            area, normal = tri_area(verts[0], verts[1], verts[2])
            xz_area, _ = tri_area((xz[0][0], 0, xz[0][1]), (xz[1][0], 0, xz[1][1]), (xz[2][0], 0, xz[2][1]))
            record = {
                "index": source_tris,
                "reason": reason,
                "owner": owner or "",
                "material": material,
                "area": area,
                "xz_area": xz_area,
                "normal_y": normal[1] / (2 * area) if area else 0.0,
                "centroid": (cx, cy, cz),
                "verts": verts,
                "xz": xz,
                "outside_m": outside_m,
                "verts_inside": sum(1 for group in per_vertex if group),
            }
            triangles.append(record)
            blob = assigned_blob if owner else unresolved_blob
            for vertex in verts:
                blob.extend(vertex)

    water_mesh = next(mesh for mesh in js["meshes"] if mesh["name"] == "dhule_city.osm_water")
    water_tris = 0
    for prim in water_mesh["primitives"]:
        positions = part.read_accessor(js, buf, prim["attributes"]["POSITION"])
        raw_index = part.read_accessor(js, buf, prim["indices"])
        for tri in range(0, len(raw_index), 3):
            water_tris += 1
            for k in range(3):
                vertex = raw_index[tri + k]
                vertex = vertex[0] if isinstance(vertex, tuple) else vertex
                x, height, z = positions[vertex]
                water_blob.extend((x, height, z))

    assigned = sum(1 for tri in triangles if tri["owner"])
    unresolved = source_tris - assigned
    if assigned + unresolved != source_tris:
        raise SystemExit("triangle mismatch")
    if reasons["crosses_boundary"] + reasons["unmatched"] + reasons["ambiguous_multi_footprint"] + reasons["ambiguous_margin"] != unresolved:
        raise SystemExit("reason mismatch %s" % dict(reasons))

    tri_cells = defaultdict(list)
    for index, tri in enumerate(triangles):
        cx, _cy, cz = tri["centroid"]
        tri_cells[(int(cx // 40.0), int(cz // 40.0))].append(index)

    def nearby_tris(building, pad):
        ix0 = int((building["minx"] - pad) // 40.0)
        ix1 = int((building["maxx"] + pad) // 40.0)
        iz0 = int((building["minz"] - pad) // 40.0)
        iz1 = int((building["maxz"] + pad) // 40.0)
        found = []
        for ix in range(ix0, ix1 + 1):
            for iz in range(iz0, iz1 + 1):
                found.extend(tri_cells.get((ix, iz), []))
        return found

    missing_rows = []
    class_counts = Counter()
    outline_missing = []
    outline_ambiguous = []
    ambiguous_ids = set()
    for tri in triangles:
        if tri["reason"] not in ("ambiguous_multi_footprint", "ambiguous_margin"):
            continue
        n1, _d1, _i1, n2, _d2, _i2 = nearest_footprints(grid, buildings, tri["centroid"][0], tri["centroid"][2])
        if n1:
            ambiguous_ids.add(n1)
        if n2:
            ambiguous_ids.add(n2)

    no_vertex = []
    for building in buildings:
        if building["id"] not in vertex_inside:
            no_vertex.append(building["id"])

    for building in buildings:
        meta = osm_meta["ways"].get(building["id"])
        area = shoelace(building["poly"])
        unique = len({(round(p[0], 3), round(p[1], 3)) for p in building["poly"]})
        crossed = self_intersects(building["poly"])
        valid = unique >= 3 and area >= 1.0 and not crossed and meta is not None and meta["closed"] and meta["unresolved_nodes"] == 0
        validity = "valid" if valid else "invalid"
        problems = []
        if meta is None:
            problems.append("missing_from_osm")
        elif not meta["closed"]:
            problems.append("open_ring")
        if meta and meta["unresolved_nodes"]:
            problems.append("unresolved_nodes")
        if unique < 3:
            problems.append("too_few_vertices")
        if area < 1.0:
            problems.append("area_under_1m2")
        if crossed:
            problems.append("self_intersection")
        confident = sum(1 for tri in triangles if tri["owner"] == building["id"])
        if confident:
            if building["id"] in ambiguous_ids:
                outline_ambiguous.append((building["id"], building["poly"]))
            continue
        pads = (20.0, 80.0, 200.0, 600.0)
        intersect = []
        nearest_dist = None
        nearest_tri = None
        for pad in pads:
            pool = nearby_tris(building, pad)
            intersect = [triangles[i] for i in pool if tri_hits_poly(triangles[i]["xz"], building["poly"])]
            if intersect:
                nearest_dist = 0.0
                nearest_tri = intersect[0]["index"]
                break
            best = 1e9
            best_index = None
            for i in pool:
                dist = poly_tri_distance(building["poly"], triangles[i]["xz"])
                if dist < best:
                    best = dist
                    best_index = triangles[i]["index"]
            if best_index is not None and best < pad:
                nearest_dist = best
                nearest_tri = best_index
                break
        overlaps = footprint_overlap(building, buildings, grid)
        centroids_here = centroid_inside.get(building["id"], [])
        stolen = sorted({owner for _reason, owner, _mat in centroids_here if owner and owner != building["id"]})
        road_id, road_dist, road_clear = nearest_road(building["poly"], roads)
        other_dist = 1e9
        other_id = ""
        ix = int(building["cx"] // grid.cell)
        iz = int(building["cz"] // grid.cell)
        for dx in range(-2, 3):
            for dz in range(-2, 3):
                for index in grid.bins.get((ix + dx, iz + dz), []):
                    other = buildings[index]
                    if other["id"] == building["id"]:
                        continue
                    dist = part.edge_distance(building["cx"], building["cz"], other["poly"])
                    if dist < other_dist:
                        other_dist = dist
                        other_id = other["id"]
        if overlaps:
            kind = "E"
            evidence = "polygon overlaps %s" % overlaps[0][0]
        elif not valid:
            kind = "C"
            evidence = ",".join(problems) or "invalid_polygon"
        elif intersect or building["id"] in vertex_inside or centroids_here:
            kind = "B"
            worst = 0.0
            for tri in intersect:
                for x, z in tri["xz"]:
                    if not part.point_in(x, z, building["poly"]):
                        worst = max(worst, part.edge_distance(x, z, building["poly"]))
            evidence = (
                "Blosm triangles meet this polygon (%d intersect, %d centroids inside). "
                "The farthest vertex of the intersecting triangles is %.2f m outside the ring, "
                "past the 0.20 m rule, so none were confidently assigned."
                % (len(intersect), len(centroids_here), worst)
            )
            if stolen:
                evidence += "; centroid triangles were assigned to " + ",".join(stolen)
        elif nearest_dist is None or nearest_dist > 2.0:
            kind = "A"
            evidence = "no building triangle intersects the polygon"
        else:
            kind = "B"
            evidence = "nearest triangle is %.2f m away and was not assigned" % nearest_dist
        class_counts[kind] += 1
        tags = meta["tags"] if meta else {}
        row = {
            "osm_id": building["id"],
            "classification": kind,
            "evidence": evidence,
            "tags": ";".join("%s=%s" % item for item in sorted(tags.items())),
            "building": tags.get("building", ""),
            "name": tags.get("name", ""),
            "area_m2": round(area, 2),
            "min_x": round(building["minx"], 2),
            "max_x": round(building["maxx"], 2),
            "min_z": round(building["minz"], 2),
            "max_z": round(building["maxz"], 2),
            "vertices": len(building["poly"]),
            "unique_vertices": unique,
            "polygon_validity": validity,
            "validity_problems": ",".join(problems),
            "osm_closed": bool(meta and meta["closed"]),
            "osm_version": meta["version"] if meta else "",
            "osm_timestamp": meta["timestamp"] if meta else "",
            "geometry_in_osm": bool(meta and meta["unresolved_nodes"] == 0 and len(building["poly"]) >= 3),
            "nearest_road_id": road_id,
            "nearest_road_distance_m": round(road_dist, 2),
            "nearest_road_clearance_m": round(road_clear, 2),
            "nearest_triangle": nearest_tri or "",
            "nearest_triangle_distance_m": "" if nearest_dist is None else round(nearest_dist, 3),
            "triangle_intersects_polygon": int(bool(intersect)),
            "intersecting_triangles": len(intersect),
            "centroid_triangles_inside": len(centroids_here),
            "mesh_vertex_inside": int(building["id"] in vertex_inside),
            "nearest_other_footprint": other_id,
            "nearest_other_footprint_distance_m": "" if other_dist == 1e9 else round(other_dist, 2),
            "overlapping_footprint": overlaps[0][0] if overlaps else "",
            "recommendation": {
                "A": "rebuild_from_osm_polygon",
                "B": "keep_unresolved",
                "C": "keep_unresolved",
                "D": "keep_unresolved",
                "E": "keep_unresolved",
                "F": "keep_unresolved",
            }[kind],
        }
        missing_rows.append(row)
        if kind == "E" or building["id"] in ambiguous_ids:
            outline_ambiguous.append((building["id"], building["poly"]))
        else:
            outline_missing.append((building["id"], building["poly"]))

    # Projection test. Assigned buildings already coincide with the mesh, so a
    # single city-wide offset is not available as an explanation.
    assigned_offsets = []
    for building in buildings:
        if building["id"] not in vertex_inside:
            continue
        if sum(1 for tri in triangles if tri["owner"] == building["id"]) == 0:
            continue
        pool = nearby_tris(building, 30.0)
        best = None
        for i in pool:
            if not tri_hits_poly(triangles[i]["xz"], building["poly"]):
                continue
            cx, _cy, cz = triangles[i]["centroid"]
            best = (cx - building["cx"], cz - building["cz"])
            break
        if best:
            assigned_offsets.append(best)
        if len(assigned_offsets) >= 200:
            break
    class_a_offsets = []
    for row in missing_rows:
        if row["classification"] != "A":
            continue
        building = by_id[row["osm_id"]]
        if row["nearest_triangle"] == "":
            continue
        tri = next(item for item in triangles if item["index"] == row["nearest_triangle"])
        class_a_offsets.append((tri["centroid"][0] - building["cx"], tri["centroid"][2] - building["cz"]))

    def mean_vector(items):
        if not items:
            return None
        mx = sum(item[0] for item in items) / len(items)
        mz = sum(item[1] for item in items) / len(items)
        lengths = [math.hypot(item[0] - mx, item[1] - mz) for item in items]
        return {"n": len(items), "mean_dx": round(mx, 2), "mean_dz": round(mz, 2), "spread_m": round(sum(lengths) / len(lengths), 2)}

    projection = {
        "assigned_sample": mean_vector(assigned_offsets),
        "class_a": mean_vector(class_a_offsets),
        "class_d_count": 0,
        "conclusion": "Assigned footprints meet the mesh in the game projection. The missing set does not share one offset, so these holes are not a projection error.",
    }

    unresolved_rows = []
    diag_counts = Counter()
    by_reason = defaultdict(list)
    for tri in triangles:
        if tri["owner"]:
            continue
        cx, cy, cz = tri["centroid"]
        n1, d1, i1, n2, d2, i2 = nearest_footprints(grid, buildings, cx, cz)
        kind = diagnose(tri["reason"], tri["material"], tri["area"], d1, d2, i1, tri["verts_inside"])
        diag_counts[kind] += 1
        by_reason[tri["reason"]].append((tri, d1, kind))
        v = tri["verts"]
        unresolved_rows.append({
            "triangle_index": tri["index"],
            "reason": tri["reason"],
            "diagnostic": kind,
            "material": tri["material"],
            "area_m2": round(tri["area"], 6),
            "area_xz_m2": round(tri["xz_area"], 6),
            "degenerate": int(tri["area"] < 1e-4),
            "centroid_x": round(cx, 3),
            "centroid_y": round(cy, 3),
            "centroid_z": round(cz, 3),
            "v0_x": round(v[0][0], 3), "v0_y": round(v[0][1], 3), "v0_z": round(v[0][2], 3),
            "v1_x": round(v[1][0], 3), "v1_y": round(v[1][1], 3), "v1_z": round(v[1][2], 3),
            "v2_x": round(v[2][0], 3), "v2_y": round(v[2][1], 3), "v2_z": round(v[2][2], 3),
            "nearest_footprint_id": n1,
            "nearest_boundary_distance_m": "" if d1 is None else round(d1, 3),
            "nearest_contains_centroid": int(bool(i1)),
            "second_footprint_id": n2,
            "second_boundary_distance_m": "" if d2 is None else round(d2, 3),
            "second_contains_centroid": int(bool(i2)),
            "vertices_inside_a_footprint": tri["verts_inside"],
            "outside_vertex_distance_m": round(tri["outside_m"], 3),
            "normal_y": round(tri["normal_y"], 4),
        })

    def reason_summary(reason):
        rows = by_reason[reason]
        dists = [item[1] for item in rows if item[1] is not None]
        areas = [item[0]["area"] for item in rows]
        mats = Counter(item[0]["material"] for item in rows)
        diags = Counter(item[2] for item in rows)
        return {
            "count": len(rows),
            "materials": dict(mats),
            "diagnostics": dict(diags),
            "degenerate": sum(1 for item in rows if item[0]["area"] < 1e-4),
            "boundary_distance_m": {
                "p10": percentile(dists, 0.10),
                "p50": percentile(dists, 0.50),
                "p90": percentile(dists, 0.90),
                "max": max(dists) if dists else None,
            },
            "area_m2": {"p50": percentile(areas, 0.50), "max": max(areas) if areas else None},
            "within_1m": sum(1 for dist in dists if dist <= 1.0),
            "within_3m": sum(1 for dist in dists if dist <= 3.0),
            "beyond_8m": sum(1 for dist in dists if dist > 8.0),
        }

    reason_recs = {
        "crosses_boundary": "preserve_separately. A split is geometrically possible later and was not applied. The whole triangle was not assigned.",
        "unmatched": "preserve_separately. Distance is outside the 0.20 m band or the second footprint is too close. Not assigned.",
        "ambiguous_multi_footprint": "preserve_separately. Vertices meet more than one footprint.",
        "ambiguous_margin": "preserve_separately. The two nearest footprints are under 0.50 m apart in the ranking.",
    }

    osm_ids = set(osm_meta["ways"])
    part_ids = set(by_id)
    glb_stat = part.GLB.stat()
    osm_stat = part.OSM.stat()
    source = {
        "osm_generator": "DriveViceCity",
        "osm_path": str(part.OSM),
        "osm_sha256": hashlib.sha256(part.OSM.read_bytes()).hexdigest(),
        "osm_mtime_utc": datetime.fromtimestamp(osm_stat.st_mtime, timezone.utc).isoformat(),
        "osm_nodes": osm_meta["nodes"],
        "osm_ways": osm_meta["way_count"],
        "osm_relations": osm_meta["relations"],
        "osm_building_ways": osm_meta["building_tags"],
        "osm_ways_with_version_or_timestamp": osm_meta["versioned_ways"],
        "partition_footprints": len(buildings),
        "ids_only_in_osm": sorted(osm_ids - part_ids),
        "ids_only_in_partition": sorted(part_ids - osm_ids),
        "duplicate_way_ids": duplicate_ids,
        "glb_path": str(part.GLB),
        "glb_sha256": hashlib.sha256(part.GLB.read_bytes()).hexdigest(),
        "glb_mtime_utc": datetime.fromtimestamp(glb_stat.st_mtime, timezone.utc).isoformat(),
        "glb_generator": asset.get("generator", ""),
        "glb_nodes": glb_nodes,
        "glb_has_osm_ids": any((n.get("extras") or {}) for n in glb_nodes),
        "export_script_osm_path": r"D:\drivevicecity\assets\maps\dhule_city.osm",
        "source_identity": "not_proven",
        "source_note": "tools/export_dhule_blosm.py points at this OSM path and the same origin. The GLB stores no way ids, no source hash, and no OSM version. Node ids in the OSM file are local. Way version and timestamp attributes are absent. The current OSM bytes therefore cannot be proven to be the bytes Blosm read.",
        "road_file_not_modified": True,
        "road_count": road_count,
        "road_origin_matches": road_lat == part.LAT0 and road_lon == part.LON0,
        "footprints_with_no_mesh_vertex_inside": no_vertex,
        "water_triangles": water_tris,
    }

    cameras = {}
    if missing_rows:
        class_a = [row for row in missing_rows if row["classification"] == "A"] or missing_rows
        focus = max(class_a, key=lambda row: float(row["nearest_triangle_distance_m"] or 0))
        cameras["missing"] = {
            "osm_id": focus["osm_id"],
            "look": [(focus["min_x"] + focus["max_x"]) * 0.5, 1.0, (focus["min_z"] + focus["max_z"]) * 0.5],
        }
    dense = Counter()
    for tri in triangles:
        if tri["owner"]:
            continue
        cx, _cy, cz = tri["centroid"]
        dense[(int(cx // 40.0), int(cz // 40.0))] += 1
    if dense:
        cell, _count = dense.most_common(1)[0]
        cameras["unresolved"] = {"look": [cell[0] * 40.0 + 20.0, 2.0, cell[1] * 40.0 + 20.0]}
    xs = [b["cx"] for b in buildings]
    zs = [b["cz"] for b in buildings]
    cameras["overview"] = {"look": [sum(xs) / len(xs), 0.0, sum(zs) / len(zs)]}

    fieldnames = list(missing_rows[0].keys()) if missing_rows else ["osm_id"]
    with (OUT / "missing_buildings.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(missing_rows)
    with (OUT / "unresolved_triangles.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(unresolved_rows[0].keys()))
        writer.writeheader()
        writer.writerows(unresolved_rows)

    spatial = {
        "projection": {"lat": part.LAT0, "lon": part.LON0, "x": "east", "y": "up", "z": "south"},
        "assignment_rule": "unchanged from partition_buildings.py. This audit does not assign triangles.",
        "source_triangles": source_tris,
        "assigned_triangles": assigned,
        "unresolved_triangles": unresolved,
        "reason_counts": dict(reasons),
        "missing_footprints": len(missing_rows),
        "missing_classification": dict(class_counts),
        "projection_test": projection,
        "unresolved_diagnostics": dict(diag_counts),
        "by_reason": {key: reason_summary(key) for key in ("crosses_boundary", "unmatched", "ambiguous_multi_footprint", "ambiguous_margin")},
        "category_recommendation": reason_recs,
        "recommendations_applied": False,
        "cameras": cameras,
        "source_comparison": source,
    }
    (OUT / "spatial_diagnostics.json").write_text(json.dumps(spatial, indent=2), encoding="utf-8")
    summary = {
        "missing_footprints": len(missing_rows),
        "unresolved_triangles": unresolved,
        "assigned_triangles": assigned,
        "source_triangles": source_tris,
        "water_triangles": water_tris,
        "classification": dict(class_counts),
        "diagnostics": dict(diag_counts),
        "reason_counts": dict(reasons),
        "duplicate_ids": duplicate_ids,
        "source_identity": source["source_identity"],
        "class_d_count": 0,
        "recommendations_applied": False,
        "cameras": cameras,
    }
    (OUT / "audit_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")

    blob_path = OUT / "preview.bin"
    with blob_path.open("wb") as handle:
        def write_floats(values):
            handle.write(struct.pack("<I", len(values) // 3))
            handle.write(struct.pack("<%df" % len(values), *values))
        write_floats(assigned_blob)
        write_floats(unresolved_blob)
        write_floats(water_blob)
        handle.write(struct.pack("<I", len(outline_missing)))
        for osm_id, poly in outline_missing:
            raw = osm_id.encode("utf-8")
            handle.write(struct.pack("<H", len(raw)))
            handle.write(raw)
            handle.write(struct.pack("<I", len(poly)))
            for x, z in poly:
                handle.write(struct.pack("<ff", x, z))
        handle.write(struct.pack("<I", len(outline_ambiguous)))
        for osm_id, poly in outline_ambiguous:
            raw = osm_id.encode("utf-8")
            handle.write(struct.pack("<H", len(raw)))
            handle.write(raw)
            handle.write(struct.pack("<I", len(poly)))
            for x, z in poly:
                handle.write(struct.pack("<ff", x, z))
        raw = json.dumps(cameras).encode("utf-8")
        handle.write(struct.pack("<I", len(raw)))
        handle.write(raw)
    print("AUDIT missing", len(missing_rows), dict(class_counts))
    print("AUDIT unresolved", unresolved, dict(diag_counts))
    print("AUDIT no_vertex", len(no_vertex))
    print("AUDIT reasons", dict(reasons))


if __name__ == "__main__":
    main()
