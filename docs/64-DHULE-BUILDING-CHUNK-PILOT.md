# 64 — Dhule building chunk pilot (Phase 2H.4B)

**Baseline:** `25d5a94` · **Engine:** Godot 4.7.2  
**Scene:** `scenes/dev/dhule_building_chunk_pilot.tscn` (not `main.tscn`)  
**Manifest:** `docs/qa/64-chunk-pilot-manifest.json` (61 candidates → **48 accepted**)

## Shadow fix (production, same PR)

Carnival kit shadows were casting from a **kilometre-scale** local AABB (`Object_835`) picked by local volume — a fake rectangular stamp. Fix in `player_car.gd`:

- Rank casters by **world** AABB after kit normalize.
- Keep two car-sized body meshes (~5×1.45×4.9 m).
- Soften sun: blur 1.5, opacity 0.72, max distance 90 m (`vfx_environment_controller.gd`, `dhule_shadow_policy.gd`).

Blosm giant mesh remains **cast off** (flicker policy). Chunk pilot buildings cast normally.

## Selection

| Field | Value |
|---|---|
| Chunk cell | (−2, 1) · 500 m |
| Spawn | (−636.54, 881.83) |
| Manifest candidates | 61 |
| Road-clearance rejects | 13 |
| **Accepted** | **48** |
| Styles | traditional_compact / plastered_house / narrow_urban |
| Height source | all **estimated** (no OSM levels/height on these ways) |

Selection tool: `tools/select_chunk_pilot_buildings.py`. Special tagged buildings (shop/school/…) excluded. No invented apartments/commercial.

## Architecture (doc 63)

- One batched `ArrayMesh` via `BuildingShell.add_neighbourhood` (7 surfaces, shared mats).
- Meta `osm_ids` on the shell mesh.
- Per-footprint `hit_<osm_id>` concave collision (accurate polygons; visual stays batched).
- Toggles: **V** chunk mesh · **B** Blosm compare · **I** OSM id labels · **G** collision debug.

Production Blosm / `main.tscn` / roads / spawn / vehicle physics **unchanged**.

## Stills

- `docs/qa/64-chunk-aerial.png`
- `docs/qa/64-chunk-street.png`
- `docs/qa/64-blosm-compare.png`
- `docs/qa/65-chunk-collision.png`

## Acceptance

| Check | Result |
|---|---|
| 40–64 real OSM footprints | 48 |
| Varied A/B/C styles | yes |
| Accurate rings | yes (manifest polygons) |
| Batched visual mesh | 1 shell, 7 surfaces |
| OSM IDs retained | yes |
| Road clearance ≥ 0.5 m | rejects recorded |
| Blosm not replaced | yes |
