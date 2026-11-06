# 30 — Dhule geographic coverage

Read-only. No production scene, road file, mesh, vehicle, or `project.godot` was edited.

The Blosm mesh and the playable roads share one origin. The spawn is empty because that junction has almost no mapped buildings, not because the mesh is shifted. Most of the 1,866 footprints sit off the playable road extract.

## Sources and the shared origin

| Source | What it is |
| --- | --- |
| `data/dhule/roads.geojson` | 799 canonical ways from `assets/maps/dhulemap.osm` |
| `data/dhule/buildings.geojson` | 254 footprints from that same smaller extract |
| `data/dhule/places.geojson` | 81 named points from that extract |
| `assets/maps/dhule_roads_game.json` | 796 playable ways. Every id is in the canonical 799 |
| `assets/maps/dhule_city.osm` | 1,866 building footprints used for the mesh, plus the shop nodes |
| `data/dhule/city_shops.json` | The five OSM shop nodes |
| `assets/models/environments/dhule_blosm_city.glb` | The mesh exported from `dhule_city.osm` |

Origin in the game JSON, the shop file, `data/dhule/manifest.json`, and the Blosm exporter: latitude 20.902, longitude 74.777. X is east, Y is up, Z is south.

```
x = (lon - 74.777) * 111320 * cos(20.902°)
z = -(lat - 20.902) * 111320
```

Checked:

- Eight shared way ids match the GeoJSON first point within 6 mm. That is rounding, not a shift. Sample ids include `102664420` and the spawn way `102664423`.
- The mesh bounds are x −4323.5 to 2686.5, y 0 to 13.78, z −2835.9 to 4285.1. Footprint centroids span x −4313.1 to 2682.9 and z −2812.8 to 4279.4. The extra ~10 m is the wall thickness already described in doc 28. There is no axis flip and no city-wide scale error.
- `scripts/osm_road_builder.gd` `_latlon_to_xz` uses a sphere radius of 6,371,000 m instead of 111,320 m per degree. At 0.04° from the origin that is 4.7 m in X and 5.0 m in Z. The playable roads, the shops, and the mesh do not use that function. It only feeds `_add_real_spots`, which is skipped while the city mesh is loaded.
- The game file header says `clip_radius_m` 2000, and `tools/osm_to_game_json.py` still says 1,600 m. The points themselves run from x −3773.5 to 2370.1 and z −1682.5 to 3363.1. The geometry is the authority. The header and the old converter cap do not describe this file.
- The GeoJSON `bounds` tag is the original `dhulemap.osm` window (lat 20.890–20.910, lon 74.760–74.789). The way coordinates extend past that tag and match the game file. `places.geojson` only names points from that smaller window.

## 250 m grid

303 cells contain a road segment or a building centroid. Full table: `docs/qa/30-grid-coverage.json`. Map: `docs/qa/30-coverage-map.png` (north is up). White lines are playable centre lines. Orange dots are footprint centroids. Blue-grey cells have roads and no footprints. Brown cells have footprints and no playable road. Amber cells have both. Green cells contain one of the five shop nodes. The red cross is the current spawn. The green cross is the recommended spawn.

| Class | Cells | Meaning |
| --- | --- | --- |
| Roads, no footprints | 154 | Driveable streets with nothing mapped beside them |
| Footprints, no playable road | 83 | Building clusters the current network does not reach |
| Dense footprints on roads | 16 | 8 or more footprints and at least one playable way |
| Sparse street | 44 | A few footprints beside a way |
| Shop street | 4 | A mapped shop node plus footprints and a road |
| Footprints near a road, other cell | 2 | Centroid just outside the road's cell |

Road connectivity uses a 3 m snap of way endpoints. The same six components appear at a 1 m snap and at an 8 m snap, so the gaps are real.

- Main component: 183.1 km of centre line. The spawn and the recommended neighbourhood are both on it.
- Five residential stubs stay separate: `884985299` (171 m), `881944742` (112 m), `885874501` (62 m), `885874500` (51 m), `885874499` (42 m).

No duplicate road ids, no duplicate building ids, and no second way with the same rounded endpoints.

Land use is thin. Of 1,866 footprints, 1,850 are `building=yes`. Tagged residential: 7. Tagged commercial: 2. Schools 4, colleges 2, hospital 1. Named footprints: 22. A dense cell is a footprint cluster, not a proven residential zone. The only commercial signal that is safe to use is an actual shop tag.

## Current spawn

The playable spawn is (−13.09, −86.21).

| Check | Result |
| --- | --- |
| Nearest playable way | `102664423`, secondary, distance to centre line 0.0 m |
| On the main component | Yes |
| Inside a footprint | No |
| Footprints within 100 / 250 / 500 m | 0 / 2 / 10 |
| Shop nodes within 500 m | None. Nearest is the newspaper vendors node `10062229423`, about 900 m away |
| Named places within 500 m | Sanskar Homeopathic Clinic, Kamlabai Girls High School, and an OSM note that is not a landmark |

This is a mapped junction in a part of the extract where buildings were not drawn. It is a poor playable neighbourhood.

## Recommended neighbourhood

The strongest connected block is the 250 m cell from x −750 to −500 and z 750 to 1000. It has 62 footprints, 6 playable ways, and 8 junctions, and it is on the main component. It has no shop node inside the cell.

Recommended spawn, on the centre line, not inside a footprint, with buildings on both sides and no carriageway overlap within 50 m:

| Field | Value |
| --- | --- |
| Game metres | x −636.54, z 881.83, y 0 |
| Heading along the way (X, Z) | −0.720, −0.694 |
| Approximate WGS84 | 20.89408 N, 74.77088 E |
| OSM way | `887431550`, residential, unnamed |
| Footprints within 100 / 250 / 500 m | 43 / 85 / 154 |
| Either side, within 45 m of the way | 14 and 10 |
| Junctions within 80 m | 4 |
| Carriageway overlaps within 50 m | 0 |
| Named buildings within 500 m | Dhule District & Sessions Court, Malhar Bhaskar Deshpande |
| Named places within 500 m | Dhule, and the hospital points listed in `docs/qa/30-coverage-summary.json` |
| Shop nodes within 500 m | None. Nearest is Exide Battery `7330998411` at (−63.8, 1100.6), about 613 m away |

A second point on the same block, way `887431552` at (−465.97, 950.06), heading (0.052, −0.999), has 36 / 95 / 174 footprints, one junction within 80 m, and Exide Battery about 429 m away. Use it only if the next test wants that shop closer. It is the same neighbourhood, not a second city.

The highest raw footprint score was a different street: way `441423781` at (−895.79, −1404.18), 41 / 91 / 209 footprints, both sides occupied, INVESTMENTVALA about 333 m away, and Jai Hind College within 500 m. No junction falls inside 80 m, so it is the weaker drive.

## The three missing ways

All three are in `roads.geojson` and absent from the game file. Each is a 2-point stub about 7 m long, and both ends already meet a playable way (distance 0.0 m).

| Id | Tags | Length | Ends already touch |
| --- | --- | --- | --- |
| `880887781` | tertiary, `bridge=yes`, `layer=1` | 7.82 m | `880958590` and `880887782` |
| `887725190` | primary_link, no bridge tag | 6.82 m | `883678050` and `883678048` |
| `1426345742` | residential, no bridge tag | 7.92 m | `414759290` and `102664422` |

They are real OSM geometry. They do not open a new neighbourhood. `880887781` is the only one tagged as a bridge. Copying the three polylines in later would close 7 m gaps. It would not fill the empty spawn.

## Nine unmatched footprints

These are in `dhule_city.osm`. None of the 48,305 building-mesh vertices falls inside the polygon. The nearest vertex is 4.2–13.8 m away, the same gap as doc 28. They were not deleted.

| Id | Area m² | Road-edge distance | Nearest way | Mesh vertices inside |
| --- | --- | --- | --- | --- |
| `1485903708` | 78 | 1.62 m (beside the road, not in it) | `888082596` | 0 |
| `1527760283` | 255 | 21.1 m | `414759302` | 0 |
| `1527760270` | 102 | 164 m | `880554966` | 0 |
| `1527816133` | 173 | 163 m | `880554966` | 0 |
| `1527760215` | 79 | 227 m | `880554966` | 0 |
| `1527760232` | 320 | 228 m | `880554966` | 0 |
| `1527858172` | 155 | 1,228 m | `441423781` | 0 |
| `1527858168` | 130 | 1,243 m | `441423781` | 0 |
| `1527858312` | 111 | 1,288 m | `441423781` | 0 |

## Buildings against road edges

Distance is from the footprint polygon to the centre line, minus half the width stored on that playable way. A negative number means the polygon enters the carriageway. A building beside a road is not treated as an error.

Per-footprint rows: `docs/qa/30-building-road-validation.csv`.

| Relation | Count |
| --- | --- |
| Centre line enters the polygon | 0 |
| Polygon enters the carriageway, centre line stays outside | 48 |
| Clearance under 1 m | 46 |
| Clearance 1–2 m | 39 |
| Clearance 2–5 m | 92 |
| Clearance 5–15 m (ordinary frontage) | 101 |
| Clearance 15–40 m | 119 |
| No playable road within 40 m | 1,421 |

The deepest carriageway overlap is 3.38 m (`819424774` against residential `784704502`). Several of the 48 are large compounds, including `784708464` (about 4,060 m²) which clips primary `217392951` by 2.5 m. Those stay where OSM drew them. The stored width is an estimate, and the centre line does not pass through the polygon.

1,421 footprints have no playable road within 40 m. That is the brown area on the map. The roads for those blocks are not in this extract. They should not be invented.

## Smallest next step

Change only the spawn record in `assets/maps/dhule_roads_game.json` to the point on way `887431550`:

- position (−636.54, 0, 881.83)
- heading (−0.720, −0.694)

Do not move footprints, do not add streets, and do not retune the car. After that, drive the Sessions Court block and confirm the car is on the centre line with houses on both sides.

Leave the three 7 m stubs and the five orphan residential ways for a later, separate check. Leave the 48 edge overlaps and the nine unmatched shells unchanged.
