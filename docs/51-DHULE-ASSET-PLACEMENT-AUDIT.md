# 51 — Dhule asset placement audit (Phase 2G)

## Verdict

Unsafe automatic world props are off in production. Street-pack seed, unverified houses, real-spot statues/temples, landmarks scatter, and demo scenery are gated by `ALLOW_UNVERIFIED_WORLD_PROPS = false`. Approved assets use catalog scale + footprint validation; failures reject the object (no 12 m hop).

## Root cause of the screenshot giants

| Visible object | Runtime source | Cause |
|---|---|---|
| Huge red/white pole/sign | `street_asset_pack.glb` → node `give_way` | Pole on local Z; height-only Y scale → ~30×124 m (`BAD_EXAMPLE`) |
| Large dark block | same pack → `concrete_barrier` with Sketchfab parent scale | Hierarchy scale blew plan AABB to ~54 m |
| Small verge props | kit barriers / StreetKit lamps | OK when placed off asphalt |

Production no longer instances these via `_seed_street_pack()`.

## Controls

- Flag: `scripts/osm_road_builder.gd` → `ALLOW_UNVERIFIED_WORLD_PROPS`
- Catalog: `scripts/dhule_asset_catalog.gd` (per-asset expected size, collision, placement)
- Validator: `scripts/asset_placement_validator.gd` (≥0.5 m asphalt clearance, float/bury, plan/height caps, optional building/neighbour rings)
- Street pieces: mesh-only rebuild, upright Z-long props, then height scale clamped so plan ≤ 8 m

## Audit scene

`scenes/dev/dhule_asset_placement_audit.tscn`

- Raw vs normalized shelf + intentional BAD height-only example
- Approved course: wall, `barriers.glb`, `concrete_barrier`, `give_way`
- Road-overlap reject demo
- AABB + asphalt-edge debug lines

## Measured (1280×720, Intel UHD 620)

```
BAD_EXAMPLE size (30.38, 3.4, 123.93)
APPROVED barrier clear 27.96
APPROVED street_concrete_barrier clear 24.93 size 3.59×1.06×1.94
APPROVED street_give_way clear 24.72 size 0.83×3.4×0.09
REJECT_DEMO road_overlap clear -3.5
AUDIT_PLACEMENT approved 4 rejected 1
PERF audit_street fps_med 43.0 draws_med 166.0
```

Production probe: `STREET pack props 0`, `landmarks~0`, `demo_scenery~0`, spawn unchanged `(-636.5, 881.8)`, 796 ways.

## Screenshots

- `docs/qa/51-shelf.png`
- `docs/qa/51-approved.png`
- `docs/qa/51-clearance.png`
