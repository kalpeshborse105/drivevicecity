# 41 — Dhule building data audit

The spawn block is real OSM geometry. It is not a set of boxes, and it does not carry heights or shop names. The production city mesh is still the joined Blosm file. This phase does not replace it.

Projection is the game projection: origin 20.902 N, 74.777 E, 111,320 m per degree, X east, Z south. Spawn stays (−636.54, 881.83) on road `887431550`.

## What `dhule_city.osm` contains

1,866 building ways, 11,278 nodes, 0 relations, 0 duplicate way ids, 0 missing nodes. Tag keys on those ways are only `building`, `name`, and `building:levels`.

| Tag | Count |
| --- | ---: |
| `building=yes` | 1,850 |
| `building=school` | 4 |
| `building=apartments` | 3 |
| `building=college` | 2 |
| `building=residential` | 2 |
| `building=commercial` | 2 |
| `building=house` | 2 |
| `building=hospital` | 1 |
| `name` | 22 |
| `building:levels` | 3 (two at 2, one at 4) |
| `height` | 0 |
| `roof:shape` | 0 |
| `roof:levels` | 0 |
| `shop` | 0 |
| `amenity` | 0 |

352 footprints are not quadrilaterals (5 to 32 corners). The other 1,514 are quadrilaterals. None of the three level tags, and none of the 22 names, sit inside 120 m of the spawn. The nearest named way is `482794524`, “Dhule District & Sessions Court”, `building=yes`, area 17,178 m², centroid about 127 m from the spawn. A solid fill would cover the courtyard, so it was not meshed.

`data/dhule/city_shops.json` has 5 shop records. None is within 400 m of the spawn.

## Footprints beside the spawn

50 building ways have a centroid within 120 m. They are stepped plans of 8 to 17 corners, about 67–86 m², all `building=yes`, with no name, height, levels, or shop tag. Several of those plans cross a carriageway (clearance below 0 m against the road half-width). Those were not built. The 16 that were built all keep at least 4.6 m between the chosen front edge and the asphalt edge.

The playable JSON stores 780 buildings as `{id, kind, name, x, z, w, d, h}` boxes. 765 are `kind=yes`. That file cannot drive an irregular plan. The prototype reads the OSM rings.

## Blosm mesh and cost

`assets/models/environments/dhule_blosm_city.glb` is unchanged. Docs 35 and 36 still describe it: 25,251 building triangles, 1,730 way ids matched under the 0.20 m rule, 136 footprints with no confident triangle, 4,922 triangles left unresolved. The GLB has no way id on the mesh.

Production attaches one trimesh to that joined mesh (`_collide_city_mesh` in `scripts/osm_road_builder.gd`). It is not one body per building. Doc 35 measured one node per building at 2,499 draw calls and 33 FPS on this Intel UHD 620, against about 63 draws and 59 FPS for the joined mesh on a high camera. Draw calls, not triangles, are the limit.

A fresh paired sample in this phase, same aerial camera, 1280×720, UHD 620:

| View | FPS | Draw calls |
| --- | ---: | ---: |
| 16 prototype shells, roads, car | 26.0 | 65 |
| Same camera, prototype hidden, Blosm building mesh shown | 51.8 | 62 |

A second sample while the machine was busier read 11.0 and 8.8 FPS at the same 65 and 62 draws. The prototype did not beat the Blosm mesh. The production scene from the previous phase, with the full road set and HUD, was about 19 FPS and 1,680 draws. These isolated numbers are not that scene.

## Names that were being invented

`BuildingKit.footprint` picked a shop name from `SIGN_WORDS` whenever a fallback building was marked commercial. Those strings are not OSM names. Production currently shows the Blosm mesh, so the list was the no-Blosm path and the other callers of `BuildingKit`. The list is removed. A commercial front keeps a blank board unless the caller passes a name.
