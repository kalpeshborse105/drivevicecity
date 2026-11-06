# Dhule road rendering

The playable centre lines are unchanged. Each way is one continuous ribbon instead of overlapping slabs. Those slabs used to extend 1.2 m past each piece and restart the texture, which shimmered while the car moved. The ribbon does not extend past the centre line, keeps one side direction along the way, and lays the texture by distance travelled (one tile every 8 m). Markings sit 2 cm above the asphalt on a second surface. The ribbon has no collision, so it cannot bounce the car. The ground collision is the existing box.

Closed ways, including the three mapped roundabouts, join the last span back to the first so the ring does not leave a wedge.

## What is drawn

- Asphalt uses the existing street and avenue textures. Primary, secondary, tertiary, trunk, and motorway ways use the avenue texture. Other classes use the street texture. Widths stay the mapped widths.
- Edge lines are drawn when the way is at least 4.5 m wide.
- Centre dashes are drawn only on primary, secondary, tertiary, trunk, trunk_link, and motorway ways that are at least 6 m wide.
- A junction disc is drawn only where three or more different way endpoints meet within 3 m. The test window around the spawn has none of those clusters. The full city has 22.
- No zebra crossings were added. The sources used here do not carry crossing nodes, and a highway class is not a crossing.
- No statues and no squares. The audit found no named square.

The three verified roundabouts get a circular island and a kerb ring. The island radius is the smallest distance from the centre line’s centroid to the ring, minus half the road width and 0.8 m. Nothing is placed if that radius is outside 1.2–40 m. All three passed.

| OSM id | Result |
| --- | --- |
| 217392930 | Island built |
| 883678059 | Island built |
| 887725187 | Island built |

## Names

Labels use the way’s `name`, or `ref` if the name is empty. Unnamed ways get no label. Labels sit along the centre line, at least 46 m apart and about 220 m apart on a long way, and fade with camera distance. The minimap GPS line appends that same verified name when the car is on a named way. The spawn road `887431550` is residential and has no name, so the GPS line stays coordinates only.

Fifteen distinct names are in the game JSON. They are listed in `docs/37-DHULE-ROAD-DATA-AUDIT.md`.

## Vehicles

The chase camera sits behind the travel direction. Kit vehicles, including the autorickshaw, get a half-turn after their long axis is aligned so the nose points with travel and the camera sees the rear. The sedan held 146.9 km/h under a 150 km/h cap on the test straight. Vertical position stayed between 0.281 m and 0.364 m, which is the suspension, not the road mesh. Wheel friction and suspension were not retuned.

Caps: van and autorickshaw and bus 120, carnival 130, safari 135, truck 125, camry 140, premium sedan and default sedan 150.

## Performance

Intel UHD Graphics 620, 1280×720, production scene `scenes/main.tscn`.

| Build | FPS | Draw calls |
| --- | ---: | ---: |
| One mesh per way | 12 | 2156 |
| Roads merged into 3 material batches | 13 | 1684 |

The isolated test (45 ways near the spawn, plus the three roundabouts) ran the drive at about 28 FPS. The production figure includes buildings, the minimap, and the job HUD. Merging the roads removed about 470 draw calls. The city is still draw-call heavy, so the frame rate barely moved.

Production log: `PHASE1 map: 796 ways`, spawn `(−636.5, 881.8)`, `ROAD junctions 22`, `ROAD roundabouts 3`, `ROAD batches 3`. Delivery jobs and the minimap were on screen. Buildings and their collision were not replaced.

## Screenshots

- `docs/qa/38-street.png` — sedan from behind, edge lines and centre dashes
- `docs/qa/38-junction.png` — spawn-area grid and a curve
- `docs/qa/38-roundabout.png` — way `887725187` with the island
- `docs/qa/38-name.png` — verified label “Dhule Malegaon Road”
- `docs/qa/38-rickshaw.png` and `docs/qa/38-carnival.png` — rear view, nose down the road
- `docs/qa/38-drive.png` — after the speed run
- `docs/qa/38-production.png` — production scene at the spawn

## Roadside objects

`scripts/roadside_placement.gd` only answers whether a point is clear of the carriageway (half width plus 1.6 m) and of a building footprint. Nothing calls it during a rebuild, so lamps and trees are not scattered again on every road build. The older prop pass in `osm_road_builder.gd` is still the one the production scene already used.

## Cleanup list

These were not deleted. Callers were checked in `scripts/`.

| Path | Evidence |
| --- | --- |
| `scripts/osm_road_builder.gd` `_build_wear_patches` | Defined. No caller. |
| `scripts/osm_road_builder.gd` `_build_zebra_and_breakers` | Defined, returns immediately. No caller. |
| `scripts/osm_road_builder.gd` `_build_edge_lines` | Defined. No caller. Markings now come from `road_surface.gd`. |
| `scripts/osm_road_builder.gd` `_build_center_dashes` | Defined. No caller. |
| `scripts/osm_road_builder.gd` `_build_curbs` | Called only when the Blosm city is absent. Production has the city, so this does not run there. |
| `scripts/street_kit.gd` `add_road_deck` | Still used by `scripts/mumbai_city_builder.gd` and by street kit itself. Not the Dhule ribbon. |
| `scripts/mumbai_city_builder.gd` `_build_road_strip` | Mumbai scene only. |
| `scripts/roadside_placement.gd` | New. No production caller, on purpose. |

`scripts/dev/dhule_road_system_test.gd` and `scenes/dev/dhule_road_system_test.tscn` are the isolated test. They load the same JSON and the same car scene.
