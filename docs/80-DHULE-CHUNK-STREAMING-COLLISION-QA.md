# 80 — Chunk streaming collision QA (Phase 2H.4D)

**Baseline:** `cbe718e` · **Engine:** Godot 4.7.2 Forward+ · **GPU:** Intel UHD 620  
**Probe log:** `docs/qa/_81_two_chunk_log.txt`  
**JSON:** `docs/qa/80-two-chunk-collision.json`

## Stills

| Shot | File |
|------|------|
| Both neighbourhoods loaded | `docs/qa/79-two-chunk-both-loaded.png` |
| Street — first chunk | `docs/qa/80-two-chunk-street-A.png` |
| Street — second chunk | `docs/qa/80-two-chunk-street-B.png` |
| Chunk boundaries | `docs/qa/80-two-chunk-boundaries.png` |
| Collision debug | `docs/qa/80-two-chunk-collision.png` |
| Load / approach streaming | `docs/qa/80-two-chunk-streaming.png` |

## Tests

| Test | Result | Notes |
|------|--------|-------|
| Drive into loaded building (`1337953920`) | **PASS** | peak ≈43 km/h, traveled ≈9 m (stopped by wall) |
| Bodies after unloading B (A stays) | **PASS** | bodies_A=49, bodies_B=0 |
| Bodies after unloading A (B stays) | **PASS** | bodies_A=0, bodies_B=42 |
| Load B while approaching from A | **PASS** | both active after approach / force proximity |
| No ghost collision at unloaded A | **PASS** | `Chunk_pilot_n1` gone; bodies_A=0 |

49 bodies on A = 48 building hits + yard concave; 42 on B = 41 + yard.

## Policies checked

- Unload removes visuals **and** collision in one `queue_free` of the chunk host.
- No building collision placed on roads (pilots already clearance-validated; allow-list reused).
- Vehicle physics / InputMap unchanged for play — probe only injects `linear_velocity` / `engine_force` for deterministic contact.
- Mode B shadows: vehicle kit non-casters unchanged; ground/road non-casters; Blosm compare cast off; shell casts on.

## Streaming notes

Load radii drawn as cyan (A) / amber (B) rings at **480 m**. Nests remain **~910 m** apart, so standing in A keeps B unloaded until the player approaches the B origin.
