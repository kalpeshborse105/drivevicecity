# 24 — Mumbai Fort playable road prototype (isolated)

## Status

Isolated scene: `scenes/mumbai_playable_test.tscn`  
**Does not replace** Dhule `main.tscn` / `dhule_roads_game.json`.

## Road data (verified OSM)

| Item | Value |
|------|--------|
| Source | OpenStreetMap via Overpass (`tools/fetch_mumbai_fort_overpass.py`) |
| Raw | `assets/maps/mumbai_fort.osm.json` |
| Game JSON | `assets/maps/mumbai_fort_roads_game.json` |
| Attribution | `assets/maps/MUMBAI_ATTRIBUTION.txt` (ODbL) |
| Origin | 18.9322°N, 72.8264°E (Fort / Horniman Circle area) |
| Clip | ±900 m square (1 Godot unit = 1 m; +X east, −Z north) |
| Roads | 442 ways (222 majors) |
| Junctions (approx endpoint clusters) | ~525 |
| Spawn | Maharshi Karve Road (secondary) |

**Not used for roads:** `assets/incoming/mumbai_city.glb` (CC-BY-4.0 visual reference only; ~3 m import scale; no road graph/collision).

## Builder

`scripts/mumbai_city_builder.gd` — continuous road decks + per-segment collision boxes, edge paint, major curbs. Ground plane with collision. No buildings/trees in the driving corridor in this phase.

## Player

Reuses `scenes/player_car.tscn` / `player_car.gd` unchanged.

## Regenerate roads

```text
python tools/fetch_mumbai_fort_overpass.py
python tools/mumbai_osm_to_game_json.py
```

## Remaining before production city select

- Sidewalks / buildings off-corridor from OSM footprints  
- Delivery anchors + HUD/minimap wiring  
- City-select screen (Dhule vs Mumbai)  
- Traffic AI on left-side lanes  
- Optional visual dressing (not the miniature GLB as collision)
