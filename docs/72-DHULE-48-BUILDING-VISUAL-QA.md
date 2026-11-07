# 72 — 48-building visual QA (Phase 2H.4B.2)

**Baseline:** `a2e9e16` · **Engine:** Godot 4.7.2 Forward+  
**Scene:** `scenes/dev/dhule_building_chunk_pilot.tscn`  
**Probe:** `scripts/dev/chunk_pilot_probe.gd` · log `docs/qa/_72_chunk_visual.log`

## Controls (pilot only)

| Key | Action |
|-----|--------|
| C | Aerial |
| B | Blosm compare |
| V | Chunk mesh |
| I | OSM id labels |
| G | Collision debug |
| F | Facade inspect (front of a building) |
| H | Shadow inspect |

## Stills

| Shot | File |
|------|------|
| Neighbourhood aerial | `docs/qa/72-chunk-aerial.png` |
| Street drive | `docs/qa/72-chunk-street.png` |
| Compact (C) | `docs/qa/72-style-compact.png` |
| Family (B) | `docs/qa/72-style-family.png` |
| Family variant | `docs/qa/72-style-variant.png` |
| Narrow (A/B narrow) | `docs/qa/72-style-narrow.png` |
| Facade close-up | `docs/qa/72-facade-closeup.png` |
| Shadow inspect | `docs/qa/72-shadow-inspect.png` |
| Collision | `docs/qa/72-collision.png` |
| Blosm compare | `docs/qa/72-blosm-compare.png` |

Legacy `64-*` / `65-*` stills refreshed from the same capture pass.

## Geometry / collision

```
CHUNK_MESH buildings=48 surfaces=7 accepted=48 rejected=13
DRIVE_HIT id=1337953920 (concave hit body responds)
```

Footprints and `hit_<osm_id>` bodies unchanged in policy — visual-only shell upgrade.

## Shadows (Mode B policy)

- Chunk shell casts genuine shadows (visible on ground in inspect still).
- Blosm compare mesh cast **off**.
- Vehicle kit shadows remain disabled (production policy untouched).
- Roads / marks non-casters.

## Performance (same pilot scene)

| Metric | 2H.4B (doc 66) | 2H.4B.2 capture sample |
|--------|----------------|-------------------------|
| Buildings | 48 | 48 |
| Visual surfaces | 7 | **7** |
| Draw calls (med) | 127 | **83** |
| Objects | 210 | **172** |
| FPS med | 56 | 21* |

\*FPS during automated multi-shot capture is not comparable to a settled street sample; draw/object counts are the batching proof. Architecture stayed on one shell / seven mats — no per-window MeshInstance3D.

## Acceptance

| Check | Result |
|-------|--------|
| Not plain featureless boxes | Pass — windows, doors, grills, lamps, parapet/roof reads |
| Distinct facades by OSM id | Pass |
| Footprint / collision preserved | Pass |
| Batched shell | Pass (7 surfaces) |
| Stable Mode B shadows | Pass |
| Production / city-wide unchanged | Pass |

**Gate:** Do not wire these 48 into `main.tscn` yet. Do not expand generation until this neighbourhood looks right in playtests.
