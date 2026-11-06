# Dhule road data audit

The playable network is `assets/maps/dhule_roads_game.json`. This audit compares it with `data/dhule/roads.geojson` and `assets/maps/dhule_city.osm`. No coordinates, names, or the GeoJSON file were changed. A highway class is not a road name. Ways with no name in the source stay unnamed.

## Sources

| File | Role |
| --- | --- |
| `assets/maps/dhule_roads_game.json` | Playable ways. Source field `dhulemap.osm-user-export-full-city`. 796 roads. Clip radius 2000 m. |
| `data/dhule/roads.geojson` | Smaller canonical clip from `dhulemap.osm`. Bounds lat 20.89002–20.90990, lon 74.75977–74.78896. 799 ways. Not overwritten. |
| `assets/maps/dhule_city.osm` | Building extract used by the city mesh. It contains 0 highway ways, so it is not the road source. |

Projection is unchanged: origin lat 20.902, lon 74.777. Godot X is east, Z is south.

## Playable ways

- 796 ways, 796 unique OSM ids, no duplicate ids.
- 41 ways have a verified `name`. 755 are unnamed.
- The game JSON does not store `ref`, `official_name`, `alt_name`, `oneway`, `lanes`, `surface`, `bridge`, or `tunnel`. Those fields are absent, not guessed.
- 0 verified names from the GeoJSON are missing on the matching game ways. No names were added.

Highway class counts:

| Class | Ways | Named |
| --- | ---: | ---: |
| trunk_link | 1 | 0 |
| primary | 32 | 14 |
| secondary | 26 | 15 |
| tertiary | 45 | 10 |
| unclassified | 23 | 0 |
| residential | 623 | 2 |
| service | 46 | 0 |

The 15 distinct names, and how many ways carry each:

- State Highway 14 (10)
- Station Road (5)
- Major District Road 46 (5)
- 80 Feet Road (4)
- Sakri Road (3)
- Other District Road 106 (3)
- Panjhara Dr Road (3)
- Dhule Malegaon Road, Nakane Road, Shivaji Road, Red Cross Road, Veer Savarkar Marg, Madhura Lane, Loha Bazzar Road, Collector Office Road (1 each)

## Ways in the GeoJSON that are not playable

Three short ways are in the GeoJSON and absent from the game JSON. They were left out. Their centre lines were not moved or invented into the network.

- `880887781` — tertiary bridge stub
- `887725190` — primary_link stub
- `1426345742` — residential stub

Every game way that falls inside the GeoJSON clip is present in the GeoJSON (`in_game_not_geojson` = 0).

## Connectivity

Centre lines were not edited.

- 1,592 endpoints.
- 252 endpoint-to-endpoint joins within 1.5 m.
- 1,305 endpoints lie within 2 m of another way, including T-junctions onto a segment interior.
- 287 endpoints have no neighbour within 2 m. These are map-edge ends or ways that simply stop. They were not extended.
- 0 duplicate segment keys. 0 segments shorter than 1 m.

Junction discs are drawn only where three or more distinct way endpoints meet within 3 m. A T-junction onto the middle of another way does not get a disc, so the centre lines stay where OSM put them.

## Roundabouts and squares

Three ways are tagged `junction=roundabout` in the GeoJSON. All three are already in the game JSON. None has a name. No public square with a mapped pedestrian boundary was found. No statue or landmark was added.

| OSM id | Class | Width | Nodes | Centre (x, z) |
| --- | --- | ---: | ---: | --- |
| 217392930 | primary | 11 m | 21 | (−942.2, −25.1) |
| 883678059 | primary | 11 m | 19 | (68.6, −457.6) |
| 887725187 | secondary | 9.5 m | 18 | (−68.8, 1137.2) |

Each ring repeats its first node at the end (closure gap 0 m).

## Spawn

Unchanged: x −636.54, z 881.83, heading (−0.72, −0.694), on residential way `887431550`.
