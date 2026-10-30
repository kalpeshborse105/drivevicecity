# Dhule Visual Realism Pass — Change Log

Focused realism/polish pass on the existing DriveViceCity Dhule map.
Gameplay (vehicle physics, garage, missions, minimap, settings, Android
export) was left untouched. All changes are incremental edits to existing
files; no systems were replaced.

## Changed files

- `res://scripts/street_kit.gd`
  - Road decks now bake **painted lane-edge lines** into a second surface of
    the *same* mesh (`add_road_deck(..., edge_mat)` + `_flat_quad`). Crisp road
    edges with **zero extra MeshInstance3D nodes** (Android-safe). Edge lines
    are skipped for roads narrower than 5 m.
  - **Trees are batched** into two `MultiMeshInstance3D` (trunk + canopy) via
    `tree()` → queue, `flush_trees()`, `_commit_batch()`. Canopies use
    per-instance colors (`vertex_color_use_as_albedo`). ~188 individual meshes
    collapse to 2 nodes in the test case.
- `res://scripts/osm_road_builder.gd`
  - Passes the road-edge material into `add_road_deck`.
  - Calls `StreetKit.flush_trees(self)` after the map build.
  - Slightly richer asphalt tints (street_road / avenue_street) and a lighter
    concrete kerb color.
- `res://scripts/building_kit.gd`
  - Per-building **glass tint** drift (no two facades identical).
  - Projecting **window sills** (chhajja-style ledge) under every window.
  - Projecting **roof cornice** band just below the parapet.
- `res://scripts/vfx_environment_controller.gd`
  - Aerial haze (`fog_aerial_perspective`, `fog_sky_affect`) for depth.
  - Slightly stronger contrast/saturation.
  - Golden-hour preset retuned (deeper blue sky, warmer non-blown horizon).
- `res://scenes/main.tscn`
  - Sky/Environment/Sun base tuned to match the controller (ACES tonemap,
    ambient energy, fog aerial perspective, sun energy, shadow max distance).

## Created files

- `res://docs/dhule_visual_polish.md` (this file).

## Validation

- `tools/smoke_test.gd` (headless): **PASS** — 420 ways, 24 anchors,
  meshes=18199, static_bodies=722 (ratio well under the 0.55 guard).
- MultiMesh batching unit check: 60 trees → 2 nodes (188 instances).
- Road-deck check: 2 surfaces (asphalt + edge line), narrow roads = 1 surface.
- Live run of `res://scenes/main.tscn`: map builds, car drives (7 km/h),
  edge lines / sills / cornices / sky all render.

## Remaining limitations

- Redundant dead code remains (`_build_edge_lines`, `_build_center_dashes`,
  `_build_wear_patches`, `_build_zebra_and_breakers`) — lane markings/zebra come
  from the kit road textures; these helpers are unused.
- Sunset/crosswalk geometry is texture-baked, not OSM-junction derived.
- Streetlights and small props are still individual nodes (compound meshes);
  batching them would need a per-lamp MultiMesh refactor.
- No junction-specific turn lane / stop-line geometry.

## Best next task for further realism

Batch streetlights and small roadside props into `MultiMeshInstance3D` too
(they dominate remaining node count), then add OSM-junction-derived stop lines
and turn-lane markings so intersections read as real Dhule junctions.