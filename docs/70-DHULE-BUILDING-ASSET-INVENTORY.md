# 70 — Dhule building asset inventory (Phase 2H.4B.2)

**Baseline:** `a2e9e16` · **Engine:** Godot 4.7.2  
**Probe:** `scripts/dev/building_asset_inventory_probe.gd`  
**JSON:** `docs/qa/70-building-asset-inventory.json`

## Building-related kit GLBs

| File | AABB (m) | Meshes | Mats | Collision in GLB | Kind | Fit 48-pilot? |
|------|----------|-------:|-----:|------------------|------|---------------|
| `buildings/indian_house.glb` | 5.0 × 5.0 × 5.16 | 2 | 2 | no | **complete building** | Geometry dry-fit OK on **16** area-band plots; **not used in pilot** |
| `buildings/bhelpuri_shop.glb` | 1.88 × 3.0 × 2.6 | 14 | 13 | no | prop / cart | **No** — not a building |
| `props/bullock_cart.glb` | 3.17 × 95.76 × 4.0 | 29 | 21 | no | prop / cart | **No** |
| `props/barriers.glb` | 5.9 × 1.7 × 5.32 | 9 | 1 | no | road prop | **No** |
| `props/street_asset_pack.glb` | 7.07 × 6.09 × 13.07 | 46 | 46 | no | prop pack | **No** |

Only `indian_house.glb` is a complete residential shell. Carts, barriers and street packs must never be stretched into footprints.

## Dry-fit vs pilot decision

`BuildingAssetFitter._fit_uniform` (area 55–120 m² band): **16** candidates could take a uniform house scale without polygon distortion.

**Pilot keeps 100% procedural batched shell** (`BuildingShell.add_neighbourhood`):

- One `MeshInstance3D`, **7** shared materials.
- Instancing 16 GLBs would break the single-shell batching goal.
- Road clearance / neighbour checks for live GLB placement remain in `building_asset_fitter.gd` for later optional use.

## Catalog notes

`dhule_asset_catalog.gd` already marks `indian_house` as footprint-only and `bhelpuri_shop` as verge cart. Unchanged.
