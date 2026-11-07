# 53 — Vehicle physics regression report (Phase 2G)

## Scope

Phase 2G must not redesign drive feel. Compare local `scripts/player_car.gd` to GitHub baseline `dd60b197` / `origin/main`.

## Force / handling table (unchanged)

| Setting | Value |
|---|---|
| Default `engine_force_value` | 5200 |
| Profile range | 3200–9000 |
| `brake_force_value` | 35 |
| `suspension_stiffness` | 45 |
| `suspension_max_force` | 15000 |

`git diff` against baseline shows **no** edits to engine force, brake force, steering limits, suspension stiffness, or per-profile mass/force tables.

## Local WIP (not part of Phase 2G commit)

Unrelated working-tree edits kept unstaged unless the user asks to include them:

- Disable kit GLB tire spin (was tearing Camry/Safari/Carnival)
- Hide duplicate `VehicleWheel3D` meshes on kit bodies
- `_lift_to_road` after garage/showroom swaps
- Collision box lift so swaps do not dig into asphalt
- Safari normalize yaw `0` in `asset_kit.gd` (GLB already faces +Z)

These do not change arcade force numbers. Phase 2G collision tests used the same vehicle scene without retuning forces.

## Before / after drive (same road, same controls)

Audit approach runs on the placement course: peak ~10–14 km/h into solids, residual speed &lt; 1 km/h after contact. No physics retune was required to make solids work once `Solid_*` bodies were present and teleports stuck.
