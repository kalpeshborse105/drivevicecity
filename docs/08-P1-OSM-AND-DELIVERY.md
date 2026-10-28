# 08 — P1: OSM Dhule roads + parcel delivery

## What P1 adds

1. **Real Dhule road layout** from OpenStreetMap (clipped ~900 m around city center)
2. **Parcel delivery loop**: green pickup → orange dropoff → ₹ cash → next job
3. HUD shows mission text, cash, delivery count, cargo state

## Playtest

1. Open `D:\drivevicecity` in Godot → **F5**
2. Spawn on OSM roads near first anchor
3. Drive into **green PICK UP** cylinder
4. Drive into **orange DELIVER** cylinder
5. Repeat; aim for **10 deliveries** without soft-lock (P1 exit criteria)

## Files

| Path | Role |
|------|------|
| `assets/maps/dhule_roads_game.json` | Slim roads + delivery anchors (ship this) |
| `assets/maps/ATTRIBUTION.txt` | ODbL credit |
| `tools/osm_to_game_json.py` | Rebuild game JSON from Overpass dump |
| `scripts/osm_road_builder.gd` | Build roads at runtime |
| `scripts/delivery_mission.gd` | Job loop |
| `scripts/delivery_zone.gd` | Pickup/drop cylinders |
| `scripts/game_bootstrap.gd` | Wire map → car spawn → missions |

## Regenerate map data

```powershell
# Download (example Overpass):
curl.exe -A "DriveViceCity/0.1" -X POST `
  -d "data=[out:json][timeout:45];way[""highway""](20.888,74.755,20.920,74.795);out geom;" `
  -o assets/maps/dhule_roads.osm.json `
  "https://overpass-api.de/api/interpreter"

python tools/osm_to_game_json.py
```

Then press F5 in Godot.

## Notes

- Roads are **visual strips** on a flat collider ground (fast on PC/phone later).
- Buildings are sparse placeholders beside some streets — not OSM footprints yet.
- Procedural P0 grid (`dhule_block_builder.gd`) is unused in main scene but kept for reference.
