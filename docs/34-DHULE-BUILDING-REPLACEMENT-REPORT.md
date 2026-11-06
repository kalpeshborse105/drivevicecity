# 34 — OSM building identity and selective replacement

## Can the current Blosm mesh be replaced by id?

No. `assets/models/environments/dhule_blosm_city.glb` does not preserve OSM ids.

The file has two nodes and no extras:

| Node | Primitives | Material | Vertices |
| --- | --- | --- | --- |
| `dhule_city.osm_buildings` | walls, roofs | `wall`, `roof` | 38,644 |
| `dhule_city.osm_water` | one flat mesh | `water` | 838 |

Attributes on the building mesh are only `POSITION` and `NORMAL`. Blosm’s default is one joined object (`singleObject` defaults to true). Turning that off in a future export creates one object per building and copies OSM tags onto it, but the object name is the `name` tag or `element`, not the way id. A post-step would still have to write the way id. That export was not run, and the production file was not rewritten.

## How the three buildings were identified

Triangles in a test copy were matched to OSM polygons in the game projection (origin 20.902 N, 74.777 E, X east, Z south). A triangle belongs to a footprint when its centroid is inside that polygon, or within 0.45 m of exactly one polygon. Nothing was matched by guessing a mesh name.

All 1,866 OSM building footprints received at least one triangle. 191 triangles sat on no single footprint and 1 was ambiguous. Those 192 stayed in the neighbour mesh.

The three replacements, after the cut:

| OSM id | Role | Blosm triangles removed | Left inside the footprint | Road clearance | Height |
| --- | --- | ---: | ---: | ---: | --- |
| 1337951722 | single-storey house | 34 | 0 | 42.13 m to 887431550 | 5.86 m, estimated |
| 1337953905 | two-storey house | 46 | 0 | 11.82 m to 887431550 | 8.91 m, estimated |
| 482794524 | Sessions Court wing | 10 | 0 | 3.93 m to 278083125 | 8.24 m, estimated |

No other footprint centroid lies inside these three polygons. Ground contact of each detailed mesh is y = 0. The court outline is still the open 14 m wing from Phase 2B.6, not a solid fill of the 17,178 m² courtyard. None of the three is tagged as a shop.

## Preview

`scenes/dev/dhule_building_replacement_test.tscn` instances the test GLB, the existing car, road ribbons from the unchanged road JSON, a ground plane, and collision. The neighbour shells are the remaining Blosm mesh. The three detailed models replace only their own footprints. `scenes/main.tscn` and `scripts/player_car.gd` were not edited.

Godot 4.7.2, Vulkan 1.3.215 Forward+, Intel UHD Graphics 620, 1280×720.

| | Before (original joined mesh) | After (three shells replaced) |
| --- | ---: | ---: |
| FPS samples | 34, 34, 38, 38 | 38, 38, 36, 36 |
| Objects in frame | 161 | 252 |
| Draw calls | 134 | 222 |
| Primitives | 285,453 | 347,603 |
| Video memory | 149.0 MB | 148.3 MB |
| Static memory | 76.6 MB | 76.5 MB |

The test GLB has 7 meshes and 45,329 triangles. Collision bodies: 3 replacement prisms plus 1 trimesh for the remaining Blosm shells.

Rays:

- `1337951722` hit `hit_col_1337951722` at (−658.40, 1.62, 928.30). The car stopped at (−656.35, 0.13, 928.35), speed 0.00.
- `1337953905` hit `hit_col_1337953905` at (−621.03, 1.62, 916.20). From the road, a neighbouring Blosm shell is the first surface. The replacement collider is the next one. Placing the car in the narrow gap between them put it inside the neighbour volume.
- `482794524` hit `hit_col_482794524` at (−697.92, 1.62, 946.00), on the courtyard wing.

Screenshots: `docs/qa/34-aerial.png`, `34-street.png`, `34-house1.png`, `34-house2.png`, `34-court.png`, `34-neighbours.png`, `34-driving.png`, `34-collision.png`.

## What this does not yet allow

The joined production mesh still cannot be edited by id. This test copy can, because the polygons and the projection line up, and the check found zero leftover triangles inside the three footprints. Integrating that cut into `scenes/main.tscn` is not safe yet: 192 triangles have no unique owner, the court shell in Blosm was only 10 triangles, and a later Blosm re-export would not keep these edits. The durable path is a new Blosm export with separate objects and the way id stored on each object, then swapping those objects. That export must not overwrite the current production GLB until it has been checked the same way.

Heights remain estimated. Window and door frames sit on the walls; the walls are not boolean-cut. The same pre-existing warnings appeared: missing `res://osm_racer/scripts/game_lang.gd`, and four `Parameter "material" is null` lines on exit.

## Left unchanged

`scenes/main.tscn`, `scripts/player_car.gd`, `assets/maps/dhule_roads_game.json`, `assets/models/environments/dhule_blosm_city.glb`, and the production collision. No commit and no push.
