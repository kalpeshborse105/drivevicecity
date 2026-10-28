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
CLIP = 900.0
Z = 14
EXTENT = 4096


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


def main() -> None:
	game = json.loads(GAME.read_text(encoding="utf-8"))
	# Cover the 900 m clip with z14 tiles (~1.5 km each).
	cx, cy = tile_xy(ORIGIN_LAT, ORIGIN_LON)
	con = sqlite3.connect(MBTILES)
	buildings: list[dict] = []
	waters: list[dict] = []
	landuses: list[dict] = []
	pois: list[dict] = []
	flyovers: list[dict] = []
	tiles = 0
	for dx in range(-2, 3):
		for dy in range(-2, 3):
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
			_collect(decoded, tx, ty, buildings, waters, landuses, pois, flyovers)
	con.close()

	buildings.sort(key=lambda b: math.hypot(b["x"], b["z"]))
	game["buildings"] = buildings[:320]
	game["water"] = waters[:24]
	game["landuse"] = landuses[:28]
	game["pois"] = pois[:18]
	flyovers.sort(key=lambda f: -f["length"])
	for item in flyovers:
		item.pop("length", None)
	game["flyovers"] = flyovers[:10]
	game["attribution"] = "© OpenStreetMap contributors (ODbL)"
	game["source"] = "osm-roads+geofabrik-shortbread-mbtiles-dhule-z14"
	GAME.write_text(json.dumps(game, separators=(",", ":")), encoding="utf-8")
	print(
		f"tiles={tiles} buildings={len(game['buildings'])} water={len(game['water'])} "
		f"landuse={len(game['landuse'])} pois={len(game['pois'])} flyovers={len(game['flyovers'])} "
		f"bytes={GAME.stat().st_size}"
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


def _collect(decoded, tx, ty, buildings, waters, landuses, pois, flyovers) -> None:
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
			waters.append(
				{
					"x": round(cx, 2),
					"z": round(cz, 2),
					"w": round(min(max(xs) - min(xs), 160), 2),
					"d": round(min(max(zs) - min(zs), 160), 2),
				}
			)
	for feat in decoded.get("land", {}).get("features", []):
		props = feat.get("properties") or {}
		kind = str(props.get("kind") or "")
		if kind not in ("residential", "commercial", "retail", "grass", "farmland", "park"):
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
			if ww < 18 or dd < 18:
				continue
			landuses.append(
				{"kind": kind if kind != "park" else "grass", "x": round(cx, 2), "z": round(cz, 2), "w": round(min(ww, 120), 2), "d": round(min(dd, 120), 2)}
			)
	for feat in decoded.get("pois", {}).get("features", []):
		props = feat.get("properties") or {}
		kind = props.get("amenity") or props.get("shop") or props.get("tourism") or ""
		if kind not in ("fuel", "hospital", "bus_station", "marketplace", "place_of_worship", "school", "bank"):
			continue
		rings = walk_rings(feat.get("geometry"))
		if not rings or not rings[0]:
			continue
		px, py = rings[0][0]
		x, z = to_xz(*lonlat_from_tile(tx, ty, px, py))
		if not inside(x, z):
			continue
		pois.append({"name": props.get("name") or props.get("name_en") or kind, "kind": kind, "x": round(x, 2), "z": round(z, 2)})
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
