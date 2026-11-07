# 62 — Rendering optimization report (Phase 2H.4A)

**Goal:** Cut production draw cost without removing Blosm, roads, or gameplay.  
**Method:** Inventory → hide-category A/B → one-change experiments → apply only validated wins.

## Hide-category A/B (same spawn camera)

| Condition | FPS med | Draws | Prims |
|---|---:|---:|---:|
| BASE | 15 | 2426 | 1.94M |
| Hide Label3D | 16 | 2390 | — |
| Hide MultiMesh | 15 | 2409 | — |
| Hide Blosm | 16 | 2438 | 1.93M |
| Hide `object*` meshes | 16 | **128** | **0.84M** |
| Minimap SubViewport off | 16 | **1254** | 1.28M |
| Shadows off small AABB (&lt;8 m) | 16 | 2427 | — |

**Conclusion:** Draw-call cost is dominated by kit vehicle part meshes (`object*`) and by the minimap re-rendering the same world. Blosm is not the draw bottleneck. Labels / street MultiMeshes are noise at this scale.

## Isolated experiments (`perf_experiment_probe.gd -- --exp=…`)

Same resolution, spawn/long-road cameras, no combined flags.

| Exp | Spawn FPS | Spawn draws | Long-road FPS | Long-road draws |
|---|---:|---:|---:|---:|
| baseline | 14 | 2424 | 10 | 1595 |
| **vehicle_shadows** (1 caster) | 13 | **936** | **14** | **657** |
| **minimap_throttle** (UPDATE_DISABLED steady) | 11 | **1269** | 10 | **449** |
| shadow_distance 60 m | 9 | 2071 | 8 | 1584 |
| blosm_off | 9 | 2443 | 10 | 1623 |

Notes:

- `vehicle_shadows` kept the largest mesh (`Object_835`) casting; disabled 379 others. Physics unchanged.
- `minimap_throttle` matches the hide A/B draw drop (~half).
- `shadow_distance` and `blosm_off` did not beat baseline draws; Blosm stays on.

## Applied production fixes (validated, separate mechanisms)

### 1. `scripts/player_car.gd` — `_optimize_kit_shadows`

After kit GLB attach, only the largest-volume `MeshInstance3D` casts a shadow.

### 2. `scripts/minimap.gd` — ~8 Hz `UPDATE_ONCE`

Minimap no longer re-draws the full World3D every frame.

Garage closed preview remains `UPDATE_DISABLED` (from H3.1).

## After both fixes (production code, `exp=baseline` probe)

| View | FPS med | Draws | Prims |
|---|---:|---:|---:|
| spawn | **18** | **516** | 0.74M |
| long road | **18** | **237** | 0.66M |

Versus pre-opt spawn baseline in the same experiment harness: **14 FPS / 2424 draws → 18 FPS / 516 draws**.

Visual: vehicle still casts one soft shadow; minimap updates ~8 Hz (acceptable for GPS chrome). Collision / roads / Blosm / jobs unchanged.

## Not applied (and why)

| Idea | Result |
|---|---|
| Disable all building shadows | Rejected — Blosm already cast-off; shells are scarce |
| Hide / replace Blosm | No draw win; forbidden |
| Shared materials pass on all props | Deferred — vehicle parts dominate first |
| Spatial chunk of Blosm | Separate experiment only; see doc 63 |
| Reduce visual quality blindly | Rejected |

## Follow-ups (before city-wide generation)

- Kit vehicles still have hundreds of visible meshes (draws even without shadows). Consider kit LOD / merged body mesh later.
- Garage-open path still expensive if Home is left open.
- Re-run `production_perf_probe.gd` after any map density change.

Logs: `docs/qa/_62_experiments_log.txt`, `docs/qa/_62_exp_*.txt`, `docs/qa/_62_after_fixes_log.txt`.
