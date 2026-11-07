# 50 — Road clearance audit

Margin: **0.5 m** outside the asphalt half-width.  
Asphalt test: every road segment is treated as a stadium polygon of width `road.width` along the centre line. Footprint edges and the placed asset AABB are sampled against that surface.

No OSM ring was moved. No failing asset was kept by turning collision off.

## Summary

| Metric | Value |
| --- | ---: |
| Footprints tested | 24 |
| Footprint road clearance &lt; 0.5 m | 0 |
| Assets fitted | 5 |
| Fitted assets with road overlap | 0 |
| Fitted assets outside polygon | 0 |
| Procedural fallback | 19 |

## Per-building report

| OSM id | Asset | Footprint m² | Asset plan m² | Clearance m | Inside poly | Road overlap | Result | Reason |
| --- | --- | ---: | ---: | ---: | --- | --- | --- | --- |
| 1337953920 | indian_house.glb | 75.3 | 56.3 | 3.84 | yes | no | fitted | ok |
| 1337952466 | indian_house.glb | 76.7 | — | 4.59 | — | no | procedural | too_small_to_fit |
| 1337951727 | indian_house.glb | 66.9 | — | 5.43 | — | no | procedural | too_small_to_fit |
| 1337952467 | indian_house.glb | 76.7 | — | 8.88 | — | no | procedural | too_small_to_fit |
| 1337953903 | indian_house.glb | 83.9 | — | 10.83 | — | no | procedural | too_small_to_fit |
| 1337951730 | indian_house.glb | 76.7 | — | 11.49 | — | no | procedural | too_small_to_fit |
| 1337953905 | indian_house.glb | 84.0 | — | 11.82 | — | no | procedural | too_small_to_fit |
| 1337953919 | indian_house.glb | 75.4 | 49.5 | 12.27 | yes | no | fitted | ok |
| 1337953924 | indian_house.glb | 75.4 | 51.0 | 13.40 | yes | no | fitted | ok |
| 1337953918 | indian_house.glb | 75.4 | 56.2 | 17.52 | yes | no | fitted | ok |
| 1337951724 | indian_house.glb | 66.9 | — | 19.62 | — | no | procedural | too_small_to_fit |
| 1337953921 | indian_house.glb | 75.4 | 56.4 | 20.66 | yes | no | fitted | ok |
| 1337951726 | indian_house.glb | 66.9 | — | 20.69 | — | no | procedural | too_small_to_fit |
| 1337953904 | indian_house.glb | 84.0 | — | 23.67 | — | no | procedural | too_small_to_fit |
| 1337951729 | indian_house.glb | 84.4 | — | 23.92 | — | no | procedural | too_small_to_fit |
| 1337952468 | indian_house.glb | 76.7 | — | 27.27 | — | no | procedural | too_small_to_fit |
| 1337953902 | indian_house.glb | 84.0 | — | 27.33 | — | no | procedural | too_small_to_fit |
| 1337951728 | — | 86.2 | — | 32.69 | — | no | procedural | no_suitable_asset |
| 1337951722 | indian_house.glb | 66.9 | — | 42.13 | — | no | procedural | too_small_to_fit |
| 1337952469 | indian_house.glb | 76.7 | — | 51.47 | — | no | procedural | too_small_to_fit |
| 1337951719 | indian_house.glb | 67.0 | — | 14.33 | — | no | procedural | too_small_to_fit |
| 1337952474 | indian_house.glb | 76.7 | — | 15.98 | — | no | procedural | too_small_to_fit |
| 1337951720 | indian_house.glb | 66.9 | — | 18.97 | — | no | procedural | too_small_to_fit |
| 1337951715 | — | 264.7 | — | 29.35 | — | no | procedural | no_suitable_asset |

`too_small_to_fit` means the square house AABB cannot stay inside that stepped OSM ring at a uniform scale that still looks like a house. Those lots keep the procedural shell. That is the required behaviour: do not stretch the GLB and do not push it onto the road.

## Debug view

Press V in `dhule_building_asset_test.tscn` (or see `docs/qa/48-clearance.png`):

- Red — asphalt polygons
- Green — OSM building rings
- Blue — placed asset AABB
- Yellow labels — clearance in metres
