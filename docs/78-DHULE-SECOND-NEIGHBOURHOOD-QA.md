# 78 — Second neighbourhood QA (Phase 2H.4C)

**Baseline:** `3b81cf7` · **Engine:** Godot 4.7.2 Forward+ · **GPU:** Intel UHD Graphics 620  
**Resolution:** 1280×720  
**Scene:** `scenes/dev/dhule_building_chunk_2_test.tscn`  
**Probe:** `scripts/dev/chunk2_pilot_probe.gd` · log `docs/qa/_78_chunk2_log.txt`

## Controls (chunk-2 only)

| Key | Action |
|-----|--------|
| C | Aerial follow |
| B | Blosm comparison toggle |
| V | Chunk visibility |
| I | OSM ID labels |
| G | Collision debug |
| O | Footprint outlines |
| R | Road-clearance debug |
| F | Facade inspect |
| H | Shadow inspect |

`scenes/main.tscn` and production Blosm are **not** modified.

## Capture stills

| Shot | File |
|------|------|
| Aerial neighbourhood | `docs/qa/78-chunk2-aerial.png` |
| Street / drive view | `docs/qa/78-chunk2-street.png` |
| Style — plastered (family) | `docs/qa/78-chunk2-style-family.png` |
| Style — traditional compact | `docs/qa/78-chunk2-style-compact.png` |
| Style — narrow urban | `docs/qa/78-chunk2-style-narrow.png` |
| Facade close-up | `docs/qa/78-chunk2-facade.png` |
| Footprint outlines | `docs/qa/78-chunk2-footprints.png` |
| Collision debug | `docs/qa/78-chunk2-collision.png` |
| Road clearance | `docs/qa/78-chunk2-clearance.png` |
| Blosm compare | `docs/qa/78-chunk2-blosm.png` |

## Geometry / collision / clearance

```
CHUNK_MESH buildings=41 surfaces=7 accepted=41 rejected=0
CLEARANCE_REPORT accepted=41  margin=0.5 m
DRIVE_HIT id=1527760280 speed≈19.7 peak≈19.7
CHUNK2_FIT geometry_ok=5 procedural=36 decision=all_procedural_batched_shell
```

- Footprints are OSM outer rings with original way IDs recoverable via side buffer / labels.  
- No road overlap in accepted set (min validator clear ≈ **1.16 m**, min front clear ≈ **3.83 m**).  
- No individual runtime visual node per building — one batched shell, 7 surfaces.

## Performance (same machine, 1280×720, UHD 620)

Measured in the chunk-2 capture camera path (not claimed as an optimisation vs pilot 1 without matched framing):

| Metric | Chunk-2 (this run) | Chunk-1 reference (`_64_chunk_pilot_log`) |
|--------|-------------------:|------------------------------------------:|
| Accepted buildings | 41 | 48 |
| Surfaces | 7 | 7 |
| FPS median | **45** | 56 |
| Draw calls median | **82** | 127 |
| Objects | 179 | 210 |

Cameras and neighbourhood density differ; do **not** treat the FPS delta as a regression or win without a locked same-camera A/B.

## Pilot 1 vs pilot 2

| Topic | First pilot | Second pilot |
|-------|-------------|--------------|
| Cell / cluster | `(-2, 1)` | Dense pocket in `(-1, 3)`, seed `1527760280` |
| Distance | — | Median **~892 m** from first nest |
| Count | 48 accepted (13 rejected at runtime) | **41 / 41** (prefiltered) |
| Styles | compact / narrow / plastered mix | 13 / 1 / 27 |
| Heights | mostly estimated | **41 estimated** (no OSM height tags) |
| GLB fit candidates | 16 geometry OK (unused) | 5 geometry OK (unused) |
| Batching | 7-surface shell | Same architecture |
| Road clearance | validator ≥ 0.5 m | Same; denser prefilter |
| Visual | denser near first roads | quieter pocket; clearer aerial framing |

## Acceptance checklist

- [x] Second geographically distinct Dhule neighbourhood  
- [x] Real OSM footprints + preserved way IDs  
- [x] 40–64 buildings (41) with style variety  
- [x] Correct collision (`DRIVE_HIT`)  
- [x] No road overlap on accepted set  
- [x] Batched visuals, recoverable IDs  
- [x] Mode B shadow policy unchanged  
- [x] Production Blosm / `main.tscn` unchanged  
- [x] Repeatable probe + stills under `docs/qa/78-*`
