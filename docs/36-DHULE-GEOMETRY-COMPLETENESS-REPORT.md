# 36 — OSM geometry completeness

The 136 footprints are not missing from the Blosm mesh. Each one is a valid `building=yes` way, and Blosm triangles already meet it. The 0.20 m rule left every one of those triangles unresolved because a vertex sits 0.33 m to 0.68 m outside the ring. The 4,922 unresolved triangles are the same kind of shell: walls, roofs, and 34 triangles that meet two footprints. None are degenerate. Nothing was reassigned.

## What was measured

`scripts/audit_geometry.py` uses the same projection and the same assignment rule as `partition_buildings.py`. It writes only under `blender_work/dhule_city_pipeline/audit/`. The production GLB, the OSM file, and the road JSON were read and not modified.

| Check | Result |
| --- | ---: |
| OSM building ways | 1,866 |
| Way ids in the OSM file and in the partition | the same 1,866, no duplicates |
| Source building triangles | 25,251 |
| Confidently assigned | 20,329 |
| Unresolved | 4,922 |
| Footprints with no confident triangle | 136 |
| Water, separate mesh | 830 |

The four rejection reasons are unchanged: `crosses_boundary` 2,476, `unmatched` 2,412, `ambiguous_multi_footprint` 28, `ambiguous_margin` 6.

## The 136 footprints

Every row is class B, geometry exists but does not match the 0.20 m test. Classes A, C, D, E, and F are empty. The per-way table is `audit/missing_buildings.csv`.

| Class | Count | Evidence |
| --- | ---: | --- |
| A. No Blosm geometry | 0 | All 136 have at least one mesh vertex inside the polygon, and 6 to 18 triangles intersect it. |
| B. Geometry exists but does not match | 136 | Those triangles are unresolved. The farthest vertex on each footprint is 0.33 m to 0.68 m outside the ring (median 0.39 m). |
| C. Polygon or topology | 0 | All 136 are closed rings, area 39.7 m² to 350 m², no self-intersection, every node resolves. |
| D. Projection | 0 | Assigned footprints already sit on the mesh in the game projection. The 136 do not share one offset. |
| E. Overlapping footprint | 0 | No vertex of these rings lies inside another footprint, and no edges properly cross. The nearest other footprint is at least 5 m away where one was found. |
| F. Unknown | 0 | The rows above account for every footprint. |

All 136 are tagged `building=yes`, with no name. 128 are quadrilaterals. The way-id prefixes clump (`152728` 52, `152727` 39, `138158` 36), and the outlines themselves are spread across the district, from about x −4313 to 2683 and z −2790 to 4074. None of them is within 40 m of a playable road. The median centre-line distance is about 1.3 km. That is the outer band already described in the coverage audit. It is not why the triangles were rejected: the mesh is there.

Nine other footprints still have no mesh vertex strictly inside the ring: `1485903708`, `1527760215`, `1527760232`, `1527760270`, `1527760283`, `1527816133`, `1527858168`, `1527858172`, `1527858312`. They are not in the 136. The edge rule gave them confident triangles. They were left as they are.

## The 4,922 triangles

`audit/unresolved_triangles.csv` has one row per triangle: centroid, three vertices, area, both nearest footprint ids, distance to each ring, and the rejection reason. No triangle was given an owner.

Distance in that file is from the centroid to the nearest ring. When the centroid is inside, the number is an inset, not a gap.

| Reason | Triangles | What they are |
| --- | ---: | --- |
| crosses_boundary | 2,476 | 1,644 walls and 832 roofs. At least one vertex is inside one footprint. The outside vertex is 0.23 m to 0.68 m past that ring. 2,069 centroids lie inside the ring. |
| unmatched | 2,412 | No vertex tested inside a footprint. 1,126 are roofs whose centroid is inside the nearest ring, so the centroid-to-edge inset fails the 0.20 m test. 1,286 are walls whose centroid is outside, 0.23 m to 0.61 m from the ring (median 0.31 m). |
| ambiguous_multi_footprint | 28 | All three vertices meet footprints, and the centroid is inside one of them. Median area is about 82 m². These are the triangles that actually touch two ways. |
| ambiguous_margin | 6 | Walls. The centroid is outside both rings, 0.05 m to 0.18 m from the nearest edge, and the second ring is inside the 0.50 m margin. |

Diagnostic counts, from the measured distances, not from a looser assignment:

| Diagnostic | Triangles |
| --- | ---: |
| Real building wall | 2,930 |
| Real building roof | 1,923 |
| Roof overhang, centroid outside and within 3 m | 35 |
| Geometry between adjoining footprints | 34 |
| Degenerate, area under 0.0001 m² | 0 |
| Unrelated to a footprint | 0 |

The largest unresolved face is a roof of about 8,260 m² whose centroid lies inside way `482794524`, the Sessions Court outline, 30 m in from the edge. Its vertices fail the inside test, so the 0.20 m rule does not take it. It stays unresolved. The same pattern, at a smaller size, is the 136.

## OSM source against the GLB

`dhule_city.osm` is a local extract. The generator tag is `DriveViceCity`. It has 11,278 nodes, 1,897 ways, and no relations. Node ids are local. Way ids are the OSM ids. No way has a `version` or `timestamp` attribute, so there is no geometry version to compare.

`tools/export_dhule_blosm.py` names this OSM path, the origin 20.902 N, 74.777 E, and Blosm mode `3Dsimple`. The GLB on disk was written about one minute after the OSM file (OSM 2026-11-06 11:59:29 UTC, GLB 12:00:26 UTC). Its generator is `Khronos glTF Blender I/O v4.5.49`. The two nodes are `dhule_city.osm_buildings` and `dhule_city.osm_water`, with no extras and no way ids. SHA-256 of the GLB is `fe778f2ebfab9bad67e43027e488b7b15dcc817c62cc572d1b66725d1bd7393d`. SHA-256 of the OSM file is `a6e346aac42bc677374aecb895121f227c75f9f29000bb14635d5a851754b97c`.

The export script points at this file, the way-id sets match, and the GLB is newer than the OSM file. The GLB does not store a source hash, so the bytes Blosm read are not proven to be these bytes.

## Recovery, not applied

For all 136 footprints the recommendation in the CSV is **keep unresolved**. The shell can be pointed at: the unresolved triangles whose centroids fall in that way. Assigning the whole triangle would also take the 0.33 m to 0.68 m that sits outside the ring. Rebuilding a second box from the OSM polygon would duplicate that shell. A re-export with per-way ids would still need a containment rule; the current joined mesh has no ids to swap. None of the 136 is tagged as something other than a building, so none is a candidate to drop.

For the triangles:

| Category | Recommendation |
| --- | --- |
| crosses_boundary | Preserve separately. A later split along the footprint edge can keep the interior piece. The outside piece is 0.23 m to 0.68 m. The whole triangle was not assigned. |
| unmatched | Preserve separately. Widening a centroid band to catch them would also accept walls that sit between neighbours. The 1.84 m gap between ways `1337953905` and `1337953919` is the case that rule was written to avoid. |
| ambiguous_multi_footprint | Preserve separately. Two footprints contain vertices. |
| ambiguous_margin | Preserve separately. The two nearest rings are under 0.50 m apart in the ranking. |

No category has evidence that the triangle is not building geometry, so none is recommended for exclusion. A split was not run.

## Runtime shape for this GPU

Doc 35 already measured the Intel UHD 620 at 1280×720. The joined mesh was 63 draw calls and 59 FPS. One node per building was 2,499 draw calls, 33 FPS, and 109 MB of static memory. The triangle count is about 25,000. Draw calls are the limit, not triangles.

Use that split:

- Runtime mesh: one mesh per spatial chunk, with wall and roof as two materials, plus the unresolved triangles in the same chunk as their own material so they stay visible and unowned. Chunks on the order of 500 m keep the occupied district in the tens of draws, close to the joined mesh that already holds 59 FPS. A single joined mesh remains a valid fallback.
- Identity: a side buffer of OSM way ids, one per confident triangle, on the chunk. The way id is not an object name and not a node.
- Archive: `buildings/<OSM_ID>.glb` stays the edit copy. `buildings/.gdignore` stays, so Godot does not import those files into the game.
- Collision: a trimesh per chunk, or a trimesh around the car. Not one body per building.
- LOD: the simple Blosm boxes are already the low mesh. Extra LOD is only useful after chunking, by merging distant chunks into one draw. It is not required to carry 25,000 triangles on this GPU.
- The archive GLBs and the chunk mesh are not loaded together.

## Pictures

`audit/unresolved_geometry_audit.blend` is the inspection file. Assigned faces are neutral, unresolved faces are red, the 136 rings are blue vertical outlines, footprints touched by the 34 ambiguous triangles are orange, and water is its own object. Axes in the file are X east, Y up, Z south.

- `docs/qa/36-overview.png` — the district. Grey shells, red unresolved faces, blue rings on the missing footprints.
- `docs/qa/36-missing.png` — the `152727` / `152728` cluster. The blue ring follows the footprint. Red is the shell past that ring.
- `docs/qa/36-unresolved.png` — a dense block. The confident shell and the red edge faces sit on the same buildings.
- `docs/qa/36-water.png` — the water mesh alone. It is a separate river, not part of the building primitive.

## Production integration

Not ready. The holes are identified, and they are still unowned. Integrating the partition means shipping 136 footprints with no confident id and 4,922 triangles that the current rule will not claim. The production GLB still has no way ids, and it still does not record the OSM hash, so a later export would not keep this cut.

## Left unchanged

`scenes/main.tscn`, `scripts/player_car.gd`, `assets/maps/dhule_roads_game.json`, `assets/models/environments/dhule_blosm_city.glb`, the production spawn, the production collision, and the architecture GLBs. No commit and no push.
