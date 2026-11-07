# 77 — Second neighbourhood asset fit (Phase 2H.4C)

**Baseline:** `3b81cf7` · **Engine:** Godot 4.7.2  
**Pilot scene:** `scenes/dev/dhule_building_chunk_2_test.tscn`  
**Fit JSON:** `docs/qa/77-chunk2-asset-fit.json`  
**Prior inventory:** `docs/70-DHULE-BUILDING-ASSET-INVENTORY.md`

## Kit inventory (building-related only)

Re-inspected under `assets/kit/` — carts, barriers, road tiles and street packs are **not** buildings.

| File | Kind | Use on chunk-2? |
|------|------|-----------------|
| `buildings/indian_house.glb` | Complete residential shell (~5×5×5.16 m) | Geometry dry-fit only |
| `buildings/bhelpuri_shop.glb` | Cart / prop | **No** |
| `props/bullock_cart.glb` | Prop (broken scale) | **No** |
| `props/barriers.glb` | Road prop | **No** |
| `props/street_asset_pack.glb` | Prop pack | **No** |

No non-uniform stretching. No GLB placed into the live chunk mesh.

## Dry-fit vs 41 OSM footprints

`BuildingAssetFitter._fit_uniform` against `indian_house.glb` (area band 55–120 m²):

| Result | Count |
|--------|------:|
| Would fit uniform (geometry OK) | **5** |
| Procedural / out of band / no fit | **36** |
| **Pilot decision** | **all_procedural_batched_shell** |

Reason: chunk-2 must keep one batched `BuildingShell` (`surfaces=7`, shared materials). Instancing five GLBs would break the batching architecture under test.

## Architecture reuse

Unchanged modules:

- `scripts/building_shell.gd` — 7-surface batched ArrayMesh + collision subchunks  
- `scripts/dhule_building_styles.gd` — compact / narrow / plastered house  
- `scripts/building_asset_fitter.gd` — dry-fit audit only  
- `scripts/asset_placement_validator.gd` — asphalt clearance ≥ 0.5 m  

OSM-ID deterministic style variation remains in the selector + shell style mapping. Commercial styles appear only when OSM tags would allow them; this pocket has **no** shop/amenity/office ways.

## Collision / shadows

- Every accepted building contributes shell collision (`hit_<osm_id>` path via neighbourhood batch).  
- Mode B preserved: vehicle shadows off; road/ground helpers off; giant Blosm cast off; genuine building shell shadows allowed.  
- `DRIVE_HIT` on way `1527760280` at ≈19.7 km/h peak confirmed contact response.
