# 29 — Dhule city placement cleanup

Production scene: `scenes/main.tscn`. Godot 4.7.2. Device: Intel UHD Graphics 620, 1280×720, Vulkan Forward+.

The real building mesh was already in the right place. The clutter was the road builder dressing the city a second time: sidewalks, kerbs, random carts, invented landmarks, demo rocks, and flyover decks with no bridge tag.

## Root cause of each reported problem

| Report | Cause |
| --- | --- |
| Houses inside roads | The road builder painted sidewalks, shoulders, and kerb boxes along every sampled way, and it scaled the street-food cart up to building size. OSM footprint centre lines do not enter building polygons (see doc 28). Those footprints were not moved. |
| Trees in the middle of roads | Trees were placed while later roads were still unsampled, so a verge tree for one way could sit on the next way. The clearance test only required 3.2 m of asphalt depth. |
| Shops inside houses, fake names | `place_shop_footprint` scaled `bhelpuri_shop.glb` (a ~3 m cart) to 5.5–14 m and dropped it on residential footprints. Names were not limited to the five OSM shop nodes. |
| Floating objects | Sixteen stored “flyovers” were drawn at y = 6.2 with only `kind` and `width` (no bridge tag). Scaled carts and barrier meshes sat above the ground. This district has no elevation model; playable ground is y = 0. |
| Props, signs, and breakers in the wrong place | Parked trucks, rickshaws, barriers, billboards, hoardings, dustbins, and speed-breaker boxes were random. There is no mapped breaker location. |
| Too many kerbs and sidewalks | `_build_curbs`, `_dress_road_sides`, shoulder boxes, and edge paint produced 8,863 visual boxes. |

## What changed

`scripts/osm_road_builder.gd`

- Every road is sampled before any tree or lamp is placed.
- With the Blosm mesh loaded, these generators return immediately: sidewalks, kerbs, shoulders, metal barriers, parked vehicles, billboards, hoardings, dustbins, planters, utility poles, landmarks, spawn-street dressing, demo rocks, and flyovers.
- Random speed breakers are disabled. `_build_zebra_and_breakers` returns without drawing.
- Trees stay, one side only, 9 m past the road edge, and only when the trunk is at least 5 m clear of every sampled asphalt edge and 4.5 m clear of the carriageway.
- Lamps stay off the asphalt (1.6 m clear when the city mesh is loaded).
- The five OSM shops use the cart at scale 1.0. If the node sits on asphalt it is moved 7 m off the facing road. The label is the OSM name, at 3.2 m, and only when that name is non-empty.
- The city mesh LOD bias is 128. Godot’s generated LODs were collapsing the 7 km mesh, so the blocks disappeared around the camera.
- Shop facing uses the road sample’s XZ position. The sample’s Y stores half-width, and using it as a height was picking the wrong centre line.

`project.godot` no longer autoloads `osm_racer/scripts/game_lang.gd`. Nothing in `scripts/` or `scenes/` called it. The `osm_racer/` folder was removed. `.gitignore` ignores that path if it comes back.

Canonical GeoJSON, `dhule_roads_game.json`, building footprints, and `scenes/main.tscn` were not edited. Vehicle physics was not edited.

## Objects removed or disabled (real city mesh loaded)

| Generator | Result |
| --- | --- |
| Sidewalks, kerbs, shoulders, lane barriers | Not built |
| Random speed breakers | Not built |
| Flyover decks (16 records, no bridge tag) | Not built |
| Landmarks, stalls, water towers, fake bridge, hand-placed spots | Not built |
| Demo rocks and edge scenery | Not built |
| Random shop carts and scaled shop buildings | Not built |
| Parked trucks, buses, rickshaws, billboards, hoardings, dustbins, planters, utility poles | Not built |

## Objects retained

- 796 playable road ways, deck and edge paint. Box batch fell from 8,863 to 100.
- Blosm mesh `dhule_blosm_city.glb`: 1,866 footprints, ground at y = 0, tops up to 13.78 m. Positions and OSM ids unchanged.
- Five OSM shops from `data/dhule/city_shops.json`: Exide Battery (`7330998411`), INVESTMENTVALA (`7655988175`), the newspaper vendors node (`10062229423`), New Suranan Kirana Stores (`12401569297`), Vishakha Dusane makeover (`14214421139`). Runtime log: `OSM shops placed: 5`.
- Verge trees and kerb lamps that pass the clearance test. Runtime: `props~34`.
- Eight road-name signs and the existing OSM feature labels (`osm_features~537`). Those labels are not new buildings.
- Building trimesh collision, so the car does not drive through the shells.

## Building and road checks (unchanged geometry)

From the doc 28 measurement, still true because no footprint or way was moved:

- 0 of 5,101 road-centre segments enter a building polygon.
- 41 footprints have a corner within half the road width while the centre line stays outside. Left where OSM put them.
- Nine `building=yes` footprints have no mesh vertex inside the polygon: `1485903708`, `1527760215`, `1527760232`, `1527760270`, `1527760283`, `1527816133`, `1527858168`, `1527858172`, `1527858312`. Nearest vertex is 4.2–13.8 m. Not deleted.
- Three canonical ways are still absent from `dhule_roads_game.json`: `880887781` (tertiary), `887725190` (primary_link), `1426345742` (residential). The network was not replaced to add them.

Spawn is `(-13.1, -86.2)`. Only one OSM building centroid is within 250 m of that point (`1276031266`, about 205 m away). The empty junction in the spawn shot is missing map data, not a hidden mesh.

## Trees, shops, floating, performance

- Tree rule: trunk must be 5 m outside the asphalt edge and 4.5 m outside the carriageway, on y = 0. The spawn view shows the remaining trees beside the junction, not in the lane. A per-tree distance table was not exported.
- Shops: five OSM nodes, real names, cart scale 1.0, not placed as a house.
- Floating: the 16 flyover decks at y = 6.2, the scaled carts, and the demo rocks are gone. Remaining props use `_ground_pos`, which sets y = 0 because there is no elevation grid. There is no separate before/after count of every floating node; those three generators were the floating set.
- Boxes: 8,863 before, 100 after.
- FPS after the map finished building, same machine and resolution: 13, 14, 15, 15, 14, 14, 14. The earlier run in doc 28, with 8,863 boxes and the building mesh collapsed by LOD, was 14–15. Drawing the full building mesh costs about the same as the old box batch. The four `Parameter "material" is null` renderer errors are still there.

## Screenshots

Taken from the production scene after this cleanup. The garage panel was hidden for the frame. The camera far plane was 8,000 m for the shot only.

- `docs/qa/29-aerial.png` — densest 80 m block in this extract, around `(-995, 2045)`, from 120 m up. Blocks sit on the ground and do not overlap each other. Roads are outside this courtyard frame.
- `docs/qa/29-drive.png` — camera 28 m from that same centroid. The frame is against a wall because that point is inside the block, not on a carriageway.
- `docs/qa/29-spawn.png` — spawn junction. Carriageway is clear. Trees sit off the asphalt. The nearest real buildings are the low shells on the horizon.

## Remaining defects

- Spawn has almost no mapped buildings. Most of the 1,866 shells are elsewhere in the district, and 915 centroids sit more than 20 m outside the road bounding box.
- Building height is still Blosm’s default level guess. OSM `height` is empty on these ways.
- The three missing road ids above are still missing. Adding them would be a network edit, which this pass did not do.
- The 41 near-edge footprints are still close to the carriageway.
- Nine footprints still have no interior mesh vertex.
- Road-name signs (8) were not re-audited one by one.
- The HUD opens the garage on start (`scripts/hud.gd`). That was left alone.
- The chase camera still has the 2.2 m minimum from `scripts/player_car.gd`. Physics were not changed.
- About 15 FPS on UHD 620 is the city mesh plus trimesh collision, not the old kerb batch.
- No Godot Asset Library pack was imported. The fix is the existing cart at its real size, not a new shop building.
