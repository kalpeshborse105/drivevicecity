# 20 — Dhule map expand audit (30 Oct 2026)

Audit only. **No** new downloads, physics changes, pipeline replacement, or gameplay edits.

Reference: OSM place [node 245691673](https://www.openstreetmap.org/api/0.6/node/245691673) — Dhule @ **20.8980°N, 74.7732°E**. Desired coverage = attached city overview (airport, Lake Nakane, NH52, Gondur, Panzara).

## Current playable bounds

| Item | Value |
|------|--------|
| Game origin | 20.902°N, 74.777°E |
| `clip_radius_m` | **1600** Ring 1 (square ≈ 3.2 km across) — was 900 |
| Game bbox (lat/lon) | Regenerated from converter (see JSON `bbox_m`) |
| Place node vs origin | ~395 m W, 445 m S — **inside** clip |
| Converter PBF window | 20.888–20.922 × 74.752–74.802 (~3.8×5.2 km) then clip |

## Local sources (checked, not re-downloaded)

| File | Format | Coverage note |
|------|--------|----------------|
| `western-zone-261027.osm.pbf` | OSM PBF (~222 MB), osmium OK | Geofabrik western zone; converter streams Dhule window only |
| `western-zone-shortbread-1.0.mbtiles` | MBTiles / MVT `format=pbf`, Shortbread 1.0, z0–14 (~521 MB) | Bounds ~67.7–80.9E, 14.4–24.7N; Dhule z14 tiles present (incl. airport / Nakane / NH52 / Gondur) |

## Game JSON feature inventory (`dhule_roads_game.json`)

| Feature | Count | Notes |
|---------|------:|-------|
| roads | 285 | 220 residential, 22 primary, 22 tertiary, 11 secondary, 10 unclassified |
| delivery_anchors | 24 | **Keep** when expanding |
| buildings | 320 | Cap from MBTiles merge |
| pois | 12 | Hospitals only in clip |
| flyovers | 6 | Shortbread `bridge` streets |
| water | 1 | 160×160 stub — not Panzara/Nakane |
| landuse | 0 | Empty; lots are procedural |
| Named roads | 15 | SH14, Sakri, Station, 80 Feet, MDR 46, Nakane Rd, … |

**Pipeline (do not replace):** PBF/Overpass → `tools/osm_to_game_json.py` (roads + spawn + anchors) → `tools/mbtiles_dhule_merge.py` (context layers only) → `scripts/osm_road_builder.gd`.

## Missing vs attached overview

Outside ±900 m but available in local PBF/MBTiles: Panzara corridor (~1.5 km N), Gondur (~5 km), Lake Nakane (~7.5 km SW), Airport (~8.7 km NW), NH52/Varkhede (~7 km E), Balapur/Fagne (~6.5 km). Landuse rows empty; fuel/school/bus POIs filtered out of current clip.

## Ring 1 implemented (30 Oct 2026)

- `clip_radius_m` **1600**; spawn + 24 anchors **pinned**
- Regenerated via `osm_to_game_json.py` + `mbtiles_dhule_merge.py` (local PBF/MBTiles only)
- Smoke: `SMOKE_TEST_RESULT=PASS` · meshes≈18952 · StaticBody≈558

## Context enrich (30 Oct 2026, later)

- MBTiles merge: stronger footprint corner clear, water dedupe, POI kind caps (hospitals ≤8), public_transport → bus POIs, land kinds +quarry/railway
- Builder: fewer outer lots/scrub; collision only near dense core → lower mesh/StaticBody counts
- Smoke: `PASS` · roads **420** · anchors **24** · buildings **513** · meshes≈18680 · StaticBody≈447 · `attr_ok`

## Remaining expand plan

1. **Corridors:** Majors only toward Sakri bypass / Station Rd — sparse residential outside Ring 1.
2. **Metro landmarks later:** ~6–8 km for Nakane / airport / NH52 after Ring 1 plays well; LOD/majors-only.

Still OSM + existing western-zone files only. No Google tiles.
