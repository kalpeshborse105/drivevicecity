# 42 — Road join blink audit

## What blinked

Dark jagged edges at T / X junctions while the camera moved. That is z-fighting: two asphalt meshes at nearly the same height.

## Join bug list (found)

| # | Cause | Where | Fix |
|---|--------|--------|-----|
| 1 | Junction pad and road ribbon shared the same Y | Every prepared junction | Junction pad at `road_y + 0.07` |
| 2 | Lane paint sat almost on the deck | Edges / dashes / stop lines | Paint lift `+0.04` / `+0.095` + material grow |
| 3 | Major + residential ribbons overlapped at the same height | Primary into residential | Major deck `+0.014` |
| 4 | Road tips were not pulled far enough out of the join | Arm trim too short | Stronger `pull` + wider arm match |
| 5 | Depth buffer precision while looking far | Chase cam | `near=0.35`, `far=700` |

## Intentionally not replaced

Road Generator addon stays editor-only. Dhule roads stay OSM (`osm_road_builder` + `road_surface`). Swapping the whole city to Road Generator would drop GPS layout.

## How to re-check

F5 → drive through any T-junction near spawn. Seam should stay a solid pad, not flicker.
