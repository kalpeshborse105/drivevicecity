# 28 — Dhule city map accuracy audit

Date: 2026-11-06

Godot 4.7.2.stable, Vulkan Forward+, Intel UHD Graphics 620.

This audit checks the Blosm city mesh against the existing road map. It does not move footprints, replace roads, edit canonical GeoJSON, or replace the vehicle.

## What is on screen

The production scene is still `scenes/main.tscn`. `project.godot` starts that scene. `DhuleMap` uses `scripts/osm_road_builder.gd`. When `assets/models/environments/dhule_blosm_city.glb` exists, that script places the mesh at the origin and skips the random box buildings, empty-lot fill, and spawn-street shops.

`scenes/dhule_blosm.tscn` is a separate viewer. It instances the same export (`assets/maps/dhule_blosm.glb`) and the player car. It does not build the road network. The alignment checked below is the production map, where both exist.

The 60-building Sessions Court drive test (`scenes/dev/dhule_block_drive_test.tscn`) is a different scene. It is not this city.

## Sources

| Source | Role | Count |
|---|---|---|
| OpenStreetMap via Overpass, saved as `assets/maps/dhule_city.osm` | Building footprints extruded by Blosm | 1,866 building ways, 11,278 nodes |
| `assets/models/environments/dhule_blosm_city.glb` | Mesh Godot loads. Copy: `assets/maps/dhule_blosm.glb` | 38,644 wall vertices, 9,661 roof vertices |
| `assets/maps/dhule_roads_game.json` | Playable roads and the old footprint list | 796 roads, 780 building records |
| `data/dhule/buildings.geojson` | Canonical building clip. Not edited | 254 ways |
| `data/dhule/roads.geojson` | Canonical road clip. Not edited | 799 ways |
| `data/dhule/city_shops.json` | The five OSM `shop` nodes | 5 |
| `assets/maps/dhulemap.osm` | Older, smaller OSM clip. Not the 1,866-way source | — |

Attribution on the extract and the shop list: © OpenStreetMap contributors, ODbL.

The mesh was made by Blender 4.5.5 with blosm 2.7.28, mode `3Dsimple`, buildings and water on, highways off. Origin set in the exporter: latitude 20.902, longitude 74.777. The addon stays outside the repo.

## Coverage

This is a district around the map origin, not the whole of Dhule.

Projected with the same formula as the roads:

- x east = (longitude − 74.777) × 111320 × cos(20.902°)
- z south = −(latitude − 20.902) × 111320
- y up

| Layer | Longitude | Latitude | Local metres (x east, z south) |
|---|---|---|---|
| Building footprints | 74.73543 to 74.80283 | 20.86351 to 20.92747 | centroids x −4313 to 2683, z −2813 to 4279 |
| Building mesh | same window, plus wall thickness | same window | x −4323.5 to 2686.5, y 0 to 13.78, z −2835.9 to 4285.1 |
| Playable roads | inside the JSON box | inside the JSON box | x −3773.5 to 2370.1, z −1682.5 to 3363.1 |

The road window is about 6.1 km east–west and 5.0 km north–south. The building mesh is about 7.0 km by 7.1 km because the Overpass download was padded by 0.01 degrees past the road clip. **915 building centroids sit more than 20 m outside the road bounding box.** Those footprints are real OSM ways. They do not have a matching road in the playable network.

All 254 canonical building IDs are inside the 1,866. The canonical road file has 799 ways. The playable file has 796. These three canonical road IDs are absent from the game JSON: `880887781`, `887725190`, `1426345742`. No game road ID is outside the canonical set.

## Coordinate check

Roads and buildings share the origin, the metre formula, x-east / y-up / z-south, and unit scale. The mesh bounds sit about 10 m outside the footprint-centroid bounds, which is the wall around each centroid, not a shifted city.

Of 1,866 footprints, **1,857 contain at least one mesh vertex**. Nine do not. Their nearest mesh vertex is 4.2 m to 13.8 m away:

`1485903708`, `1527760215`, `1527760232`, `1527760270`, `1527760283`, `1527816133`, `1527858168`, `1527858172`, `1527858312`.

All nine are `building=yes`. This is not a city-wide offset. It is nine outlines the inside-test did not catch. They were not moved.

The median distance from a footprint centroid to the nearest mesh vertex is 8.3 m. That is the empty interior of a hollow shell. The maximum, 78 m, is a large footprint whose centre is far from its walls.

OSM way IDs in `dhule_city.osm`: 1,866 unique, **no duplicate IDs**.

The game JSON’s 780 building records are a different list. 252 have an OSM id, and every one of those ids is in the city extract. **528 records have `id` null**, so they cannot be traced to a way. One id is repeated. Their stored heights (4 m, 6.2 m, 8 m, 10 m) are filled numbers. With the Blosm mesh loaded, those records are not built as boxes. The mesh is the geometry.

## Roads through buildings

5,101 road segments were tested against the footprint polygons.

- Road centre lines that enter a building polygon: **0**
- Footprints with a corner inside half the road width of a centre line, while the centre line stays outside the polygon: **41**

Those 41 are close to the carriageway. They were left where OSM put them.

No footprint is under 1 m².

## Building tags

Tags were classified only from `building=*`. `building=yes` stays unknown.

| Class | Count | OSM values |
|---|---|---|
| Unknown | 1,850 | `yes` |
| Institutional | 7 | school 4, college 2, hospital 1 |
| Residential | 4 | `residential` 2, `house` 2 |
| Apartment | 3 | `apartments` |
| Commercial | 2 | `commercial` |
| Industrial | 0 | — |

Named buildings: 22. `height` is null on all 1,866 ways. `building:levels` exists on three, and those values were kept:

- `482797271` Jai Hind College, college, 4 levels, no height
- `1193593171` Dr Babasaheb Ambedkar High School, Dhule, school, 2 levels, no height
- `1276028477` Rachana Hall, commercial, 2 levels, no height

Other named institutional footprints, with no level count: North Point School (`1098919784`), Dr Babasaheb Ambedkar Memorial College of Law, Deopur (`1193592151`), a second New City High School outline (`1276126020`), and an unnamed hospital (`441423829`).

Blosm’s `defaultLevels` weights (1, 2, and rarely 3 storeys) supply the mesh height where OSM has no height. Mesh tops run from about 4 m to **13.78 m**. Those heights are visual estimates. The source `height` field is still null.

Mesh inspection of `dhule_blosm_city.glb`:

- Two primitives on the building mesh: `wall` and `roof`. A third material, `water`, is a separate mesh.
- Wall colour is the Blosm default orange `(1, 0.5, 0.2)`. Roof is brown. No facade texture and **no UVs**.
- Wall normals are horizontal. Roof normals point up. A sample of 1,017 triangles had no degenerate faces.
- There is no window or door geometry. The five shops are the only storefronts, and they are a placed model, not part of this mesh.

The water mesh spans roughly x −6706 to 10028 and z −17514 to 5550. That is an OSM water way that was not clipped to the district. The loader hides a water mesh larger than 8 km so it does not paint across the roads. The three water records already in the game JSON are unchanged.

## Shops

Exactly five OSM `shop` nodes are placed, with the existing shop model and their own names:

| OSM node | Name | Tag | x, z |
|---|---|---|---|
| 7330998411 | Exide Battery | car_parts | −63.8, 1100.6 |
| 7655988175 | INVESTMENTVALA | supermarket | −599.6, −1252.5 |
| 10062229423 | multiple local newspaper vendors | newsagent | −915.4, −43.7 |
| 12401569297 | New Suranan Kirana Stores | grocery | −1121.0, −2046.8 |
| 14214421139 | Vishakha Dusane makeover | beauty | −1313.5, 492.2 |

No extra shops were generated. The production run logged `OSM shops placed: 5` and `shops~0` from the old street generator.

The shop file in the kit is documented as a 3 m street cart (`bhelpuri_shop.glb`), scaled here onto a 10 m × 8 m footprint. It marks the real shop coordinate. It is not a surveyed shop building.

## Vehicle

Not changed in this audit.

The production car is `scenes/player_car.tscn`, script `scripts/player_car.gd`. The drive test uses the same scene. Default profile 0 is a procedural sedan from `VehicleMeshBuilder`, not a downloaded GLB. Starting collision box is 1.9 × 1.2 × 4.4 m. Wheel radius is 0.38 m, wheel height 0.38 m, track ±0.85 m, wheelbase ±1.35 m. Mass 950 kg, engine force 640, listed top speed 145 km/h. The collision box is resized when a kit mesh is applied.

Other profiles load third-party GLBs listed in `docs/18-ASSET-CREDITS.md`: Kia Carnival, Tata Safari, a low-poly autorickshaw, a bus, a Tata truck, and a Camry. The credits table does not record a licence that allows those branded meshes to ship. Profile 4 is the autorickshaw GLB (normalized length 2.9 m).

Recommendation, not done here: the hero vehicle should be an original Blender model, or a mesh with a written CC0 or CC-BY licence. Prefer one Indian autorickshaw and one original car. Do not promote the Kia, Toyota, or Tata GLBs to the shipping car until a licence is on file. Keep the current physics until that mesh exists.

## Run

Command: Godot 4.7.2, `scenes/main.tscn`, window 1280×720, same Intel UHD 620.

The map finished with: 796 ways, 0 generated street shops, 190 props, 0 empty lots, 24 landmark labels, 8 road signs, 537 OSM features, 16 flyovers, 10 demo rocks, 8,863 batched visual boxes (kerbs, sidewalks, paint). Spawn `(−13.1, −86.2)`.

FPS after that build, five samples: **14, 14, 15, 14, 15**.

Four renderer errors, `Parameter "material" is null`, were printed. The process still exited 0.

Street, aerial, shop, and facade screenshots were not saved. The capture was stopped before the game window was grabbed. The log above is the run that did complete. Do not treat this document as a visual sign-off of facades.

## Defects

- The mesh is one district, not Dhule city-wide. 915 footprints fall outside the road clip.
- 1,850 of 1,866 buildings have no type beyond `building=yes`.
- Displayed height is a Blosm estimate. OSM `height` is null.
- Facades are flat orange walls. No UVs, no windows.
- The five shops are a scaled street cart at the real node, not a shop building.
- 41 footprints meet the carriageway edge. Centre lines do not enter buildings.
- Nine footprints failed the vertex-inside test.
- Three canonical roads are missing from the playable JSON.
- 528 game-JSON building records have no OSM id.
- The water way from Overpass is far larger than the district and is hidden.
- About 8,863 extra visual boxes remain. Measured frame rate is 14–15 FPS at 1280×720, not the building vertex count alone.
- Branded vehicle GLBs do not have a shipping licence in the credits file.

## Next phase

Do not generate more buildings until this district is accepted.

1. Keep the label “Dhule district extract”, with the bounding box above, anywhere the map is described.
2. Leave the 1,866 footprints and the 41 near-road outlines where they are.
3. Resolve the nine unmatched IDs and the three missing road IDs before expanding the clip.
4. A facade material can be shared across `building=yes` walls. It must not invent shop names or floor counts. The three real `building:levels` values can drive those three buildings; every other height stays marked as an estimate.
5. Replace the street-cart shop marker only at the five real nodes, with one shop model used for all five.
6. The frame-rate work is the 8,863 boxed kerb and sidewalk parts, then shadows, not a new building set.
7. Start an original autorickshaw and one original car in Blender. Do not swap physics in that first mesh pass.

## Workflow to keep

```
OpenStreetMap (ODbL)
    → GeoJSON for the canonical clip (ids, tags, rings, null heights kept)
    → district OSM for Blosm
    → Blender 4.5 + blosm, OSM 3D only, no Google 3D or satellite
    → one GLB: geographic shells
    → Godot on the existing road origin
```

Separate from that shell: reusable wall and roof materials, a shop model used only on tagged shops, landmark models only for named institutional ways, vehicles, and roadside props. Blender is for those original pieces. Blosm is for the OSM shells. No Google Maps, Earth, or Street View scrape, and no unofficial 3D tile dump.
