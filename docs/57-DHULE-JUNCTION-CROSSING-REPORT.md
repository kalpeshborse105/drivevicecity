# 57 — Junction crossing and edge-paint report (Phase 2H.3)

## Problem

White road-edge markings continued visually through intersections where OSM ribbons meet. Asphalt joins were already padded (doc 42); paint was not clipped.

## Fix

| Piece | Change |
| --- | --- |
| Edge / centre paint | `RoadSurface._edge_lines` / `_centre_dashes` skip samples inside `RoadCrosswalk.in_junction_clear()` |
| Stop lines | Every local junction arm gets a stop bar via `RoadCrosswalk.add_stop_line` |
| Zebra | `RoadCrosswalk.add_crosswalk` — rectangular, evenly spaced stripes; max 2 arms per junction |
| Selectivity | Skip trunk/motorway hints; prefer narrower arms on 4-ways |
| Kit mesh | `assets/kit/props/road_crossing.glb` (~5×5 m) optional under stripes when width ≈ 5 m |
| Unused | `pedestrian_crossing.glb` is Sketchfab-scale (~400 u) — **not** placed raw |

Crossings are **gameplay/environment** markings. OSM does not tag every Dhule crossing.

## Geometry rules kept

- OSM centre lines unchanged.
- Asphalt still continuous via junction pads (`road_y + 0.07`).
- No extra overlapping asphalt slabs for paint.
- Markings lift ≈ 0.05–0.095 m above deck (anti z-fight).
- Stop lines separate from zebra.

## QA

`scenes/dev/dhule_visual_qa.tscn`: synthetic 4-way, T, angled meet, roundabout-approach arms + nearby OSM. Probe log: **crosswalks placed 6**, junctions `three 1 four 2`.

Screenshots: `docs/qa/57-junction-after.png`, `docs/qa/57-markings-close.png`.

## Production path

`RoadSurface.flush_batch` runs the same clip + mark logic used by `osm_road_builder`. Local WIP outside these files was not staged.
