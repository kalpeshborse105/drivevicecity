"""Merge Dhule-only Shortbread tiles into the existing game JSON.

Does not replace roads, spawn, or delivery anchors.
Source MBTiles stays out of the playable scene and out of Git.
"""
from __future__ import annotations

import gzip
import json
import math
import sqlite3
from pathlib import Path

import mapbox_vector_tile

ROOT = Path(__file__).resolve().parents[1]
MBTILES = ROOT / "western-zone-shortbread-1.0.mbtiles"
GAME = ROOT / "assets" / "maps" / "dhule_roads_game.json"

ORIGIN_LAT = 20.902
ORIGIN_LON = 74.777
MPL = 111320.0
MPLON = 111320.0 * math.cos(math.radians(ORIGIN_LAT))
# Match Ring 1 clip in osm_to_game_json.py
CLIP = 1600.0
Z = 14
EXTENT = 4096
# Tile ring: z14 ~2.4 km — ±3 covers ~1.6 km clip with margin
TILE_RANGE = range(-3, 4)
BUILDING_CAP = 520
WATER_CAP = 56
LANDUSE_CAP = 96
POI_CAP = 40
FLYOVER_CAP = 14
ROAD_CLEAR_M = 10.0
# Footprint AABB also rejected if any corner sits on asphalt
BUILDING_CORNER_CLEAR_M = 7.5


def to_xz(lat: float, lon: float) -> tuple[float, float]:
	x = (lon - ORIGIN_LON) * MPLON
	z = -(lat - ORIGIN_LAT) * MPL
	return x, z


def inside(x: float, z: float, radius: float = CLIP - 20) -> bool:
	return abs(x) <= radius and abs(z) <= radius


def lonlat_from_tile(tx: int, ty: int, px: float, py: float) -> tuple[float, float]:
	n = 2**Z
	lon = (tx + px / EXTENT) / n * 360.0 - 180.0
	y = ty + py / EXTENT
	lat = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * y / n))))
	return lat, lon


def tile_xy(lat: float, lon: float) -> tuple[int, int]:
	n = 2**Z
	x = int((lon + 180.0) / 360.0 * n)
	latr = math.radians(lat)
	y = int((1 - math.log(math.tan(latr) + 1 / math.cos(latr)) / math.pi) / 2 * n)
	return x, y


def walk_rings(geom) -> list[list[tuple[float, float]]]:
	"""Return rings as lists of (px, py) from a decoded MVT geometry."""
	if not isinstance(geom, dict):
		return []
	gtype = geom.get("type")
	coords = geom.get("coordinates") or []
	rings: list[list[tuple[float, float]]] = []
	if gtype == "Polygon":
		for ring in coords:
			rings.append([(float(p[0]), float(p[1])) for p in ring])
	elif gtype == "MultiPolygon":
		for poly in coords:
			for ring in poly:
				rings.append([(float(p[0]), float(p[1])) for p in ring])
	elif gtype == "Point":
		rings.append([(float(coords[0]), float(coords[1]))])
	return rings


def _seg_dist2(px: float, pz: float, ax: float, az: float, bx: float, bz: float) -> float:
	abx, abz = bx - ax, bz - az
	apx, apz = px - ax, pz - az
	ab2 = abx * abx + abz * abz
	if ab2 < 1e-6:
		return apx * apx + apz * apz
	t = max(0.0, min(1.0, (apx * abx + apz * abz) / ab2))
	dx, dz = ax + abx * t - px, az + abz * t - pz
	return dx * dx + dz * dz


def build_road_index(roads: list) -> list[tuple[float, float, float, float, float]]:
	"""Flat list of (ax, az, bx, bz, half_w + clear) segments for carriageway reject."""
	segs: list[tuple[float, float, float, float, float]] = []
	for r in roads:
		pts = r.get("points") or []
		half = float(r.get("width", 7.0)) * 0.5 + ROAD_CLEAR_M
		for i in range(len(pts) - 1):
			a, b = pts[i], pts[i + 1]
			segs.append((float(a[0]), float(a[1]), float(b[0]), float(b[1]), half))
	return segs


def on_carriageway(x: float, z: float, segs: list[tuple[float, float, float, float, float]]) -> bool:
	for ax, az, bx, bz, clear in segs:
		if _seg_dist2(x, z, ax, az, bx, bz) <= clear * clear:
			return True
	return False


def main() -> None:
	game = json.loads(GAME.read_text(encoding="utf-8"))
	# Never overwrite roads / spawn / delivery jobs
	roads = game.get("roads") or []
	road_segs = build_road_index(roads)

	cx, cy = tile_xy(ORIGIN_LAT, ORIGIN_LON)
	con = sqlite3.connect(MBTILES)
	buildings: list[dict] = []
	waters: list[dict] = []
	landuses: list[dict] = []
	pois: list[dict] = []
	flyovers: list[dict] = []
	tiles = 0
	for dx in TILE_RANGE:
		for dy in TILE_RANGE:
			tx, ty = cx + dx, cy + dy
			tms_y = (2**Z - 1) - ty
			row = con.execute(
				"select tile_data from tiles where zoom_level=? and tile_column=? and tile_row=?",
				(Z, tx, tms_y),
			).fetchone()
			if not row:
				continue
			tiles += 1
			blob = row[0]
			if blob[:2] == b"\x1f\x8b":
				blob = gzip.decompress(blob)
			decoded = mapbox_vector_tile.decode(blob)
			_collect(decoded, tx, ty, buildings, waters, landuses, pois, flyovers, road_segs)
	con.close()

	# Prefer denser / closer footprints; drop center OR corners on asphalt
	def _building_ok(b: dict) -> bool:
		x, z, hw, hd = b["x"], b["z"], b["w"] * 0.45, b["d"] * 0.45
		pts = [
			(x, z),
			(x + hw, z),
			(x - hw, z),
			(x, z + hd),
			(x, z - hd),
			(x + hw, z + hd),
			(x - hw, z - hd),
		]
		# Tighter clear on corners so facades never sit in the lane
		tight = [(a, bz, c, d, max(BUILDING_CORNER_CLEAR_M, e - 2.0)) for a, bz, c, d, e in road_segs]
		return all(not on_carriageway(px, pz, tight) for px, pz in pts)

	buildings = [b for b in buildings if _building_ok(b)]
	buildings.sort(key=lambda b: math.hypot(b["x"], b["z"]))
	# Dedup near-identical footprints (tile overlap)
	deduped: list[dict] = []
	for b in buildings:
		if all(math.hypot(b["x"] - o["x"], b["z"] - o["z"]) > 6.0 for o in deduped):
			deduped.append(b)
		if len(deduped) >= BUILDING_CAP:
			break
	game["buildings"] = deduped

	# Dedup overlapping water patches
	waters.sort(key=lambda w: -(w["w"] * w["d"]))
	water_out: list[dict] = []
	for w in waters:
		if all(math.hypot(w["x"] - o["x"], w["z"] - o["z"]) > 40.0 for o in water_out):
			water_out.append(w)
		if len(water_out) >= WATER_CAP:
			break
	game["water"] = water_out

	landuses.sort(key=lambda lu: -(lu["w"] * lu["d"]))
	# Prefer variety: keep at most ~half residential patches
	spawn = game.get("spawn") or {}
	sx = float(spawn.get("x", 0.0))
	sz = float(spawn.get("z", 0.0))
	lu_out: list[dict] = []
	res_n = 0
	for lu in landuses:
		if lu["kind"] == "residential":
			if res_n >= LANDUSE_CAP // 2:
				continue
			res_n += 1
		# Skip landuse that covers the spawn pad
		if math.hypot(lu["x"] - sx, lu["z"] - sz) < 40.0:
			continue
		lu_out.append(lu)
		if len(lu_out) >= LANDUSE_CAP:
			break
	game["landuse"] = lu_out

	# Diversify POIs — soft carriageway reject; cap hospitals so other kinds appear
	pois.sort(key=lambda p: math.hypot(p["x"], p["z"]))
	poi_out: list[dict] = []
	kind_counts: dict[str, int] = {}
	kind_caps = {"hospital": 8, "school": 6, "place_of_worship": 6, "fuel": 4, "marketplace": 4, "bank": 4, "bus_station": 4}
	for p in pois:
		k = str(p.get("kind") or "")
		if on_carriageway(p["x"], p["z"], [(a, b, c, d, max(0.0, e - 4.0)) for a, b, c, d, e in road_segs]):
			continue
		cap = kind_caps.get(k, 5)
		if kind_counts.get(k, 0) >= cap:
			continue
		kind_counts[k] = kind_counts.get(k, 0) + 1
		poi_out.append(p)
		if len(poi_out) >= POI_CAP:
			break
	game["pois"] = poi_out

	flyovers.sort(key=lambda f: -f["length"])
	for item in flyovers:
		item.pop("length", None)
	game["flyovers"] = flyovers[:FLYOVER_CAP]
	game["attribution"] = "© OpenStreetMap contributors (ODbL)"
	game["source"] = "osm-roads+geofabrik-shortbread-mbtiles-dhule-z14-ring1"
	# Preserve clip from roads converter if present
	if "clip_radius_m" not in game:
		game["clip_radius_m"] = CLIP
	GAME.write_text(json.dumps(game, separators=(",", ":")), encoding="utf-8")
	print(
		f"tiles={tiles} buildings={len(game['buildings'])} water={len(game['water'])} "
		f"landuse={len(game['landuse'])} pois={len(game['pois'])} flyovers={len(game['flyovers'])} "
		f"bytes={GAME.stat().st_size} clip={game.get('clip_radius_m')}"
	)


def _lines(geom) -> list[list[tuple[float, float]]]:
	if not isinstance(geom, dict):
		return []
	gtype = geom.get("type")
	coords = geom.get("coordinates") or []
	if gtype == "LineString":
		return [[(float(p[0]), float(p[1])) for p in coords]]
	if gtype == "MultiLineString":
		return [[(float(p[0]), float(p[1])) for p in line] for line in coords]
	return []


def _collect(decoded, tx, ty, buildings, waters, landuses, pois, flyovers, road_segs) -> None:
	for feat in decoded.get("buildings", {}).get("features", []):
		for ring in walk_rings(feat.get("geometry")):
			if len(ring) < 4:
				continue
			xz = [to_xz(*lonlat_from_tile(tx, ty, px, py)) for px, py in ring]
			xs = [p[0] for p in xz]
			zs = [p[1] for p in xz]
			cx = sum(xs) / len(xs)
			cz = sum(zs) / len(zs)
			if not inside(cx, cz):
				continue
			if on_carriageway(cx, cz, road_segs):
				continue
			w = max(xs) - min(xs)
			d = max(zs) - min(zs)
			if not (4 <= w <= 80 and 4 <= d <= 80):
				continue
			props = feat.get("properties") or {}
			kind = props.get("amenity") or props.get("shop") or "yes"
			h = 6.5 if props.get("shop") else 8.0
			buildings.append({"kind": kind, "x": round(cx, 2), "z": round(cz, 2), "w": round(w, 2), "d": round(d, 2), "h": h})
	for feat in decoded.get("water_polygons", {}).get("features", []):
		for ring in walk_rings(feat.get("geometry")):
			if len(ring) < 3:
				continue
			xz = [to_xz(*lonlat_from_tile(tx, ty, px, py)) for px, py in ring]
			cx = sum(p[0] for p in xz) / len(xz)
			cz = sum(p[1] for p in xz) / len(xz)
			if not inside(cx, cz, CLIP):
				continue
			xs = [p[0] for p in xz]
			zs = [p[1] for p in xz]
			ww = max(xs) - min(xs)
			dd = max(zs) - min(zs)
			if ww < 8 and dd < 8:
				continue
			waters.append(
				{
					"x": round(cx, 2),
					"z": round(cz, 2),
					"w": round(min(max(ww, 12), 220), 2),
					"d": round(min(max(dd, 12), 220), 2),
				}
			)
	# Rivers/canals as elongated patches (Panzara often tagged as water_lines)
	for feat in decoded.get("water_lines", {}).get("features", []):
		for line in _lines(feat.get("geometry")):
			if len(line) < 2:
				continue
			xz = [to_xz(*lonlat_from_tile(tx, ty, px, py)) for px, py in line]
			xs = [p[0] for p in xz]
			zs = [p[1] for p in xz]
			cx = sum(xs) / len(xs)
			cz = sum(zs) / len(zs)
			if not inside(cx, cz, CLIP):
				continue
			ww = max(max(xs) - min(xs), 14.0)
			dd = max(max(zs) - min(zs), 10.0)
			if ww * dd < 200:
				continue
			waters.append(
				{
					"x": round(cx, 2),
					"z": round(cz, 2),
					"w": round(min(ww, 220), 2),
					"d": round(min(dd, 80), 2),
				}
			)
	_LAND_MAP = {
		"residential": "residential",
		"commercial": "commercial",
		"retail": "retail",
		"industrial": "commercial",
		"grass": "grass",
		"farmland": "farmland",
		"park": "grass",
		"forest": "grass",
		"cemetery": "grass",
		"playground": "grass",
		"quarry": "farmland",
		"railway": "commercial",
	}
	for feat in decoded.get("land", {}).get("features", []):
		props = feat.get("properties") or {}
		raw = str(props.get("kind") or "")
		kind = _LAND_MAP.get(raw)
		if not kind:
			continue
		for ring in walk_rings(feat.get("geometry")):
			if len(ring) < 3:
				continue
			xz = [to_xz(*lonlat_from_tile(tx, ty, px, py)) for px, py in ring]
			cx = sum(p[0] for p in xz) / len(xz)
			cz = sum(p[1] for p in xz) / len(xz)
			if not inside(cx, cz):
				continue
			xs = [p[0] for p in xz]
			zs = [p[1] for p in xz]
			ww, dd = max(xs) - min(xs), max(zs) - min(zs)
			if ww < 12 or dd < 12:
				continue
			landuses.append(
				{"kind": kind, "x": round(cx, 2), "z": round(cz, 2), "w": round(min(ww, 160), 2), "d": round(min(dd, 160), 2)}
			)
	_POI_KEEP = {
		"fuel": "fuel",
		"hospital": "hospital",
		"clinic": "hospital",
		"doctors": "hospital",
		"bus_station": "bus_station",
		"marketplace": "marketplace",
		"place_of_worship": "place_of_worship",
		"school": "school",
		"college": "school",
		"university": "school",
		"bank": "bank",
		"police": "bank",
		"hotel": "marketplace",
		"cinema": "marketplace",
		"supermarket": "marketplace",
		"courthouse": "bank",
	}
	for feat in decoded.get("pois", {}).get("features", []):
		props = feat.get("properties") or {}
		raw = props.get("amenity") or props.get("shop") or props.get("tourism") or ""
		kind = _POI_KEEP.get(str(raw))
		if not kind:
			continue
		rings = walk_rings(feat.get("geometry"))
		if not rings or not rings[0]:
			continue
		px, py = rings[0][0]
		x, z = to_xz(*lonlat_from_tile(tx, ty, px, py))
		if not inside(x, z):
			continue
		pois.append({"name": props.get("name") or props.get("name_en") or kind, "kind": kind, "x": round(x, 2), "z": round(z, 2)})
	# Bus stops / stations from public_transport layer when present
	for feat in decoded.get("public_transport", {}).get("features", []):
		props = feat.get("properties") or {}
		rings = walk_rings(feat.get("geometry"))
		if not rings or not rings[0]:
			continue
		px, py = rings[0][0]
		x, z = to_xz(*lonlat_from_tile(tx, ty, px, py))
		if not inside(x, z):
			continue
		pois.append(
			{
				"name": props.get("name") or props.get("name_en") or "Bus stop",
				"kind": "bus_station",
				"x": round(x, 2),
				"z": round(z, 2),
			}
		)
	for feat in decoded.get("streets", {}).get("features", []):
		props = feat.get("properties") or {}
		if props.get("bridge") not in (1, True, "yes", "1"):
			continue
		kind = str(props.get("kind") or "")
		if kind not in ("primary", "secondary", "tertiary", "trunk", "motorway", "unclassified"):
			continue
		width = {"motorway": 12, "trunk": 11, "primary": 10, "secondary": 9, "tertiary": 8}.get(kind, 8)
		for line in _lines(feat.get("geometry")):
			if len(line) < 2:
				continue
			pts = []
			for px, py in line:
				x, z = to_xz(*lonlat_from_tile(tx, ty, px, py))
				if inside(x, z, CLIP):
					pts.append([round(x, 2), round(z, 2)])
			if len(pts) < 2:
				continue
			length = 0.0
			for i in range(1, len(pts)):
				length += math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1])
			if length < 35:
				continue
			flyovers.append({"kind": kind, "width": width, "length": round(length, 1), "points": pts})


if __name__ == "__main__":
	main()
