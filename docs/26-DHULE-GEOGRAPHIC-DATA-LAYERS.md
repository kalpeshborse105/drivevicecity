# DriveViceCity — Phase 1B: Complete Dhule Geographic Data Layers

Date: 6 Nov 2026.

New layers were exported from `assets/maps/dhulemap.osm` by `tools/export_dhule_layers.py` version 1.0.0. `data/dhule/roads.geojson` and `data/dhule/buildings.geojson` were not rewritten. No game scene, map builder, game JSON, or vehicle script was edited. No commit, push, reset, or clean was run. No 3D generation was started.

A second run of the exporter wrote identical bytes for every new file. SHA-256 of the OSM source, the two existing GeoJSON layers, `assets/maps/dhule_roads_game.json`, `scripts/osm_road_builder.gd`, `scenes/main.tscn`, and the vehicle and gameplay scripts stayed the same.

## Verdicts

| Check | Result |
| --- | --- |
| Remaining 17 ways | PASS — 17 features, 0 missing, 0 extra |
| 81 tagged nodes | PASS |
| 4 route relations | PASS — member lists match the source in order |
| 2 boundary relations | PASS — tags and members match; geometry left null |
| Manifest | PASS |
| Existing canonical files untouched | PASS |
| Geometry valid where a geometry was written | PASS |

## Output files

| File | Features | Geometry |
| --- | ---: | --- |
| `data/dhule/waterways.geojson` | 2 | LineString |
| `data/dhule/natural.geojson` | 1 | Polygon |
| `data/dhule/landuse.geojson` | 4 | Polygon |
| `data/dhule/leisure.geojson` | 6 | Polygon |
| `data/dhule/railway.geojson` | 1 | LineString |
| `data/dhule/amenities.geojson` | 3 | Polygon |
| `data/dhule/places.geojson` | 81 | Point |
| `data/dhule/route_relations.json` | 4 relations | members only |
| `data/dhule/boundaries.geojson` | 2 | null |
| `data/dhule/manifest.json` | 11 layer entries | |

The three ways that were neither water, natural, landuse, leisure, nor railway are all `amenity` ways, so they are in `amenities.geojson`. Way ids do not overlap `roads.geojson` (799) or `buildings.geojson` (254).

File sizes: waterways 17,747 bytes, natural 23,699, landuse 5,851, leisure 8,154, railway 1,207, amenities 3,688, places 50,092, route relations 532,685, boundaries 6,088, manifest 2,220.

## 1. Remaining ways

Each feature keeps `way/{id}`, the integer OSM way id, ordered `node_ids`, and the full tag dictionary. Coordinates are `[longitude, latitude]` and match the source nodes. `name` is JSON `null` where the way has no name. Closed area rings were already closed in the OSM file, so no closing vertex was added. Shapely 2.1.2 reported every one of these 17 geometries valid. Unresolved node references: 0.

Waterways:

| Way | Tag | Name | Nodes |
| ---: | --- | --- | ---: |
| 166036681 | waterway=river | Panzara River (`alt_name` Panjhra) | 56 |
| 301935986 | waterway=river | none | 120 |

Natural:

| Way | Tag | Nodes |
| ---: | --- | ---: |
| 301905603 | natural=water, water=river | 225 |

Landuse:

| Way | Tag | Name | Nodes |
| ---: | --- | --- | ---: |
| 366646906 | industrial | none | 10 |
| 784704495 | cemetery | Malegaon Road Kabrastan | 7 |
| 815791119 | railway | none | 13 |
| 1562214993 | industrial | none | 7 |

`landuse=railway` on way 815791119 is an area. The rail line is a separate feature below.

Leisure:

| Way | Tag | Name | Nodes |
| ---: | --- | --- | ---: |
| 265572727 | stadium | none | 5 |
| 441426939 | pitch | none | 9 |
| 509653013 | swimming_pool | none | 5 |
| 784704489 | playground | none | 22 |
| 784704499 | swimming_pool | none | 5 |
| 1098922199 | track | Common cycling track | 5 |

Railway:

| Way | Tags | Nodes |
| ---: | --- | ---: |
| 667409697 | railway=rail, service=siding, gauge=1676, electrified=no | 4 |

Amenities:

| Way | Tag | Name | Nodes |
| ---: | --- | --- | ---: |
| 265573305 | bus_station | none | 5 |
| 482795252 | school | Cannosa Convent High School | 5 |
| 1276026223 | fuel | Bharat Petroleum | 6 |

The school way spells the name `Cannosa`. A separate place node spells `Canossa`. Both spellings are the source values.

## 2. Tagged nodes

`places.geojson` has the 81 nodes that carry at least one tag. Untagged way vertices were not copied in as extra points. A tagged node that a way also references is still one Point feature.

Classification, with no node counted twice:

| Tags present | Nodes |
| --- | ---: |
| amenity | 36 |
| railway | 4 |
| shop | 3 |
| place | 1 |
| tourism | 1 |
| leisure | 1 |
| highway | 1 |
| name and/or source only | 34 |

Amenity values: hospital 32, blood_bank 2, school 2. Shops: Exide Battery (`car_parts`), multiple local newspaper vendors (`newsagent`), Vishakha Dusane makeover (`beauty`). The place node is 245691673, `place=city`, name Dhule. Tourism is node 7330998457, Plaza, `tourism=hotel`. Railway points are three `level_crossing` nodes and one `buffer_stop`. The leisure node is Officer's club Swimming club, `leisure=swimming_pool`. The highway node is 13621972942, `highway=turning_circle`.

`place`, `amenity`, `shop`, `tourism`, and `name` are JSON `null` when that tag is absent. Every `tags` object matches the OSM node. Every coordinate matches the node. Duplicate node ids: 0. Every point is a valid Point.

## 3. Relations

`route_relations.json` holds four road routes. Tags and ordered members match `dhulemap.osm`, including empty roles, the one `road` role, and the `forward` roles. No route line was built. Most member ways are outside this extract, and a line through only the local ways would drop the rest of the route.

| Relation | Name | Members | Ways present in this OSM file |
| ---: | --- | ---: | ---: |
| 970785 | old National Highway 6 | 2,539 | 12 |
| 2885736 | Old National Highway 211 | 598 | 6 |
| 4033091 | SH14 | 78 | 5 |
| 17407512 | Asian Highway AH46 | 2,350 | 4 |

`boundaries.geojson` holds two administrative boundaries. Tags, roles, and member references match the source. Geometry is `null` on both features.

| Relation | Name | Outer ways in this file | Admin centre |
| ---: | --- | ---: | --- |
| 1985898 | Dhule (official name Dhule District) | 0 of 31 | node 245691673, present |
| 10327952 | Dhule Taluka | 0 of 6 | node 245691673, present |

The admin centre is the same city node already stored in `places.geojson`. It was not used as a stand-in polygon. The outer ways are not in `dhulemap.osm`, so the boundary rings cannot be assembled from this file.

## 4. Manifest

`data/dhule/manifest.json` records:

- `city_id`: `dhule`
- `display_name`: Dhule
- `crs`: WGS84 / EPSG:4326
- `origin`: latitude 20.902, longitude 74.777
- `source_filename`: `assets/maps/dhulemap.osm`
- `source_timestamp`: `null`
- `latest_element_timestamp`: `2026-11-05T08:21:22Z`
- `export_date`: `2026-11-06`
- ODbL-1.0 and © OpenStreetMap contributors
- exporter `tools/export_dhule_layers.py` version 1.0.0
- feature counts for the two existing layers and the nine new files

The OSM header from cgimap has a license and no extract timestamp. `source_timestamp` stays null for that reason. `latest_element_timestamp` is the newest `timestamp` attribute on a node, way, or relation in the file (relations 970785 and 17407512). It is not the export date.

## 5. Validation

- Way count 2 + 1 + 4 + 6 + 1 + 3 = 17, the same set as the non-highway, non-building ways in the OSM file.
- Place count 81, the same set as the tagged nodes.
- Relation count 4 routes + 2 boundaries, and no other relations exist in the file.
- Ids are unique inside each file. Exported way ids do not repeat a road or building id.
- Coordinates compared equal to the source longitude and latitude on every vertex and every place.
- Raw tag dictionaries compared equal on every way, place, route, and boundary.
- Missing names and missing place, amenity, shop, and tourism tags are JSON `null`. No height, level, roof, or width was filled in.
- Shapely reported the 17 ways and 81 points valid. Boundary geometry was left null instead of being marked valid or invalid.
- Route and boundary member arrays compared equal, in order, to the OSM members.
- `skipped_unresolved_ways` in the manifest is empty.
- Second export was byte-identical.

## 6. Production safety

Unchanged by this export: `assets/maps/dhulemap.osm`, `assets/maps/dhule_roads_game.json`, `data/dhule/roads.geojson`, `data/dhule/buildings.geojson`, `tools/export_dhule_geojson.py`, `scripts/osm_road_builder.gd`, `scenes/main.tscn`, `scripts/player_car.gd`, `scripts/hud.gd`, `scripts/game_bootstrap.gd`, `scripts/building_kit.gd`, `scripts/street_kit.gd`, `scripts/asset_kit.gd`, `scripts/game_settings.gd`, `scripts/minimap.gd`, and `project.godot`.

## Unresolvable geometry

Boundary polygons for Dhule District and Dhule Taluka cannot be built from this extract. All 37 outer ways are absent. The route relations also cannot be drawn as complete lines: 5,538 of 5,565 route members point at ways that are not in the file (2,527 + 592 + 73 + 2,346).

This phase stops here. The new files are source layers only. They are not wired into the playable map.
