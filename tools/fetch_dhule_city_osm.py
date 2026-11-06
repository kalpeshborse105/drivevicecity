"""Download real Dhule building footprints for the playable map.

Writes an OSM file for Blender/blosm and a small shop list in game metres.
Footprints and shop points come from OpenStreetMap. Nothing is invented.
"""
import json
import math
import urllib.request
from pathlib import Path

ORIGIN_LAT = 20.902
ORIGIN_LON = 74.777
MIN_X, MAX_X = -3773.5, 2370.13
MIN_Z, MAX_Z = -1682.45, 3363.14
M_LAT = 111320.0
M_LON = 111320.0 * math.cos(math.radians(ORIGIN_LAT))

ROOT = Path(r"D:\drivevicecity")
OSM_OUT = ROOT / "assets" / "maps" / "dhule_city.osm"
SHOPS_OUT = ROOT / "data" / "dhule" / "city_shops.json"

south = ORIGIN_LAT - MAX_Z / M_LAT - 0.01
north = ORIGIN_LAT - MIN_Z / M_LAT + 0.01
west = ORIGIN_LON + MIN_X / M_LON - 0.01
east = ORIGIN_LON + MAX_X / M_LON + 0.01


def to_game(lat: float, lon: float) -> tuple[float, float]:
    x = (lon - ORIGIN_LON) * M_LON
    z = -(lat - ORIGIN_LAT) * M_LAT
    return (round(x, 2), round(z, 2))


def fetch() -> dict:
    query = f"""[out:json][timeout:180];
(
  way["building"]({south},{west},{north},{east});
  way["shop"]({south},{west},{north},{east});
  way["natural"="water"]({south},{west},{north},{east});
  way["waterway"]({south},{west},{north},{east});
  node["shop"]({south},{west},{north},{east});
);
out geom;
"""
    req = urllib.request.Request(
        "https://overpass-api.de/api/interpreter",
        data=query.encode("utf-8"),
        headers={"User-Agent": "DriveViceCity/1.0 (local Dhule map build)"},
    )
    with urllib.request.urlopen(req, timeout=240) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> None:
    data = fetch()
    elements = data.get("elements", [])
    node_ids: dict[tuple[float, float], int] = {}
    nodes: list[tuple[int, float, float]] = []
    ways: list[str] = []
    shops: list[dict] = []
    next_id = 1
    buildings = 0

    def node_id(lat: float, lon: float) -> int:
        nonlocal next_id
        key = (round(lat, 7), round(lon, 7))
        found = node_ids.get(key)
        if found is not None:
            return found
        node_ids[key] = next_id
        nodes.append((next_id, key[0], key[1]))
        next_id += 1
        return node_ids[key]

    for element in elements:
        tags = element.get("tags") or {}
        geometry = element.get("geometry") or []
        if element.get("type") == "node" and "shop" in tags:
            x, z = to_game(element["lat"], element["lon"])
            shops.append({
                "id": element["id"],
                "name": tags.get("name", ""),
                "kind": tags.get("shop", "yes"),
                "x": x,
                "z": z,
            })
            continue
        if element.get("type") != "way" or len(geometry) < 3:
            continue
        refs = [node_id(point["lat"], point["lon"]) for point in geometry]
        if refs[0] != refs[-1]:
            refs.append(refs[0])
        tag_lines = []
        if "building" in tags:
            buildings += 1
            tag_lines.append(f'    <tag k="building" v="{_xml(tags.get("building", "yes"))}"/>')
            if tags.get("building:levels"):
                tag_lines.append(f'    <tag k="building:levels" v="{_xml(tags["building:levels"])}"/>')
            if tags.get("height"):
                tag_lines.append(f'    <tag k="height" v="{_xml(tags["height"])}"/>')
            if tags.get("name"):
                tag_lines.append(f'    <tag k="name" v="{_xml(tags["name"])}"/>')
        if "shop" in tags:
            tag_lines.append(f'    <tag k="shop" v="{_xml(tags["shop"])}"/>')
            lats = [point["lat"] for point in geometry]
            lons = [point["lon"] for point in geometry]
            x, z = to_game(sum(lats) / len(lats), sum(lons) / len(lons))
            shops.append({
                "id": element["id"],
                "name": tags.get("name", ""),
                "kind": tags.get("shop", "yes"),
                "x": x,
                "z": z,
            })
        if tags.get("natural") == "water":
            tag_lines.append('    <tag k="natural" v="water"/>')
        if "waterway" in tags:
            tag_lines.append(f'    <tag k="waterway" v="{_xml(tags["waterway"])}"/>')
        if not tag_lines:
            continue
        nds = "\n".join(f'    <nd ref="{ref}"/>' for ref in refs)
        ways.append(f'  <way id="{element["id"]}">\n{nds}\n' + "\n".join(tag_lines) + "\n  </way>")

    OSM_OUT.parent.mkdir(parents=True, exist_ok=True)
    SHOPS_OUT.parent.mkdir(parents=True, exist_ok=True)
    node_xml = "\n".join(f'  <node id="{nid}" lat="{lat}" lon="{lon}"/>' for nid, lat, lon in nodes)
    body = "\n".join(ways)
    OSM_OUT.write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<osm version="0.6" generator="DriveViceCity">\n'
        f"{node_xml}\n{body}\n</osm>\n",
        encoding="utf-8",
    )
    SHOPS_OUT.write_text(json.dumps({
        "attribution": "© OpenStreetMap contributors (ODbL)",
        "origin_lat": ORIGIN_LAT,
        "origin_lon": ORIGIN_LON,
        "shop_count": len(shops),
        "shops": shops,
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"buildings {buildings}")
    print(f"shops {len(shops)}")
    print(f"nodes {len(nodes)}")
    print(f"wrote {OSM_OUT} ({OSM_OUT.stat().st_size} bytes)")
    print(f"wrote {SHOPS_OUT}")


def _xml(value: str) -> str:
    return (
        str(value)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


if __name__ == "__main__":
    main()
