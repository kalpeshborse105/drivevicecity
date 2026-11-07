# 66 — Chunk pilot performance (Phase 2H.4B)

Intel UHD Graphics 620 · 1280×720 · Godot 4.7.2 Forward+

## A. Synthetic architecture bench (fixed)

Probe: `scripts/dev/chunk_arch_bench.gd`  
Fix: use `look_at_from_position` (was `Node not inside tree`).

| Mode | FPS med | Draws | Objects |
|---|---:|---:|---:|
| A — 64 individual (2 meshes each) | 21 | 405 | 405 |
| B — 8 spatial chunks | **60** | **55** | 55 |
| C — B + distance hide | **60** | **1** | 1 |

Log: `docs/qa/_66_chunk_bench_log.txt`.  
Boxes are architecture proof only — not the real-geometry result.

## B. Real OSM chunk pilot (48 buildings)

Scene: `scenes/dev/dhule_building_chunk_pilot.tscn`  
Log: `docs/qa/_64_chunk_pilot_log.txt`

| Metric | Value |
|---|---:|
| Accepted buildings | 48 |
| Visual surfaces | 7 (shared mats) |
| FPS med (street sample) | **56** |
| Draws med | **127** |
| Objects | 210 |

## C. Blosm comparison (same camera)

Toggle **B** in the pilot scene. Still: `docs/qa/64-blosm-compare.png`.

| | Chunk pilot | Blosm neighbourhood view |
|---|---|---|
| Footprints | Exact OSM rings (48) | Joined city mesh (city-wide) |
| Draw style | Batched shell + labels/roads | 1–2 city meshes |
| Shadows | Chunk casts; soft sun | Giant AABB cast **off** (flicker policy) |
| Collision | Per-footprint concave | Trimesh on joined mesh |
| Production | Not wired into `main.tscn` | Unchanged source of truth |

## D. Production shadow cost (related)

After world-AABB kit shadow fix (Carnival):

- Casters on vehicle: **2** car-sized meshes (was 1 bogus giant).
- Sun: blur 1.5, opacity 0.72, max distance 90 m.

Does not change vehicle force tables.

## Gate for city-wide generation

Still closed. Next step is a larger neighbourhood pilot and production feature-flag — not 1,866 shells in `main.tscn`.
