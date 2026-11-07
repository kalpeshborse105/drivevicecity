# 48 — Dhule asset inventory

New kit files from the phase-2E download commit were inspected in place. Nothing was renamed, moved, or deleted.

Units are Godot metres as imported (`nodes/root_scale=1.0`). AABBs below are raw mesh extents before any game normalize.

## Building candidates

| File | Location | Type | Raw AABB (m) | Meshes | Materials | Collision | Notes |
| --- | --- | --- | ---: | ---: | ---: | --- | --- |
| `indian_house.glb` | `assets/kit/buildings/` | Exterior house | 5.00 × 5.00 × 5.16 | 2 | 2 | none | Textured front; side uses the same atlas. Suitable as a family/cottage shell when the OSM ring can hold a square plan. |
| `indian_house_0.jpg` / `_1.jpg` | same folder | Albedo | — | — | — | — | Embedded dependencies of the house. |
| `bhelpuri_shop.glb` | `assets/kit/buildings/` | Street-food cart / small kiosk | 4.95 × 5.70 × 3.57 | 14 | 13 | none | Has an `AnimationPlayer`. Kit normalize targets 2.6 m longest side. Not a full shop footprint. |

## Street / road assets (not buildings)

| File | Location | Type | Raw AABB (m) | Meshes | Use |
| --- | --- | --- | ---: | ---: | --- |
| `street_asset_pack.glb` | `assets/kit/props/` | Prop pack (~56 MB, 138 PNGs) | 13.07 × 6.09 × 7.07 | 46 | Barriers, cones, signs, bins, barrels, trash. No house meshes. Missing some imported `.stex` warnings on load. |
| `road_segment.glb` | `assets/kit/roads/` | Road tile | 1.00 × 0.05 × 2.50 | 1 | Carriageway tile. |
| `road_divider_indian.glb` | `assets/kit/roads/` | Road diorama | 96.4 × 0.72 × 96.4 | 34 | Large divider slab, not a building. |
| `street_road.glb` | `assets/kit/roads/` | Long asphalt strip | 20.0 × 0.37 × 652.3 | 4 | Already used as road albedo source. |
| `sidewalk_8m.glb` | `assets/kit/sidewalks/` | Sidewalk strip | 1.54 × 0.36 × 8.12 | 2 | Already in the sidewalk kit. |

## Street pack contents (sample)

Top-level props under `Sketchfab_model/…/RootNode`: `red_barrier`, `concrete_barrier`, `Cardboard_Box`, `metal_barrier1/2`, `Cone`, `warning`, `give_way`, `stop`, `no_waiting`, `pole_1/2`, `Barrel`, `Bin`, `Hydrant`, `trashbag`, cups, bottles, shards. No residential, shop, apartment, school, or warehouse meshes.

## Existing kit already in the project

`bhelpuri_shop` was already mapped in `scripts/asset_kit.gd`. `indian_house` was added to `BUILDINGS` and normalized to an 8 m longest side for loose roadside decoration. Footprint fitting in this phase uses the raw ~5 m mesh and a uniform scale, not that 8 m preset, so the house can sit inside the smaller Dhule rings.

## Suitability for Dhule streets

- **Use for footprint fitting:** `indian_house.glb` only, and only when a uniform scale keeps its AABB inside the OSM polygon with ≥ 0.5 m asphalt clearance.
- **Reference / shelf only:** `bhelpuri_shop.glb` (cart), street pack props.
- **Do not place as buildings:** road tiles, road divider diorama, full street pack instance.
- **No GLB available yet** for apartments, warehouses, schools, hospitals, or multi-bay commercial shells. Those categories stay procedural or wait for tagged OSM evidence plus a suitable model.
