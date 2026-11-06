# Dhule urban layout audit

The playable centre lines were not moved. This pass compares `assets/maps/dhule_roads_game.json` (796 ways) with `data/dhule/roads.geojson` and `assets/maps/dhulemap.osm`. `assets/maps/dhule_city.osm` is the building extract and has none of the road or public-space tags below.

## Road connections

Endpoints were clustered when they lie within 3.2 m and belong to at least two different ways. The angle is the angle between the roads, so a straight OSM split reads as about 0 degrees.

| Kind | Count | What was built |
| --- | ---: | --- |
| Straight two-way split | 77 | Nothing. The ribbons already meet. |
| Two-way bend | 13 | Junction disc, ribbon ends trimmed to the disc |
| Two-way corner | 7 | Junction disc, ribbon ends trimmed to the disc |
| Three-way | 20 | Junction disc, ribbon ends trimmed to the disc |
| Four-way or more | 2 | Junction disc, ribbon ends trimmed to the disc |
| Roundabout arms | 27 | Approach trimmed to the ring edge. The ring is not cut. |
| Endpoint with no neighbour within 8 m | 279 | Left as mapped |

42 discs are drawn. The 27 arm records only trim the approach, so the roundabout ring stays one piece. Two centre lines cross away from a shared node. They were not given a disc, because a disc there would cover a crossing the source did not mark as a junction.

## Roundabouts

Same three ways as the road audit. All are in the playable JSON. None has a name.

| OSM id | Class |
| --- | --- |
| 217392930 | primary |
| 883678059 | primary |
| 887725187 | secondary |

`highway=turning_circle` occurs once, as a node. It is not a roundabout and was not given a circle.

## Public spaces

Searched tags: `junction=roundabout`, `highway=pedestrian`, `area:highway`, `place=square`, `leisure=park`, `landuse=recreation_ground`.

| Tag | In dhulemap.osm and the GeoJSON clip |
| --- | --- |
| junction=roundabout | 3 ways, listed above |
| highway=pedestrian | 0 |
| area:highway | 0 |
| place=square | 0 |
| leisure=park | 0 |
| landuse=recreation_ground | 0 |

A point is named "Plaza". It has no polygon, so no square was paved from it.

These polygons are real and were not turned into squares or chowks:

| OSM id | Tag | Name |
| --- | --- | --- |
| 265572727 | leisure=stadium | unnamed |
| 441426939 | leisure=pitch | unnamed |
| 784704489 | leisure=playground | unnamed |
| 1098922199 | leisure=track | Common cycling track |
| 509653013, 784704499 | leisure=swimming_pool | unnamed |
| node 10062243720 | leisure=swimming_pool | Officer's club Swimming club |

No statue and no invented landmark was added.
