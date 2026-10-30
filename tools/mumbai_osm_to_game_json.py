"""Build a small Mumbai Fort/Colaba OSM road JSON for the isolated playable prototype.

Source: Geofabrik western-zone PBF (same file as Dhule) — Mumbai clip only.
Does NOT modify dhule_roads_game.json.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBF = ROOT / "western-zone-261027.osm.pbf"
OVERPASS = ROOT / "assets" / "maps" / "mumbai_fort.osm.json"
OUT = ROOT / "assets" / "maps" / "mumbai_fort_roads_game.json"
ATTRIB = ROOT / "assets" / "maps" / "MUMBAI_ATTRIBUTION.txt"

# Fort / Horniman Circle area — manageable prototype, not all of Mumbai
ORIGIN_LAT = 18.9322
ORIGIN_LON = 72.8264
MUMBAI_LAT = (18.920, 18.945)
MUMBAI_LON = (72.810, 72.845)
CLIP_RADIUS = 900.0
CORE_RADIUS = 350.0

METERS_PER_DEG_LAT = 111320.0
METERS_PER_DEG_LON = 111320.0 * math.cos(math.radians(ORIGIN_LAT))

WIDTH = {
	"motorway": 14.0,
	"trunk": 12.0,
	"primary": 11.0,
	"secondary": 9.5,
	"tertiary": 8.0,
	"unclassified": 7.0,
	"residential": 6.5,
	"living_street": 5.5,
	"service": 5.0,
}
KEEP = set(WIDTH)
PRIORITY = {
	"motorway": 0,
	"trunk": 1,
	"primary": 2,
	"secondary": 3,
	"tertiary": 4,
	"unclassified": 5,
	"residential": 6,
	"living_street": 7,
	"service": 8,
}
MINOR_ROAD_CAP = 220


def to_xz(lat: float, lon: float) -> list[float]:
	x = (lon - ORIGIN_LON) * METERS_PER_DEG_LON
	z = -(lat - ORIGIN_LAT) * METERS_PER_DEG_LAT
	return [round(x, 2), round(z, 2)]


def inside(pt: list[float], radius: float = CLIP_RADIUS) -> bool:
	return abs(pt[0]) <= radius and abs(pt[1]) <= radius


def path_length(pts: list[list[float]]) -> float:
	total = 0.0
	for i in range(1, len(pts)):
		total += math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1])
	return total


def clip_polyline_runs(pts: list[list[float]]) -> list[list[list[float]]]:
	runs: list[list[list[float]]] = []
	cur: list[list[float]] = []
	for p in pts:
		if inside(p):
			cur.append(p)
		elif cur:
			if len(cur) >= 2:
				runs.append(cur)
			cur = []
	if len(cur) >= 2:
		runs.append(cur)
	return runs


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


def load_pbf_elements(path: Path) -> list[dict]:
	import osmium

	class NodePass(osmium.SimpleHandler):
		def __init__(self) -> None:
			super().__init__()
			self.coords: dict[int, tuple[float, float]] = {}

		def node(self, n) -> None:  # noqa: ANN001
			if not n.location.valid():
				return
			lat, lon = n.lat, n.lon
			if not (MUMBAI_LAT[0] <= lat <= MUMBAI_LAT[1] and MUMBAI_LON[0] <= lon <= MUMBAI_LON[1]):
				return
			self.coords[n.id] = (lat, lon)

	class WayPass(osmium.SimpleHandler):
		def __init__(self, coords: dict[int, tuple[float, float]]) -> None:
			super().__init__()
			self.coords = coords
			self.elements: list[dict] = []

		def way(self, w) -> None:  # noqa: ANN001
			tags = {t.k: t.v for t in w.tags}
			if not tags.get("highway"):
				return
			geom: list[tuple[float, float]] = []
			for nref in w.nodes:
				hit = self.coords.get(nref.ref)
				if hit:
					geom.append(hit)
			if len(geom) < 2:
				return
			self.elements.append(
				{
					"type": "way",
					"id": w.id,
					"tags": tags,
					"geometry": [{"lat": lat, "lon": lon} for lat, lon in geom],
				}
			)

	nodes = NodePass()
	print(f"scanning PBF for Mumbai Fort window…", flush=True)
	nodes.apply_file(str(path))
	print(f"mumbai_nodes={len(nodes.coords)}", flush=True)
	ways = WayPass(nodes.coords)
	ways.apply_file(str(path))
	print(f"mumbai_highway_ways={len(ways.elements)}", flush=True)
	return ways.elements


def main() -> None:
	source_name = "geofabrik-western-zone-pbf-mumbai-fort-clip"
	if OVERPASS.exists():
		print(f"reading Overpass extract {OVERPASS.name}", flush=True)
		payload = json.loads(OVERPASS.read_text(encoding="utf-8"))
		elements = payload.get("elements") or []
		source_name = "overpass-mumbai-fort-highways"
	elif PBF.exists():
		elements = load_pbf_elements(PBF)
	else:
		raise SystemExit(
			"Missing OSM source. Run tools/fetch_mumbai_fort_overpass.py or provide western-zone PBF.\n"
			"Do not invent roads."
		)
	roads: list[dict] = []
	min_x = min_z = 1e9
	max_x = max_z = -1e9

	for el in elements:
		tags = el.get("tags") or {}
		hw = tags.get("highway")
		if hw not in KEEP:
			continue
		geom = el.get("geometry") or []
		if len(geom) < 2:
			continue
		pts_full = [to_xz(float(g["lat"]), float(g["lon"])) for g in geom]
		for pts in clip_polyline_runs(pts_full):
			if len(pts) < 2:
				continue
			if hw in ("residential", "service", "living_street") and len(pts) > 10:
				dec = pts[::2]
				if dec[-1] != pts[-1]:
					dec.append(pts[-1])
				pts = dec
			length = path_length(pts)
			if length < 16.0:
				continue
			for xz in pts:
				min_x = min(min_x, xz[0])
				max_x = max(max_x, xz[0])
				min_z = min(min_z, xz[1])
				max_z = max(max_z, xz[1])
			roads.append(
				{
					"id": el.get("id"),
					"highway": hw,
					"name": tags.get("name") or "",
					"width": WIDTH[hw],
					"priority": PRIORITY[hw],
					"points": pts,
					"length_m": round(length, 1),
				}
			)

	# Prefer majors; cap minors for mobile prototype
	roads.sort(key=lambda r: (r["priority"], -r["length_m"]))
	majors = [r for r in roads if r["highway"] in ("motorway", "trunk", "primary", "secondary", "tertiary")]
	minors = [r for r in roads if r["highway"] not in ("motorway", "trunk", "primary", "secondary", "tertiary")]
	roads = majors + minors[:MINOR_ROAD_CAP]

	# Spawn on longest secondary/primary near origin
	spawn = None
	candidates = [r for r in roads if r["highway"] in ("primary", "secondary", "tertiary", "trunk")]
	candidates.sort(key=lambda r: -r["length_m"])
	for r in candidates:
		mid = len(r["points"]) // 2
		p = r["points"][mid]
		if inside(p, CORE_RADIUS):
			h = heading_at(r["points"], mid)
			spawn = {"x": p[0], "z": p[1], "hx": h[0], "hz": h[1], "road": r.get("name") or r["highway"], "highway": r["highway"]}
			break
	if spawn is None and roads:
		r = roads[0]
		p = r["points"][0]
		h = heading_at(r["points"], 0)
		spawn = {"x": p[0], "z": p[1], "hx": h[0], "hz": h[1], "road": r.get("name") or r["highway"], "highway": r["highway"]}

	# Connectivity probe: count endpoint clusters (rough junction count)
	ends: list[tuple[float, float]] = []
	for r in roads:
		ends.append((r["points"][0][0], r["points"][0][1]))
		ends.append((r["points"][-1][0], r["points"][-1][1]))
	clusters = 0
	used = [False] * len(ends)
	for i, a in enumerate(ends):
		if used[i]:
			continue
		clusters += 1
		used[i] = True
		for j in range(i + 1, len(ends)):
			if used[j]:
				continue
			if math.hypot(a[0] - ends[j][0], a[1] - ends[j][1]) < 12.0:
				used[j] = True

	game = {
		"city": "mumbai_fort_prototype",
		"origin_lat": ORIGIN_LAT,
		"origin_lon": ORIGIN_LON,
		"clip_radius_m": CLIP_RADIUS,
		"scale": "1 Godot unit = 1 metre",
		"coord_system": "x=east metres, z=south metres (lat north → −z)",
		"attribution": "© OpenStreetMap contributors (ODbL)",
		"source": source_name,
		"bbox_m": {"min_x": round(min_x, 1), "max_x": round(max_x, 1), "min_z": round(min_z, 1), "max_z": round(max_z, 1)},
		"road_count": len(roads),
		"junction_clusters_approx": clusters,
		"spawn": spawn,
		"roads": [{k: v for k, v in r.items() if k != "priority"} for r in roads],
		"buildings": [],
		"water": [],
		"landuse": [],
		"pois": [],
		"delivery_anchors": [],
		"flyovers": [],
		"note": "Playable OSM road prototype only. mumbai_city.glb is NOT aligned and not used for roads.",
	}
	OUT.parent.mkdir(parents=True, exist_ok=True)
	OUT.write_text(json.dumps(game, separators=(",", ":")), encoding="utf-8")
	ATTRIB.write_text(
		"Map data © OpenStreetMap contributors\n"
		"Licensed under the Open Data Commons Open Database License (ODbL).\n"
		"https://www.openstreetmap.org/copyright\n\n"
		"Mumbai Fort / Colaba prototype clip (~±900 m) around\n"
		f"{ORIGIN_LAT} N, {ORIGIN_LON} E from Geofabrik western-zone OSM PBF.\n"
		"Processed into mumbai_fort_roads_game.json for DriveViceCity isolated scene.\n"
		"The visual asset assets/incoming/mumbai_city.glb is CC-BY-4.0 (suveer__10) and is\n"
		"NOT used as the playable road network.\n",
		encoding="utf-8",
	)
	print(
		f"wrote {OUT.name} roads={len(roads)} majors={len(majors)} "
		f"junctions~{clusters} spawn={spawn} bytes={OUT.stat().st_size}"
	)


if __name__ == "__main__":
	main()
