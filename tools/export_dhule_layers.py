"""
export_dhule_layers.py
======================
Export the OSM objects that are not already in roads.geojson or buildings.geojson.

Writes only:
  data/dhule/waterways.geojson
  data/dhule/natural.geojson
  data/dhule/landuse.geojson
  data/dhule/leisure.geojson
  data/dhule/railway.geojson
  data/dhule/amenities.geojson
  data/dhule/places.geojson
  data/dhule/route_relations.json
  data/dhule/boundaries.geojson
  data/dhule/manifest.json

Does not read or write dhule_roads_game.json, roads.geojson, or buildings.geojson.
Does not invent tags, heights, or relation geometry.
"""

import json
import os
import xml.etree.ElementTree as ET
from datetime import date

EXPORTER_VERSION = "1.0.0"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OSM_PATH = os.path.join(ROOT, "assets", "maps", "dhulemap.osm")
OUT_DIR = os.path.join(ROOT, "data", "dhule")

# Category tag, output filename, geometry kind. Area kinds become a polygon
# only when the source way is already a closed ring.
LAYERS = (
    ("waterway", "waterways.geojson", "line"),
    ("natural", "natural.geojson", "area"),
    ("landuse", "landuse.geojson", "area"),
    ("leisure", "leisure.geojson", "area"),
    ("railway", "railway.geojson", "line"),
    ("amenity", "amenities.geojson", "area"),
)
LAYER_KEYS = {key for key, _, _ in LAYERS}
PLACE_FIELDS = ("place", "amenity", "shop", "tourism")
FORBIDDEN = {"roads.geojson", "buildings.geojson", "dhule_roads_game.json"}


def tag_or_null(tags, key):
    return tags[key] if key in tags else None


def source_block(bounds):
    return {
        "file": "assets/maps/dhulemap.osm",
        "license": "ODbL-1.0",
        "attribution": "© OpenStreetMap contributors",
        "bounds": bounds,
    }


def write_json(filename, payload):
    if os.path.basename(filename) in FORBIDDEN:
        raise RuntimeError(f"refusing to write {filename}")
    path = os.path.join(OUT_DIR, filename)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    return path


def way_feature(osm_id, refs, tags, nodes, kind):
    coordinates = [[nodes[ref][0], nodes[ref][1]] for ref in refs]
    node_ids = [int(ref) for ref in refs]
    closed = len(refs) >= 4 and refs[0] == refs[-1]
    if kind == "area" and closed:
        geometry = {"type": "Polygon", "coordinates": [coordinates]}
    else:
        geometry = {"type": "LineString", "coordinates": coordinates}
    props = {
        "osm_type": "way",
        "osm_id": osm_id,
        "node_ids": node_ids,
        "tags": tags,
    }
    for key in LAYER_KEYS:
        if key in tags:
            props[key] = tags[key]
    props["name"] = tag_or_null(tags, "name")
    return {
        "type": "Feature",
        "id": f"way/{osm_id}",
        "geometry": geometry,
        "properties": props,
    }


def chain_rings(ref_lists):
    """Join ways that share endpoints. Return closed node-id rings, or None."""
    remaining = [list(refs) for refs in ref_lists]
    rings = []
    while remaining:
        ring = remaining.pop(0)
        progressed = True
        while progressed and ring[0] != ring[-1]:
            progressed = False
            for index, other in enumerate(remaining):
                if ring[-1] == other[0]:
                    ring = ring + other[1:]
                elif ring[-1] == other[-1]:
                    ring = ring + list(reversed(other))[1:]
                elif ring[0] == other[-1]:
                    ring = other + ring[1:]
                elif ring[0] == other[0]:
                    ring = list(reversed(other)) + ring[1:]
                else:
                    continue
                remaining.pop(index)
                progressed = True
                break
        if ring[0] != ring[-1]:
            return None
        rings.append(ring)
    return rings


def boundary_geometry(members, ways, nodes):
    """Assemble a polygon only when every outer and inner way is in this file."""
    groups = {"outer": [], "inner": []}
    for member in members:
        role = member["role"]
        if role not in groups or member["type"] != "way":
            continue
        rec = ways.get(str(member["ref"]))
        if rec is None or any(ref not in nodes for ref in rec["refs"]):
            return None
        groups[role].append(rec["refs"])
    if not groups["outer"]:
        return None
    outer_rings = chain_rings(groups["outer"])
    inner_rings = chain_rings(groups["inner"]) if groups["inner"] else []
    if outer_rings is None or inner_rings is None:
        return None

    def ring_coords(refs):
        return [[nodes[ref][0], nodes[ref][1]] for ref in refs]

    if len(outer_rings) == 1 and not inner_rings:
        return {"type": "Polygon", "coordinates": [ring_coords(outer_rings[0])]}
    if len(outer_rings) == 1:
        return {
            "type": "Polygon",
            "coordinates": [ring_coords(outer_rings[0])] + [ring_coords(r) for r in inner_rings],
        }
    polygons = []
    for outer in outer_rings:
        polygons.append([ring_coords(outer)])
    if inner_rings:
        return None
    return {"type": "MultiPolygon", "coordinates": polygons}


def feature_count(filename):
    path = os.path.join(OUT_DIR, filename)
    with open(path, encoding="utf-8") as handle:
        return len(json.load(handle)["features"])


def main():
    root = ET.parse(OSM_PATH).getroot()
    bounds_el = root.find("bounds")
    bounds = {key: bounds_el.attrib[key] for key in ("minlat", "minlon", "maxlat", "maxlon")}
    meta = source_block(bounds)

    nodes = {}
    element_timestamps = []
    for node in root.findall("node"):
        nodes[node.attrib["id"]] = (float(node.attrib["lon"]), float(node.attrib["lat"]))
        if node.attrib.get("timestamp"):
            element_timestamps.append(node.attrib["timestamp"])

    ways = {}
    for way in root.findall("way"):
        tags = {tag.attrib["k"]: tag.attrib["v"] for tag in way.findall("tag")}
        refs = [nd.attrib["ref"] for nd in way.findall("nd")]
        ways[way.attrib["id"]] = {"tags": tags, "refs": refs}
        if way.attrib.get("timestamp"):
            element_timestamps.append(way.attrib["timestamp"])

    layer_features = {filename: [] for _, filename, _ in LAYERS}
    skipped_unresolved = []
    for way_id, rec in ways.items():
        tags = rec["tags"]
        if "highway" in tags or "building" in tags:
            continue
        matched = [key for key, _, _ in LAYERS if key in tags]
        if len(matched) != 1:
            raise RuntimeError(f"way {way_id} matched {matched or 'no'} layer keys")
        if any(ref not in nodes for ref in rec["refs"]) or len(rec["refs"]) < 2:
            skipped_unresolved.append(way_id)
            continue
        filename, kind = next((fn, kind) for key, fn, kind in LAYERS if key == matched[0])
        layer_features[filename].append(
            way_feature(int(way_id), rec["refs"], tags, nodes, kind)
        )

    places = []
    for node in root.findall("node"):
        tags = {tag.attrib["k"]: tag.attrib["v"] for tag in node.findall("tag")}
        if not tags:
            continue
        osm_id = int(node.attrib["id"])
        props = {
            "osm_type": "node",
            "osm_id": osm_id,
            "tags": tags,
        }
        for field in PLACE_FIELDS:
            props[field] = tag_or_null(tags, field)
        props["name"] = tag_or_null(tags, "name")
        places.append(
            {
                "type": "Feature",
                "id": f"node/{osm_id}",
                "geometry": {
                    "type": "Point",
                    "coordinates": [float(node.attrib["lon"]), float(node.attrib["lat"])],
                },
                "properties": props,
            }
        )

    routes = []
    boundaries = []
    for rel in root.findall("relation"):
        tags = {tag.attrib["k"]: tag.attrib["v"] for tag in rel.findall("tag")}
        members = [
            {
                "type": member.attrib.get("type"),
                "ref": int(member.attrib["ref"]),
                "role": member.attrib.get("role", ""),
            }
            for member in rel.findall("member")
        ]
        if rel.attrib.get("timestamp"):
            element_timestamps.append(rel.attrib["timestamp"])
        record = {"id": int(rel.attrib["id"]), "tags": tags, "members": members}
        if tags.get("type") == "route" and tags.get("route") == "road":
            routes.append(record)
        elif tags.get("type") == "boundary":
            geometry = boundary_geometry(members, ways, nodes)
            props = {
                "osm_type": "relation",
                "osm_id": record["id"],
                "name": tag_or_null(tags, "name"),
                "tags": tags,
                "members": members,
            }
            boundaries.append(
                {
                    "type": "Feature",
                    "id": f"relation/{record['id']}",
                    "geometry": geometry,
                    "properties": props,
                }
            )
        else:
            raise RuntimeError(f"unclassified relation {rel.attrib['id']}")

    os.makedirs(OUT_DIR, exist_ok=True)
    for filename, features in layer_features.items():
        write_json(
            filename,
            {
                "type": "FeatureCollection",
                "name": f"dhule-{filename.split('.')[0]}",
                "source": meta,
                "features": features,
            },
        )
        print(f"{filename} {len(features)}")

    write_json(
        "places.geojson",
        {
            "type": "FeatureCollection",
            "name": "dhule-places",
            "source": meta,
            "features": places,
        },
    )
    print(f"places.geojson {len(places)}")

    write_json(
        "route_relations.json",
        {
            "type": "RouteRelationCollection",
            "name": "dhule-route-relations",
            "source": meta,
            "relations": routes,
        },
    )
    print(f"route_relations.json {len(routes)}")

    write_json(
        "boundaries.geojson",
        {
            "type": "FeatureCollection",
            "name": "dhule-boundaries",
            "source": meta,
            "features": boundaries,
        },
    )
    print(f"boundaries.geojson {len(boundaries)} geometry {[f['geometry'] for f in boundaries]}")

    latest = max(element_timestamps) if element_timestamps else None
    layers = [
        {
            "id": "roads",
            "filename": "roads.geojson",
            "feature_count": feature_count("roads.geojson"),
            "rewritten_this_export": False,
        },
        {
            "id": "buildings",
            "filename": "buildings.geojson",
            "feature_count": feature_count("buildings.geojson"),
            "rewritten_this_export": False,
        },
    ]
    for key, filename, _kind in LAYERS:
        layers.append(
            {
                "id": key if key != "amenity" else "amenities",
                "filename": filename,
                "feature_count": len(layer_features[filename]),
                "rewritten_this_export": True,
            }
        )
    layers.extend(
        [
            {
                "id": "places",
                "filename": "places.geojson",
                "feature_count": len(places),
                "rewritten_this_export": True,
            },
            {
                "id": "route_relations",
                "filename": "route_relations.json",
                "feature_count": len(routes),
                "rewritten_this_export": True,
            },
            {
                "id": "boundaries",
                "filename": "boundaries.geojson",
                "feature_count": len(boundaries),
                "geometry_assembled": sum(1 for feature in boundaries if feature["geometry"]),
                "rewritten_this_export": True,
            },
        ]
    )
    write_json(
        "manifest.json",
        {
            "city_id": "dhule",
            "display_name": "Dhule",
            "crs": "WGS84 / EPSG:4326",
            "epsg": 4326,
            "origin": {"latitude": 20.902, "longitude": 74.777},
            "source_filename": "assets/maps/dhulemap.osm",
            "source_timestamp": None,
            "latest_element_timestamp": latest,
            "export_date": date.today().isoformat(),
            "bounds": bounds,
            "license": "ODbL-1.0",
            "attribution": "© OpenStreetMap contributors",
            "exporter": {
                "script": "tools/export_dhule_layers.py",
                "version": EXPORTER_VERSION,
            },
            "layers": layers,
            "skipped_unresolved_ways": skipped_unresolved,
        },
    )
    print(f"manifest.json latest_element_timestamp {latest} skipped {skipped_unresolved}")


if __name__ == "__main__":
    main()
