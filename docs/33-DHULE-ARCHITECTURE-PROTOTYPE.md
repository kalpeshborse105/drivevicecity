# 33 — Dhule architecture prototype (Phase 2B.6)

Separate inspection build for the Sessions Court neighbourhood. The production city is still `assets/models/environments/dhule_blosm_city.glb`. This prototype is not instanced from `scenes/main.tscn`.

Run the preview with Godot 4.7.2:

`scenes/dev/dhule_architecture_test.tscn`

WASD drives the existing `scenes/player_car.tscn`. C toggles an aerial camera. The chase camera in this scene stops 0.28 m before a wall hit. `scripts/player_car.gd` is unchanged.

## Selection

Projection is the game origin: 20.902 N, 74.777 E, X east, Y up, Z south. Footprints come from `assets/maps/dhule_city.osm`. Roads come from `assets/maps/dhule_roads_game.json`. Nothing was moved.

Pool: footprints within 130 m of the court centroid. 23 are listed in `validation.csv`. 13 are built. The other 10 stay in the CSV as `mesh_status=not_built` because the set is capped at 15. They were not removed from OSM.

All 23 rows are `status=estimated`. None of these footprints has an OSM height or `building:levels` value. Minimum road clearance in the pool is 1.56 m (way `1337951725`, nearest road `887431550`). No row has clearance under 0.3 m.

| OSM id | Role | Area m² | Height m | Clearance m |
| --- | --- | ---: | ---: | ---: |
| 482794524 | Sessions Court wing | 17177.82 | 8.24 | 3.93 |
| 1337951722, 1337951723, 1337951724, 1337951725 | 1-storey house | ~67 | 4.39 | 1.56–62.34 |
| 1337952467, 1337952468, 1337952469, 1337952470, 1337953921 | 2-storey house | ~76 | 7.44 | 8.88–70.29 |
| 1337953900, 1337953901, 1337953905 | 2-storey house | 84.01 | 7.44 | 11.82–68.90 |

Way `482794524` is a 4-corner outline, name “Dhule District & Sessions Court”, tag `building=yes`. A solid fill would cover the courtyard. The mesh is a 14 m wing around that outline. The interior is open. Collision matches the wing, not a solid prism. Height is estimated (2 floors, no OSM height).

The twelve houses are `building=yes` with no name and no shop tag. They are not labelled commercial.

## Shops

The five OSM shop records are all outside this block. Distances from the court centroid: Exide Battery 698.6 m, Vishakha Dusane makeover 727.8 m, multiple local newspaper vendors 1005.1 m, INVESTMENTVALA 2204.3 m, New Suranan Kirana Stores 3017.3 m. None is placed on a prototype footprint.

Kirana and commercial meshes exist only in the reusable library, at Godot X = 4500. They are not OSM buildings.

## Geometry

Placed houses use a plinth, wall shell, parapet, framed windows with a chajja, a door on the road-facing edge, and a roof tank with a stair block. Two-storey houses also get a balcony. Materials are shared procedural Principled colours (plaster, sand, civic grey, plinth, roof, door, frame, glass, metal, shutter, rail). No photo textures and no invented shop names.

Window openings are frames and glass sitting on the wall. The wall is not boolean-cut. Shells are hollow. Component GLBs (door, window, balcony, parapet, compound wall, gate, tank, stair, roof detail, shutter) are simple kit pieces in `reusable_assets/`, separate from the fitted footprints.

## Preview test

Godot 4.7.2, Vulkan 1.3.215 Forward+, Intel UHD Graphics 620, window 1280×720.

- Roads in view: 26 ribbons from the existing road JSON.
- Building colliders: 13 trimesh bodies, one per built footprint. First body reported 72 shape faces.
- Ray from (−608, 1.6, 916.2) to (−645, 1.6, 916.2) hit `hit_col_1337953905` at (−621.03, 1.6, 916.2).
- The car was spawned at (−608, 0.42, 916.2), heading west, and accelerated into that building. It stopped at (−618.98, 0.14, 916.22) with speed 0.02 m/s. It did not pass the wall. The gap from the origin to the hit face is the vehicle body.
- Street driving along road `887431550` stays on the ribbon. Buildings sit beside the carriageway.

Screenshots: `docs/qa/33-aerial.png`, `33-street.png`, `33-house.png`, `33-shop.png`, `33-driving.png`, `33-collision.png`. The shop frame is the library kirana shutter, not an OSM shop.

### FPS

Last paired sample on this machine, after the scene had loaded:

| View | Samples |
| --- | --- |
| Street chase, car driving | 26, 36, 34, 34 |
| Aerial | 37, 37, 36, 37 |

An earlier pass on the same meshes moved between 21 and 38 as the machine load changed. Buildings were not removed to raise the number. All 13 stay in memory. Materials are shared from the GLB. No extra LOD was added; these meshes are small enough that Godot’s default LOD does not drop them.

## What failed or is still estimated

- Every height is estimated. OSM does not supply height or levels here.
- The court mesh is a courtyard wing, not a reconstructed building.
- Ten nearby footprints are listed and not meshed.
- No real shop sits in this block, so the shutter photo is the library mesh.
- Walls are shells with applied frames, not cut openings. Glass transmission from Blender does not show as refractive glass in Godot.
- Compound walls and gates exist as kit pieces. They are not fitted around the OSM plots.
- `Material.use_nodes` in Blender 5.2.3 prints a deprecation warning. Export still completes.

## Warnings that were already in the project

- Autoload `res://osm_racer/scripts/game_lang.gd` fails to load. `project.godot` was not edited.
- Four `Parameter "material" is null` renderer messages on exit.

## Left unchanged

`scenes/main.tscn`, `scripts/player_car.gd`, `assets/maps/dhule_roads_game.json`, `assets/models/environments/dhule_blosm_city.glb`, and `data/dhule/`. No commit and no push.
