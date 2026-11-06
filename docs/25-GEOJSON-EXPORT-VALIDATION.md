# DriveViceCity — Phase 1A: GeoJSON Export Validation

Date: 6 Nov 2026.

Read-only check of `tools/export_dhule_geojson.py` against `assets/maps/dhulemap.osm` and the two files it writes. No game scene, map builder, game JSON, vehicle script, or asset was edited. No commit, push, reset, or clean was run.

The exporter was run a second time only to test determinism. That run rewrote the same two GeoJSON files with identical bytes. The OSM file hash stayed the same.

## Verdicts

| Check | Result |
| --- | --- |
| 1. `roads.geojson` | PASS |
| 2. `buildings.geojson` | PASS |
| 3. Geographic accuracy | PASS |
| 4. Exporter quality | PASS for these two layers |
| 5. Production files left untouched | PASS |

These two files are a faithful copy of the highway ways and building footprints in `dhulemap.osm`. They are the right canonical source for those two layers. They are not a complete Dhule geographic database: route relations, boundaries, water, landuse, amenities, and node places are still only in the OSM file, and building height is absent there too.

## 1. Roads — PASS

`data/dhule/roads.geojson` is 973,049 bytes.

- Type `FeatureCollection`, name `dhule-roads`, 799 features.
- OSM highway ways in the source: 799. Missing from GeoJSON: 0. Extra features: 0.
- Every feature id is `way/{osm_id}` and matches `properties.osm_id`. Duplicate way ids: 0. Duplicate feature ids: 0.
- Every `node_ids` list matches the OSM `nd` refs in order, and each coordinate equals that node’s longitude then latitude. Coordinate mismatches: 0. Node-order mismatches: 0.
- `properties.tags` equals the OSM tag dictionary on all 799 ways.
- Empty geometries: 0. Null geometries: 0. LineStrings with fewer than 2 positions: 0. Coordinates outside WGS84 range: 0. Latitude/longitude swaps: 0. Consecutive duplicate positions: 0.
- Shapely 2.1.2 reported all 799 geometries valid LineStrings.

Highway values: residential 624, tertiary 46, service 46, primary 32, secondary 26, unclassified 23, primary_link 1, trunk_link 1.

Tag counts inside `properties.tags`:

| Tag | Ways |
| --- | ---: |
| highway | 799 |
| name | 41 |
| oneway | 67 |
| lanes | 7 |
| bridge | 17 |
| tunnel | 0 |
| surface | 10 |
| width | 0 |

`oneway=yes` is on 64 ways and `oneway=no` is on 3 ways. `lanes` is `2` on 6 ways and `1` on 1 way. `bridge=yes` is on 17 ways. `surface=asphalt` is on 10 ways. No highway way in this file has `width` or `tunnel`, so those keys are absent in the raw tags as well. Other preserved keys include `source` (649), `ref` (30), `layer` (17), `ref:old` (14), and smaller sets for `kerb`, `lane_markings`, `lit`, `shoulder`, `sidewalk`, `name:ur`, and `junction`.

Promoted fields `highway`, `name`, `oneway`, `lanes`, `bridge`, and `tunnel` match the raw tag or are JSON `null` when the tag is absent. Mismatches: 0.

Unique road names (15), across 41 named ways: 80 Feet Road, Collector Office Road, Dhule Malegaon Road, Loha Bazzar Road, Madhura Lane, Major District Road 46, Nakane Road, Other District Road 106, Panjhara Dr Road, Red Cross Road, Sakri Road, Shivaji Road, State Highway 14, Station Road, Veer Savarkar Marg.

Road coordinate extent (longitude, latitude): 74.7407143, 20.8717885 to 74.799791, 20.9171136. Position count: 5,903.

## 2. Buildings — PASS

`data/dhule/buildings.geojson` is 353,239 bytes.

- Type `FeatureCollection`, name `dhule-buildings`, 254 features.
- OSM building ways in the source: 254. Missing from GeoJSON: 0. Extra features: 0. Ways tagged both `highway` and `building`: 0.
- Every feature id is `way/{osm_id}` and matches `properties.osm_id`. Duplicate ids: 0.
- Every ring is closed: the first and last coordinates are the same, and the OSM way was already closed. The exporter’s close-the-ring step added no points on this file.
- Each ring is a single exterior. Holes: 0. Rings shorter than 4 positions: 0. Open rings: 0. Zero-area rings: 0. Consecutive duplicate vertices: 0.
- Edge checks found no non-adjacent crossings and no collinear overlaps. Shapely 2.1.2 reported all 254 polygons valid.
- `properties.tags` equals the OSM tag dictionary on all 254 ways. Tag mismatches: 0. Coordinate mismatches: 0.

Building values: `yes` 248, residential 2, commercial 2, school 2.

Height, levels, and roof:

| Field | Present | Absent |
| --- | ---: | ---: |
| `height` / `properties.height` | 0 | 254 |
| `building:levels` / `properties.levels` | 1 | 253 |
| `roof:shape` / `properties.roof_shape` | 0 | 254 |

The one levels value is the string `"2"` on way 1276028477, Rachana Hall, `building=commercial`, `addr:street=NH53`. No feature received a default height, level count, or roof shape.

Twelve buildings have names: Adivasi Vikas Prakalpa Office, Apala Maharashtra Paper Office, Dhule District & Sessions Court, Malhar Bhaskar Deshpande, Muncipal corporation Dhule, New City High School, Pitru Chhaya Apartment, Prakash Cinema Theatre, Rachana Hall, Radhey Apartment, Swastik Theatre. The source spelling `Muncipal` is preserved.

Other preserved building tags include `addr:city` (12), `addr:street` (12), `addr:district` (10), `amenity` (3), and `office` (3).

Building coordinate extent: 74.7595064, 20.8897778 to 74.783442, 20.90894. Position count, including each closing vertex: 2,223.

## 3. Geographic accuracy — PASS

Coordinates are WGS84 in GeoJSON order, longitude then latitude. Every exported position matches the referenced OSM node exactly as parsed from the XML decimals. Feature counts and way ids match the source highway and building ways, as listed above.

The OSM `<bounds>` element is:

- latitude 20.8900200 to 20.9099000
- longitude 74.7597700 to 74.7889600

The file’s nodes extend past that window. Full node extent: longitude 74.7125083 to 74.8505389, latitude 20.8615743 to 20.9410253. Of 6,979 nodes, 1,290 lie outside `<bounds>`:

- 946 are referenced by highway ways
- 25 are referenced by building ways
- 319 are referenced by the other 17 ways

Exported features that include at least one of those vertices:

- 128 roads. All 128 also have vertices inside the window. None sit entirely outside it.
- 6 buildings. All 6 also have vertices inside the window. The farthest building vertex is about 27 m outside (way 819424773).

Distance of the farthest vertex on each overflowing road, using 111,320 m per degree of latitude and `111,320 * cos(20.902°)` per degree of longitude:

| Farthest vertex | Count of ways |
| --- | ---: |
| 1–20 m | 18 |
| 20–100 m | 45 |
| 100–500 m | 35 |
| 500 m or more | 30 |

Largest road overflows:

| Way | Kind | Name | Ref | Past the window |
| ---: | --- | --- | --- | ---: |
| 102664422 | primary | Dhule Malegaon Road | | 2,030 m |
| 103623457 | tertiary | Nakane Road | ODR 100 | 1,982 m |
| 880554966 | secondary | | | 1,621 m |
| 236977993 | secondary | | | 1,616 m |
| 104116551 | secondary | Other District Road 106 | ODR 106 | 1,168 m |
| 157372210 | primary | | | 1,086 m |
| 885782728 | primary | | | 1,084 m |
| 887885955 | primary | Sakri Road | | 1,016 m |

These vertices are in `dhulemap.osm`. The `<bounds>` element records the export window, while the ways keep their nodes beyond that window. The exporter copied those nodes. They are still in both GeoJSON files.

## 4. Exporter quality — PASS for these two layers

Reviewed `tools/export_dhule_geojson.py`.

- Way order follows the OSM document. Tag order follows each way’s tag elements. Way and node ids are decimal integers. Largest node id in the file is 14,214,421,145 and the largest way id is 1,562,214,993, both inside the JSON safe-integer range.
- Geometry is `[longitude, latitude]`. Building output is one exterior ring. An unclosed building ring would be closed by repeating the first node; every building way in this file was already closed.
- Raw tags are copied whole. The promoted fields are a view of six road keys and five building keys. A missing key becomes JSON `null`.
- A way whose `nd` ref is missing from the node table is skipped. This file has 0 unresolved refs, so the skip path removed nothing. The only record of a future skip would be the stdout counter.
- The script writes `data/dhule/roads.geojson` and `data/dhule/buildings.geojson` only. It does not open `dhule_roads_game.json`.
- Second run, same machine, same source: both outputs were byte-identical to the first (`roads.geojson` 973,049 bytes, `buildings.geojson` 353,239 bytes). `dhulemap.osm` stayed 1,952,576 bytes with the same SHA-256.

Each collection also carries `name` and `source` members (file, ODbL-1.0, © OpenStreetMap contributors, and the `<bounds>` strings). RFC 7946 allows extra members. A strict reader can ignore them.

Information present in the OSM file and absent from these two GeoJSON files:

- 17 ways that are neither highways nor buildings: waterway 2, leisure 6, amenity 3, landuse 4, natural 1, railway 1.
- 6 relations: road routes old National Highway 6 (970785), Old National Highway 211 (2885736), SH14 (4033091), and Asian Highway AH46 (17407512); administrative boundaries Dhule (1985898) and Dhule Taluka (10327952).
- 81 tagged nodes, including place and amenity tags. Their coordinates appear only when a road or building way references them. They are not their own features.
- Way `version`, `timestamp`, `changeset`, `uid`, and `user`.

`width`, `tunnel`, `height`, and `roof:shape` are absent because the source ways do not carry those tags.

## 5. Production safety — PASS

SHA-256 of these files was unchanged by the second export run:

- `assets/maps/dhule_roads_game.json`
- `assets/maps/dhulemap.osm`
- `scripts/osm_road_builder.gd`
- `scenes/main.tscn`
- `scripts/player_car.gd`
- `scripts/hud.gd`
- `scripts/game_bootstrap.gd`
- `scripts/building_kit.gd`
- `scripts/street_kit.gd`
- `scripts/asset_kit.gd`
- `scripts/game_settings.gd`
- `scripts/minimap.gd`
- `project.godot`
- `tools/export_dhule_geojson.py`

This validation did not commit, push, reset, or clean. Existing uncommitted work in the working tree was left as it was.

## Canonical source

Use `data/dhule/roads.geojson` and `data/dhule/buildings.geojson` as the canonical copy of the 799 highway ways and 254 building footprints in this OSM clip. Ids, node order, coordinates, and raw tags matched the source with no geometry failures and no invented heights.

Keep `assets/maps/dhule_roads_game.json` as the separate playable dressing file. This phase does not replace it.

These GeoJSON files do not yet cover water, landuse, amenities, route membership, administrative boundaries, or node places, and they cannot supply building height.

## Recommended fixes

Not implemented.

1. When the next layer phase is approved, export the 17 other ways and the 81 tagged nodes as their own GeoJSON files, with the same id and raw-tag rule.
2. Export the four road-route relations and two boundary relations as member lists so NH, SH, and AH membership stays with the ways.
3. Write skipped ways to a small report if a future OSM file has a dangling `nd` ref. The current exporter only prints a counter and drops the whole way.
4. Keep an `outside_bounds` count in the collection `source` so the 128 overflowing roads and 6 overflowing buildings stay visible to the next tool. Leave the vertices in place.
5. Copy way `version` and `timestamp` if a later diff needs to know which OSM revision was exported.
6. Leave `height`, `building:levels`, `roof:shape`, and `width` null where the tag is missing.
