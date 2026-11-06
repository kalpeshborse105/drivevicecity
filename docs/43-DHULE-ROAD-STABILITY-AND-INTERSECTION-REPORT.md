# 43 — Road stability and intersections

The flicker came from the junction disc. It sat 1 cm above the ribbons, while each ribbon still ran through the disc at full width. Two asphalt surfaces occupied the same pixels, and the depth buffer swapped which one won as the camera moved. Straight splits were left as two end caps, so a small angle made those caps overlap as well.

## What changed

Centre lines, way ids, names, and the spawn (−636.54, 881.83) are unchanged. Production still loaded 796 ways.

Each verified meeting of two or more open ends is now one flat polygon at the same height as the ribbon. The ribbon is shortened along its own first segment until its end edge is the polygon edge. Nothing is stacked on top. A two-way continuation is pulled back 0.35 m, so the join is a short patch instead of a crossing wedge. Roundabout arms are still trimmed to the ring and do not get a second disc.

Paint added on top of that, 3 cm up, and only as marks:

- A stop bar on each approach of a 3-way or 4-way join.
- Five zebra stripes on the narrower arm of a 4-way join. There are 2 four-ways. The OSM extract has no `crossing` tag, so these stripes are junction paint, not a mapped crossing. They are not on every join.

## Measured

Godot 4.7.2, Intel UHD 620, 1280×720.

| Run | Result |
| --- | --- |
| Isolated roads, car at 107 km/h | 43 FPS, 76 draws. The chase view shows the cross road meeting the lane as one surface. |
| Production | 796 ways, spawn unchanged, 119 flat joins (77 straight, 13 bends, 7 corners, 20 three-way, 2 four-way), 27 roundabout arms, 3 roundabouts. |
| Production frame sample | 8 FPS, 450 draws. The home panel was open over the camera, so this is not a clean match to the earlier 19 FPS / 1,680 draw sample. No improvement is claimed. |

Screenshots: `docs/qa/43-drive-mid.png` (the join while driving), `docs/qa/43-drive-fast.png`, `docs/qa/43-road-name.png`.

## Still open

Two centre lines cross without a shared node. They still have no join, because the centre line was not moved to invent one. A seam can show where a major-road material meets a minor-road material. That seam is an edge, not two stacked surfaces.
