"""Fetch Mumbai Fort highway ways from Overpass (OSM ODbL). Offline fallback: PBF converter."""
from __future__ import annotations

import json
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "maps" / "mumbai_fort.osm.json"

SOUTH, WEST, NORTH, EAST = 18.920, 72.810, 18.945, 72.845

QUERY = f"""[out:json][timeout:90];
(
  way["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|service)$"]({SOUTH},{WEST},{NORTH},{EAST});
);
out geom;
"""


def main() -> None:
	url = "https://overpass-api.de/api/interpreter"
	print("fetching Overpass Mumbai Fort highways…", flush=True)
	body = urllib.parse.urlencode({"data": QUERY}).encode("utf-8")
	req = urllib.request.Request(url, data=body, method="POST")
	req.add_header("Content-Type", "application/x-www-form-urlencoded")
	req.add_header("User-Agent", "DriveViceCity/1.0 (OSM ODbL; local game prototype)")
	with urllib.request.urlopen(req, timeout=120) as resp:
		data = json.load(resp)
	els = data.get("elements") or []
	OUT.parent.mkdir(parents=True, exist_ok=True)
	OUT.write_text(json.dumps(data), encoding="utf-8")
	print(f"elements={len(els)} wrote {OUT} bytes={OUT.stat().st_size}")


if __name__ == "__main__":
	main()
