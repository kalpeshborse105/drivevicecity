# 47 — Dhule neighbourhood prototype

`scenes/dev/dhule_building_neighbourhood_test.tscn` builds 24 OSM footprints around the spawn on road `887431550`. `scenes/main.tscn` does not load it. The Blosm city, the road geometry, the spawn, the car physics, and the minimap were not edited.

The block is one mesh with 7 material slots and 24 collision bodies, plus one body for the steps and the four compound walls. Press C for the aerial camera. Press B to swap the shells and the Blosm mesh on the same camera.

## What is verified

Every shell uses the OSM ring. All 24 are `building=yes`. None has `height`, `building:levels`, `name`, or `shop`. The car started on the road side of way `1337953920`, reached 12.5 km/h, and stopped at (−638.0, 0.1, 894.5) at 0.2 km/h. The ray hit `hit_1337953920`.

The Sessions Court outline `482794524` (17,178 m²) was not filled. Footprints that cross a carriageway were not built. The nearest kept wall is 4.64 m clear of the asphalt edge.

| OSM id | Corners | Area m² | Style | Floors | Source | Clear m |
| --- | ---: | ---: | --- | ---: | --- | ---: |
| 1337953920 | 17 | 75.3 | family | 2 | estimated | 4.64 |
| 1337952466 | 12 | 76.7 | family | 2 | estimated | 4.73 |
| 1337951727 | 12 | 66.9 | cottage | 1 | estimated | 5.50 |
| 1337952467 | 12 | 76.7 | family | 2 | estimated | 9.94 |
| 1337953903 | 16 | 83.9 | family | 2 | estimated | 11.63 |
| 1337951730 | 12 | 76.7 | row | 2 | estimated | 12.51 |
| 1337953905 | 16 | 84.0 | family | 2 | estimated | 12.00 |
| 1337953919 | 17 | 75.4 | family | 2 | estimated | 12.46 |
| 1337953924 | 17 | 75.4 | family | 2 | estimated | 13.56 |
| 1337953918 | 17 | 75.4 | family | 2 | estimated | 18.27 |
| 1337951724 | 12 | 66.9 | row | 1 | estimated | 20.76 |
| 1337953921 | 17 | 75.4 | family | 2 | estimated | 21.46 |
| 1337951726 | 12 | 66.9 | cottage | 1 | estimated | 21.53 |
| 1337953904 | 16 | 84.0 | family | 2 | estimated | 24.46 |
| 1337951729 | 8 | 84.4 | family | 2 | estimated | 25.36 |
| 1337952468 | 12 | 76.7 | family | 2 | estimated | 28.33 |
| 1337953902 | 16 | 84.0 | family | 2 | estimated | 28.12 |
| 1337951728 | 8 | 86.2 | shop | 2 | visual estimate | 35.57 |
| 1337951722 | 12 | 66.9 | row | 1 | estimated | 43.27 |
| 1337952469 | 12 | 76.7 | family | 2 | estimated | 52.60 |
| 1337951719 | 12 | 67.0 | cottage | 1 | estimated | 15.57 |
| 1337952474 | 12 | 76.7 | family | 2 | estimated | 16.11 |
| 1337951720 | 12 | 66.9 | cottage | 1 | estimated | 19.01 |
| 1337951715 | 4 | 264.7 | family | 2 | estimated | 33.31 |

Counts: 4 cottages, 16 family houses, 3 row houses, 1 shop estimate, 0 commercial, 0 apartments. Way `1337951715` is the long 265 m² outline. It is one building, not a courtyard, and it stays two floors because nothing in the tags says otherwise.

## What is estimated

Floor counts and colours are estimates, using the rules in `docs/46-DHULE-BUILDING-STYLE-SYSTEM.md`. The shop label on `1337951728` is the only use that is not a size rule. Its shutter and board are blank. No other way was given a shopfront.

## Comparison

Same scene, same sun, 1280×720, Intel UHD 620. The shell samples are this block plus the nearby roads. The Blosm samples are the whole joined city mesh, because that file is one mesh and cannot be cut down to these 24 footprints. Video memory was already about 148 MB before the mesh was shown.

| View | FPS median | FPS minimum | Draws | Video MB | Static MB |
| --- | ---: | ---: | ---: | ---: | ---: |
| Shells, street | 13 | 13 | 42 | 147.9 | 68.1 |
| Shells, aerial | 26 | 26 | 28 | 147.9 | 68.1 |
| Blosm, same street camera | 13 | 13 | 15 | 149.2 | 68.4 |
| Blosm, same aerial camera | 30 | 30 | 15 | 149.2 | 68.4 |

An earlier pass on these cameras read 23 and 27 FPS, and a busier pass read 8 and 9. Draw counts stayed at 42 / 28 for the shells and 15 for Blosm. This is not a faster city. The shell scene does not draw the other 1,800 buildings.

## Pictures

- `docs/qa/46-street.png` — one-floor houses in the distance and taller houses beside the road.
- `docs/qa/46-facade.png` — door, step, lamp, brick base, sunshades, and a second floor on way `1337953920`.
- `docs/qa/46-shop.png` — the long side of the shop-estimate outline. The shutter is on the road edge, which this camera does not face.
- `docs/qa/46-aerial.png` — the 24 rings, including the long house and the shorter cottages.
- `docs/qa/46-blosm-street.png` and `docs/qa/46-blosm-aerial.png` — the same cameras on the production Blosm mesh.
- `docs/qa/46-collision.png` — the car stopped against `1337953920`.

## Production

Not ready. Twenty-four of 1,866 footprints are built, and the heights are estimates. The joined Blosm mesh remains the city.
