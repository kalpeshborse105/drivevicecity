# 61 — Production performance baseline (Phase 2H.4A)

**Baseline commit:** `97087e2` (H3.1)  
**Engine:** Godot 4.7.2 · Forward+ · Intel UHD Graphics 620 · **1280×720**  
**Scene:** `scenes/main.tscn` only (not synthetic QA)  
**Probe:** `scripts/dev/production_perf_probe.gd`

## Protect

| Item | Value |
|---|---|
| Branch | `main` @ `97087e2` |
| Blosm | Kept (`DhuleBlosmCity`) |
| Roads | 796 ways |
| Spawn | (−636.54, 881.83) |
| Vehicle physics exports | Untouched |

## Probe correction

Previous `PERF_NEAR_BUILDINGS` searched `BlosmCity` / `dhule_city` and skipped. Runtime path is:

`/root/Main/DhuleMap/DhuleBlosmCity`

The new probe discovers that node by name walk.

## Scene inventory (after boot)

| Metric | Count |
|---|---|
| MeshInstance3D | 934 |
| MultiMeshInstance3D | 12 |
| Label3D | 116 |
| SubViewports | 3 |
| Shadow casters on | 908 |
| Unique material instances | 608 |
| Blosm meshes / surfaces | 2 / 3 (cast off, giant AABB policy) |
| Road batch meshes | 4 |
| Top mesh name prefix | `object*` = **760** (kit vehicle parts) |

Bucket attribution (path walk):

| Bucket | Meshes |
|---|---|
| `garage_preview` | 389 |
| `player_car` | 388 |
| vehicle kit parts | 70 |
| Blosm | 2 |
| Roads | 4 |

## Controlled camera samples (pre-optimization)

| View | FPS med | FPS min | Frame ms | Draws | Objects | Prims | Static MB | Video MB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 01 spawn | 9 | 8 | 103 | 2446 | 2537 | 2.01M | 134 | 344 |
| 02 long road | 9 | 9 | 97 | 1614 | 1705 | 1.77M | 134 | 344 |
| 03 toward Blosm | 10 | 9 | 91 | 1254 | 1332 | 1.01M | 134 | 344 |
| 04 dense area | 8 | 8 | 105 | 2399 | 2482 | 1.99M | 134 | 344 |
| 05 open terrain | 10 | 9 | 85 | 1292 | 1381 | 1.19M | 134 | 344 |
| 06 garage closed | 8 | 4 | 112 | 2446 | 2537 | 2.01M | 134 | 344 |
| 07 garage open | **4** | 4 | **229** | **2877** | 3034 | 2.30M | 135 | 351 |
| 08 driving | 4 | 4 | 55* | 1232 | 1300 | 0.84M | 135 | 352 |

\* `TIME_PROCESS` underestimates GPU-bound frames while driving.

Logs: `docs/qa/_61_perf_baseline_log.txt`, `docs/qa/_61_cost_breakdown_log.txt`.

## Early bottleneck ranking (evidence, not guesses)

See doc 62 for hide-category and isolated experiments. Summary:

1. **Kit vehicle `object*` meshes** (~380 under `PlayerCar`) — draw-call and prim dominant.
2. **Minimap SubViewport** shares main `World3D` and re-drew every frame (~half of draws).
3. **Garage preview** when open (+~400 draws, FPS halves); closed already uses `UPDATE_DISABLED` (H3.1).
4. **Blosm joined city** — 2 draws, cast off; hiding it does **not** cut production draws.

City-wide building generation must wait until these production costs stay under control (doc 62/63).
