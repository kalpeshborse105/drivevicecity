"""Convert Overpass OSM JSON (out geom) into slim road JSON for Godot."""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "maps" / "dhule_roads.osm.json"
OUT = ROOT / "assets" / "maps" / "dhule_roads_game.json"

ORIGIN_LAT = 20.902
ORIGIN_LON = 74.777
METERS_PER_DEG_LAT = 111320.0
METERS_PER_DEG_LON = 111320.0 * math.cos(math.radians(ORIGIN_LAT))
CLIP_RADIUS = 900.0
# Prefer anchors inside this soft radius so spawn isn't on the map edge
CORE_RADIUS = 420.0

WIDTH = {
	"motorway": 14.0,
	"trunk": 12.0,
	"primary": 11.0,
	"secondary": 9.5,
	"tertiary": 8.0,
	"unclassified": 7.0,
	"residential": 7.0,
	"living_street": 6.0,
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


def clip_polyline(pts: list[list[float]]) -> list[list[float]]:
	runs: list[list[list[float]]] = []
	cur: list[list[float]] = []
	for p in pts:
		if inside(p):
			cur.append(p)
		elif cur:
			runs.append(cur)
			cur = []
	if cur:
		runs.append(cur)
	if not runs:
		return []
	return max(runs, key=len)


def heading_at(pts: list[list[float]], idx: int) -> list[float]:
	"""Unit forward vector in XZ (Godot forward ≈ this direction along road)."""
	if len(pts) < 2:
		return [0.0, -1.0]
	i0 = max(0, min(idx, len(pts) - 2))
	dx = pts[i0 + 1][0] - pts[i0][0]
	dz = pts[i0 + 1][1] - pts[i0][1]
	length = math.hypot(dx, dz)
	if length < 0.001:
		return [0.0, -1.0]
	return [round(dx / length, 4), round(dz / length, 4)]


def main() -> None:
	if not SRC.exists():
		raise SystemExit(f"Missing source OSM JSON: {SRC}")

	data = json.loads(SRC.read_text(encoding="utf-8"))
	elements = data.get("elements", [])
	roads: list[dict] = []
	min_x = min_z = 1e9
	max_x = max_z = -1e9

	for el in elements:
		if el.get("type") != "way":
			continue
		tags = el.get("tags") or {}
		hw = tags.get("highway")
		if hw not in KEEP:
			continue
		geom = el.get("geometry") or []
		if len(geom) < 2:
			continue
		pts = [to_xz(float(g["lat"]), float(g["lon"])) for g in geom]
		pts = clip_polyline(pts)
		if len(pts) < 2:
			continue
		if hw in ("residential", "service", "living_street") and len(pts) > 8:
			step = 2
			dec = pts[::step]
			if dec[-1] != pts[-1]:
				dec.append(pts[-1])
			pts = dec
		length = path_length(pts)
		if length < 18.0:
			continue
		for xz in pts:
			min_x = min(min_x, xz[0])
			max_x = max(max_x, xz[0])
			min_z = min(min_z, xz[1])
			max_z = max(max_z, xz[1])
		roads.append(
			{
				"id": el.get("id"),
				"name": tags.get("name") or tags.get("name:en") or "",
				"highway": hw,
				"width": WIDTH[hw],
				"points": pts,
				"length": round(length, 1),
			}
		)

	roads.sort(key=lambda r: (PRIORITY.get(r["highway"], 9), -r["length"]))
	major = [r for r in roads if PRIORITY.get(r["highway"], 9) <= 5]
	minor = [r for r in roads if PRIORITY.get(r["highway"], 9) > 5][:220]
	roads = major + minor

	# Build well-mapped anchors: mid-segments on longer roads, prefer city core
	candidates: list[dict] = []
	for r in roads:
		pts = r["points"]
		n = len(pts)
		indices = {0, n // 3, n // 2, (2 * n) // 3, n - 1}
		for idx in sorted(indices):
			idx = max(0, min(idx, n - 1))
			p = pts[idx]
			if not inside(p, CLIP_RADIUS - 40):
				continue
			hx, hz = heading_at(pts, idx if idx < n - 1 else n - 2)
			dist_core = math.hypot(p[0], p[1])
			pri = PRIORITY.get(r["highway"], 9)
			score = dist_core + pri * 35.0
			# Prefer core
			if dist_core > CORE_RADIUS:
				score += 200.0
			candidates.append(
				{
					"x": p[0],
					"z": p[1],
					"hx": hx,
					"hz": hz,
					"road": r.get("name") or r["highway"],
					"highway": r["highway"],
					"score": score,
				}
			)

	candidates.sort(key=lambda a: a["score"])
	filtered: list[dict] = []
	for a in candidates:
		if all(math.hypot(a["x"] - b["x"], a["z"] - b["z"]) > 70 for b in filtered):
			item = {k: a[k] for k in ("x", "z", "hx", "hz", "road", "highway")}
			filtered.append(item)
		if len(filtered) >= 24:
			break

	for r in roads:
		r.pop("length", None)

	# Spawn = best (lowest score) core anchor
	spawn = filtered[0] if filtered else {"x": 0.0, "z": 0.0, "hx": 0.0, "hz": -1.0, "road": "center"}

	payload = {
		"attribution": "© OpenStreetMap contributors (ODbL)",
		"origin_lat": ORIGIN_LAT,
		"origin_lon": ORIGIN_LON,
		"clip_radius_m": CLIP_RADIUS,
		"bbox_m": {"min_x": min_x, "max_x": max_x, "min_z": min_z, "max_z": max_z},
		"road_count": len(roads),
		"spawn": spawn,
		"roads": roads,
		"delivery_anchors": filtered,
	}
	OUT.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
	seg_est = sum(max(0, len(r["points"]) - 1) for r in roads)
	print(f"roads={len(roads)} segments~{seg_est} anchors={len(filtered)} out_bytes={OUT.stat().st_size}")
	print("spawn", spawn)
	print("bbox", payload["bbox_m"])


if __name__ == "__main__":
	main()
