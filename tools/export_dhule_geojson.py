"""
export_dhule_geojson.py
=======================
Read-only export of dhulemap.osm into source GeoJSON.

Writes:
  data/dhule/roads.geojson
  data/dhule/buildings.geojson

Does not read or write assets/maps/dhule_roads_game.json.
Missing tags stay null. Heights are not invented.
"""

import json
import os
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OSM_PATH = os.path.join(ROOT, "assets", "maps", "dhulemap.osm")
OUT_DIR = os.path.join(ROOT, "data", "dhule")

ROAD_FIELDS = ("highway", "name", "oneway", "lanes", "bridge", "tunnel")
BUILDING_FIELDS = (
    ("building", "building"),
    ("name", "name"),
    ("levels", "building:levels"),
    ("height", "height"),
    ("roof_shape", "roof:shape"),
)


def tag_or_null(tags, key):
    return tags[key] if key in tags else None


def source_block(bounds):
    return {
        "file": "assets/maps/dhulemap.osm",
        "license": "ODbL-1.0",
        "attribution": "© OpenStreetMap contributors",
        "bounds": bounds,
    }


def main():
    root = ET.parse(OSM_PATH).getroot()
    bounds_el = root.find("bounds")
    bounds = None
    if bounds_el is not None:
        bounds = {k: bounds_el.attrib[k] for k in ("minlat", "minlon", "maxlat", "maxlon")}

    nodes = {}
    for node in root.findall("node"):
        nodes[node.attrib["id"]] = (float(node.attrib["lon"]), float(node.attrib["lat"]))

    roads = []
    buildings = []
    skipped_roads = 0
    skipped_buildings = 0

    for way in root.findall("way"):
        tags = {tag.attrib["k"]: tag.attrib["v"] for tag in way.findall("tag")}
        refs = [nd.attrib["ref"] for nd in way.findall("nd")]
        if any(ref not in nodes for ref in refs):
            if "highway" in tags:
                skipped_roads += 1
            if "building" in tags:
                skipped_buildings += 1
            continue

        osm_id = int(way.attrib["id"])
        coordinates = [list(nodes[ref]) for ref in refs]

        if "highway" in tags and len(coordinates) >= 2:
            props = {
                "osm_type": "way",
                "osm_id": osm_id,
                "node_ids": [int(ref) for ref in refs],
                "tags": tags,
            }
            for field in ROAD_FIELDS:
                props[field] = tag_or_null(tags, field)
            roads.append(
                {
                    "type": "Feature",
                    "id": f"way/{osm_id}",
                    "geometry": {"type": "LineString", "coordinates": coordinates},
                    "properties": props,
                }
            )

        if "building" in tags and len(coordinates) >= 3:
            ring_refs = list(refs)
            ring = list(coordinates)
            if ring[0] != ring[-1]:
                ring.append(list(ring[0]))
                ring_refs.append(ring_refs[0])
            props = {
                "osm_type": "way",
                "osm_id": osm_id,
                "node_ids": [int(ref) for ref in ring_refs],
                "tags": tags,
            }
            for field, key in BUILDING_FIELDS:
                props[field] = tag_or_null(tags, key)
            buildings.append(
                {
                    "type": "Feature",
                    "id": f"way/{osm_id}",
                    "geometry": {"type": "Polygon", "coordinates": [ring]},
                    "properties": props,
                }
            )

    os.makedirs(OUT_DIR, exist_ok=True)
    roads_path = os.path.join(OUT_DIR, "roads.geojson")
    buildings_path = os.path.join(OUT_DIR, "buildings.geojson")
    meta = source_block(bounds)

    with open(roads_path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(
            {"type": "FeatureCollection", "name": "dhule-roads", "source": meta, "features": roads},
            handle,
            ensure_ascii=False,
            indent=2,
        )
        handle.write("\n")

    with open(buildings_path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(
            {
                "type": "FeatureCollection",
                "name": "dhule-buildings",
                "source": meta,
                "features": buildings,
            },
            handle,
            ensure_ascii=False,
            indent=2,
        )
        handle.write("\n")

    print(f"roads {len(roads)} skipped {skipped_roads} -> {roads_path}")
    print(f"buildings {len(buildings)} skipped {skipped_buildings} -> {buildings_path}")


if __name__ == "__main__":
    main()
