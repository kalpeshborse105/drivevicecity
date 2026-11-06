# 42 — Dhule building prototype

`scenes/dev/dhule_building_prototype.tscn` builds 16 OSM footprints around the spawn. `scenes/main.tscn` does not load it. Roads, the car, and the spawn are the existing ones. The road scripts were not edited.

## What is verified

Each shell uses the OSM ring, not a replacement rectangle. All 16 are `building=yes` with no height and no shop tag. The body is named `hit_<way id>` and carries that id. A ray from (−638.7, 1.4, 886) hit `hit_1337953920` at (−638.7, 1.4, 892.26). The car was driven south into that face and stopped at (−638.52, 0.08, 890.23) with speed 0. The wall is on the ground. Nothing in this set is a floating label.

| OSM id | Corners | Area m² | Floors | Source | Front clearance m |
| --- | ---: | ---: | ---: | --- | ---: |
| 1337953920 | 17 | 75.3 | 2 | estimated | 4.64 |
| 1337953903 | 16 | 83.9 | 2 | estimated | 11.63 |
| 1337951730 | 12 | 76.7 | 2 | estimated | 12.51 |
| 1337951726 | 12 | 66.9 | 1 | estimated | 21.53 |
| 1337953921 | 17 | 75.4 | 2 | estimated | 21.46 |
| 1337953918 | 17 | 75.4 | 2 | estimated | 18.27 |
| 1337953904 | 16 | 84.0 | 2 | estimated | 24.46 |
| 1337953905 | 16 | 84.0 | 2 | estimated | 12.00 |
| 1337952466 | 12 | 76.7 | 2 | estimated | 4.73 |
| 1337953902 | 16 | 84.0 | 2 | estimated | 28.12 |
| 1337953919 | 17 | 75.4 | 2 | estimated | 12.46 |
| 1337951727 | 12 | 66.9 | 1 | estimated | 5.50 |
| 1337952468 | 12 | 76.7 | 2 | estimated | 28.33 |
| 1337951724 | 12 | 66.9 | 1 | estimated | 20.76 |
| 1337951722 | 12 | 66.9 | 1 | estimated | 43.27 |
| 1337952467 | 12 | 76.7 | 2 | estimated | 9.94 |

Neighbour gaps here are about 1.8 m, so the 0.9 m party-wall test did not hide any of these fronts. No selected edge crosses the asphalt.

## What is estimated

There is no `height` or `building:levels` on these ways. Area under 72 m² is one floor, wall height 3.55 m. Anything larger is two floors, wall height 6.25 m. Plaster colour, window spacing, the door, the parapet, and the roof tank are a reusable style in `scripts/building_shell.gd`. They are not a measured facade.

`building_shell.gd` also has shop, mixed, and civic branches: shutters and a blank board, or a plain civic wall. None of the 16 ways has a shop, amenity, or institutional tag, so those branches are not instanced here. No business name is generated.

The Sessions Court outline is verified and was left unmeshed. A prism of 17,178 m² would invent a building the courtyard does not have.

## How it is drawn

One mesh, five materials (plaster, roof, glass, dark, metal), for all 16 plans. The way id is on the collision body, not on a separate visual node. Sixteen concave bodies is acceptable for this block. It is the wrong shape for all 1,866 footprints: doc 35 already showed one node per building costing thousands of draws. A later city pass should keep one mesh per chunk and a side list of way ids. Collision for that pass should stay a chunk trimesh, with the per-id body reserved for the near block.

Walls are 0.28 m thick and include a parapet. Window glass and sunshades sit on the outer face. They do not cut the wall. The roof is the triangulated ring.

## Performance

Godot 4.7.2, Vulkan, Intel UHD 620, 1280×720. Same aerial camera.

| | FPS | Draws |
| --- | ---: | ---: |
| Prototype, first sample | 26.0 | 65 |
| Blosm building mesh, same camera | 51.8 | 62 |
| Prototype, later sample | 11.0 | 65 |
| Blosm, later sample | 8.8 | 62 |

Draw calls stayed flat. The first pair is the cleaner reading: the simple city mesh was faster. No improvement is claimed.

## Pictures

- `docs/qa/41-street.png` — chase view along the spawn road, shells beside the carriageway.
- `docs/qa/41-aerial.png` — the 16 stepped plans and the road.
- `docs/qa/41-facade.png` — street-level wall, parapet, and roof tank.
- `docs/qa/41-collision.png` — the car stopped short of way `1337953920`.

## Production

Not ready. Heights are estimates, the style is not a survey, and only 16 of 1,866 footprints are built. The joined Blosm mesh remains the city. Integrating this means a chunked mesh that still names each way, not a swap of `scenes/main.tscn` now.

## Left unchanged

`scenes/main.tscn`, `scripts/player_car.gd`, the road geometry and labels, the spawn, delivery logic, and the minimap. `SIGN_WORDS` was removed from `scripts/building_kit.gd` so fallback shopfronts are no longer given invented names.
