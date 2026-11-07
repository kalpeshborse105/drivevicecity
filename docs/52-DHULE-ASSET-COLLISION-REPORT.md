# 52 — Dhule asset collision report (Phase 2G)

## Rule

Solid catalog entries get a world-space `Solid_*` `StaticBody3D` sibling (`DhuleAssetCatalog.add_collision`). Do not call `_strip_physics()` on solids that must stop the car. Decorative entries (`blocks_vehicle: false`, e.g. cone) stay non-blocking on purpose.

## Collision types

| Asset | Collision | Blocks vehicle |
|---|---|---|
| `barriers.glb` / traffic barrier | box | yes |
| `street_pack:concrete_barrier` | box | yes |
| `street_pack:give_way` | capsule pole | yes |
| `street_light_mh.glb` | capsule pole | yes |
| indian house / bhelpuri cart | box | yes (placement gated) |
| `street_pack:cone` | none_decorative | no |

Layer/mask: `1` / `1` (matches default vehicle body).

## Drive-into tests (audit course)

Teleport uses `PhysicsServer3D` because `PlayerCar._physics_process` clears `freeze` every frame.

| Target | peak km/h | end km/h | min dist m | result |
|---|---|---|---|---|
| `test_wall` | 14.0 | 0.3 | 2.2 | stopped — `hit_test_wall` |
| `barrier` | 9.9 | 0.1 | 4.3 | stopped — `Solid_barriers` |
| `concrete_barrier` | 14.1 | 0.4 | 2.1 | stopped |
| `give_way` | 14.2 | 0.8 | 2.0 | stopped — `Solid_street_give_way` |

Screenshots: `docs/qa/52-hit-*.png`.

## Production

Blosm city mesh collision unchanged. Street-pack solids are not spawned (`props 0`). Roadside kit barriers that still place on the non-Blosm path keep collision instead of being stripped.
