# 81 — Two-chunk performance (Phase 2H.4D)

**Baseline:** `cbe718e` · **Engine:** Godot 4.7.2 Forward+  
**Display:** 1280×720 · **GPU:** Intel UHD Graphics 620  
**JSON:** `docs/qa/81-two-chunk-perf.json` · log `docs/qa/_81_two_chunk_log.txt`

Cameras differ per case (street nest vs high dual overview). **Do not** treat FPS deltas across cases as matched A/B proof of an optimisation.

## Cases (latest probe)

| Case | Active | Surfaces | Bodies | FPS med | Frame ms med | Draws med | Mem MB |
|------|--------|---------:|-------:|--------:|-------------:|----------:|-------:|
| A — first alone | n1 | 7 | 49 | **33** | 163 | 85 | 79.7 |
| B — second alone | n2 | 7 | 42 | **20** | 722 | 85 | 79.5 |
| C — both loaded | n1+n2 | 14 | 91 | **23** | 114 | 16 | 80.3 |
| D — A on, B off | n1 | 7 | 49 | **59** | 119 | 73 | 79.8 |
| E — B on, A off | n2 | 7 | 42 | **35** | 685 | 9 | 79.5 |
| F — both, far cam | n1+n2 | 14 | 91 | **46** | 194 | 80 | 80.3 |

Stills: `docs/qa/81-two-chunk-A-only.png`, `B-only`, `both`, `far-both`.

## Load / unload timings (mesh rebuild)

| Chunk | Typical load ms | Unload ms |
|-------|----------------:|----------:|
| `pilot_n1` (48) | ~1950–3450 | ≤1 |
| `pilot_n2` (41) | ~650–1100 | ≤1 |

Unload is near-instant (`queue_free`). Load cost is one-shot `BuildingShell` batch build — not repeated while the chunk stays resident.

## Observations

- Shared materials keep surface count at **7 per chunk** (14 when both loaded).
- Draw counts vary strongly with camera (far dual overview can report fewer draws than street nest).
- Case B/E frame-time spikes coincide with recent loads settling — report medians, not single frames.
- Streaming keeps the far nest out of the active set when the car stays at the other origin (~910 m).

## Acceptance

Both pilots operate through one manager with correct OSM IDs, synchronized collision, and measured streaming behaviour. Production Blosm / `main.tscn` unchanged.
