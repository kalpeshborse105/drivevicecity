# 35 — OSM building identity pipeline

The partition is repeatable and the three replacements check out in an isolated preview. It is not ready for production integration. 136 footprints still have no confident mesh, 4,922 triangles stay unresolved, and the production GLB still has no per-building ids.

## Pipeline

`blender_work/dhule_city_pipeline/scripts/partition_buildings.py` reads `assets/maps/dhule_city.osm` and the production Blosm GLB. It writes only under `blender_work/dhule_city_pipeline/`. The production file is hashed and left untouched (`fe778f2e…7393d`).

Projection is the game projection: origin 20.902 N, 74.777 E, 111,320 m per degree, X east, Y up, Z south. A glTF position `(x, height, z)` is Godot `(x, height, z)`.

Phase 34 assigned a triangle when its centroid was inside a polygon or within 0.45 m of exactly one edge. That band can claim a neighbour wall. The gap between ways `1337953905` and `1337953919` is 1.84 m, so 0.45 m from each side can meet in the middle. This pipeline uses a stricter rule and does not guess:

- Every vertex is inside one way, or any vertex outside that way is at most 0.20 m from its edge.
- If no vertex is inside any way, the centroid’s nearest edge is at most 0.20 m and the second-nearest footprint is at least 0.50 m farther.
- Vertices in two ways: `ambiguous_multi_footprint`. The triangle is not split.
- An outside vertex more than 0.20 m from the only inside way: `crosses_boundary`. Kept whole.
- Nearest and second-nearest closer than 0.50 m: `ambiguous_margin`.

Wall and roof primitives stay on the shared `wall` and `roof` materials. Water is copied to `city_water.glb` and is not mixed into buildings. Roads are not read by the partitioner.

`export/buildings/<OSM_ID>.glb` is the archive (1,730 files). `buildings/.gdignore` stops Godot importing them. `grouped_joined.glb` is two nodes. `grouped_by_id.glb` is one node per exported id plus unresolved, with the way id in extras. The preview uses `neighbourhood_replaced.glb`.

## Triangle assignment

Source building mesh: 25,251 triangles. Water: 830 triangles, separate. OSM footprints: 1,866. Duplicate way ids in the OSM file: none.

| Reason | Triangles | Result |
| --- | ---: | --- |
| inside | 1,434 | assigned |
| boundary (within 0.20 m) | 11,499 | assigned |
| nearest edge, 0.50 m margin | 7,396 | assigned |
| crosses a boundary | 2,476 | unresolved |
| unmatched | 2,412 | unresolved |
| two footprints | 28 | unresolved |
| margin under 0.50 m | 6 | unresolved |

Assigned 20,329. Unresolved 4,922. Sum 25,251, equal to the source. Nothing is discarded. Exported ids: 1,730, with zero duplicate ids. The other 136 footprints are listed in `building_manifest.json` as `no_confident_triangles`.

Godot’s primitive counts on the same high camera agree with that split. The original GLB, which includes water, drew 26,981 primitives. The joined partition, without water, drew 26,151. The difference is 830, the water mesh. Roads and the ground plane are in both numbers.

## Replacements

The neighbourhood file keeps the 32 neighbour shells within 160 m of the court and swaps three ids for the detailed meshes from the architecture export. Raw nodes `1337951722`, `1337953905`, and `482794524` are absent. `1337953919` is present. Visual nodes are `bld_<id>`. Collision is a hidden `col_<id>` mesh with one body, `hit_col_<id>`. The visual mesh is not given a second body.

Godot’s glTF importer also attaches a default `StaticBody3D` under each `col_` node. Those three bodies sat on the same surface as `hit_col_*`, which is why an earlier ray at the court wing returned the name `StaticBody3D`. The preview removes those importer bodies before adding the named one. After that, each ray hits one body:

| Ray | Body | Point |
| --- | --- | --- |
| East of 3919, toward 3905 | `hit_1337953919` | (−614.01, 1.6, 916.2) |
| From the gap, toward 3905 | `hit_col_1337953905` | (−621.03, 1.6, 916.2) |
| Toward the single-storey house | `hit_col_1337951722` | (−658.40, 1.6, 928.3) |
| Toward the court wing | `hit_col_482794524` | (−697.92, 1.6, 946.0) |

`1337953919` is a real OSM building, not a leftover copy of `1337953905`. Its footprint is x −619.10 to −610.45, z 910.35 to 922.91 (45 confident triangles). `1337953905` is x −629.86 to −620.94. The facing edges are 1.84 m apart. An east ray hits 3919 first, inside 3919’s volume. The replacement collider is the next surface, at x −621.03. Spawning the car at x −617.2 put it inside 3919 and ejected it. That spawn is not used.

The car was driven into the single-storey house and stopped at (−656.35, 0.13, 928.35), speed 0.00. Neighbour shells on either side stayed. The court remains the open 14 m wing.

## Performance

Godot 4.7.2, Vulkan 1.3.215 Forward+, Intel UHD Graphics 620, 1280×720. The first three rows use one high camera at (−800, 2800, 700), far plane 14,000. The last row is the neighbourhood street camera after driving. It is a different view.

| | Original joined GLB | Partition, joined | Partition, one node per id | Neighbourhood with 3 replacements |
| --- | ---: | ---: | ---: | ---: |
| FPS samples | 35, 35, 35 | 59, 59, 59, 59 | 33, 33, 33 | 34, 34, 49, 49 |
| Objects in frame | 62 | 63 | 2,499 | 350 |
| Draw calls | 62 | 63 | 2,499 | 334 |
| Primitives | 26,981 | 26,151 | 21,040 | 224,106 |
| Video memory | 141.3 MB | 141.3 MB | 141.5 MB | 145.9 MB |
| Static memory | 68.3 MB | 68.3 MB | 109.2 MB | 78.4 MB |

The first original sample was 1 FPS while the mesh uploaded, then 35. The joined partition is faster on this camera because the original file also draws the large water mesh. One node per building costs 2,499 draws and 109 MB of static memory, and the frame rate drops to 33. That file is the id-preserving comparison, not the runtime to ship. The archive files and `grouped_by_id.glb` keep the way id. `grouped_joined.glb` is the draw-call shape that matches the current city.

The neighbourhood row includes the detailed architecture meshes, so its primitive count is not a city-wide total. Swapping three buildings inside the joined city mesh would add a handful of draws. That full-city swap was not built as a fourth GLB.

## Preview

`scenes/dev/dhule_city_pipeline_test.tscn` and `scripts/dev/dhule_city_pipeline_test.gd` instance the neighbourhood GLB and `scenes/player_car.tscn`. The car controller is unchanged. Roads are ribbons from `dhule_roads_game.json` (26 segments in this window). Collision bodies in the preview: 35. A label reads the body under the camera and strips the `hit_` / `hit_col_` prefix. Press C for the aerial camera.

Screenshots in `docs/qa/`:

- `35-aerial.png` — open court wing, detailed houses among the orange shells, car on the road.
- `35-street.png` — the same block from the road. The camera ray reports way `1337953921`.
- `35-house1.png` — the single-storey replacement. The label reads `1337951722`.
- `35-neighbour3919.png` — looking west from east of 3919. The label reads `1337953919`.
- `35-driving.png` — the car on the road through the block.
- `35-collision.png` — the car stopped against the single-storey house. The label still says Ground because the capture script had the scene’s process turned off.

The same pre-existing warnings appeared: missing `res://osm_racer/scripts/game_lang.gd`, and four `Parameter "material" is null` lines on exit.

## Remaining limits

- 4,922 triangles have no confident owner. They remain in `unresolved_geometry.glb`.
- 136 footprints have no confident triangles, so they cannot be swapped by id yet.
- Crossing triangles are not cut. Cutting them would invent an edge the Blosm mesh does not have.
- The production GLB is still one joined mesh with no extras. A later Blosm export with `singleObject` off still names objects from the `name` tag, not the way id, and must not overwrite `dhule_blosm_city.glb` until this conservation check passes.
- Heights on the three detailed models remain estimated.
- One GLB per building is the archive. Shipping it as the runtime mesh multiplies draw calls.

## Left unchanged

`scenes/main.tscn`, `scripts/player_car.gd`, `assets/maps/dhule_roads_game.json`, `assets/models/environments/dhule_blosm_city.glb`, and the production collision. No commit and no push.

## Production integration

Not ready. The identity cut is measured and the three replacements collide as their own way ids, with neighbour `1337953919` explained. Integrating it means replacing the production mesh while 136 footprints and 4,922 triangles are still unresolved, and while a future Blosm export would not keep this cut.
