# 76 — Second Dhule neighbourhood selection (Phase 2H.4C)

**Baseline:** `3b81cf7` · **Engine:** Godot 4.7.2  
**OSM:** `assets/maps/dhule_city.osm` · **Roads:** `assets/maps/dhule_roads_game.json`  
**Tool:** `tools/select_chunk2_pilot_buildings.py`  
**Manifest:** `docs/qa/76-chunk2-pilot-manifest.json` (+ CSV)  
**Rejects:** `docs/qa/76-chunk2-selection-rejects.json`  
**Clearance (runtime):** `docs/qa/76-chunk2-pilot-clearance.json`

## Goal

Select **40–64** real OSM building outer rings in a continuous pocket **different** from the first 48-building pilot (`docs/qa/64-chunk-pilot-manifest.json`, cell `(-2, 1)`).

## Geographic pocket

| Field | Value |
|-------|-------|
| Target / expand cells | `(-2,2)`, `(-1,2)`, `(-3,2)`, `(-2,3)`, `(-1,3)` |
| Dense cluster seed | OSM way `1527760280` at ≈ `(-188.7, 1701.6)` |
| Cluster radius | **180 m** (grown until ≥40 after overlap filter) |
| Selected cell mix | **41 / 41** in `(-1, 3)` |
| Neighbourhood origin | `(-160.92, 1698.19)` |
| Median distance from first pilot | **891.6 m** |
| Footprint span (selected) | ≈ 328 m × 339 m |

First-pilot IDs (**61**) are hard-excluded. No invented footprints or tags.

## Selection filters

1. Must have `building=*` outer ring (≥3 vertices).  
2. Skip civic / large-use tags: apartments, commercial, retail, industrial, warehouse, school, college, hospital, mosque, temple, church, public, garage.  
3. Skip ways with `shop` / `amenity` / `office` (no fictional commercial).  
4. Area band **28–320 m²**.  
5. **Road clearance** must pass both Godot checks used at runtime:  
   - AABB asphalt clearance ≥ **0.5 m** (`AssetPlacementValidator`)  
   - Front-edge clearance ≥ **0.5 m** (`_front_edge`)  
6. Neighbour AABB overlap margin **0.2 m** prefilter.  
7. Dense-cluster grow around densest seed (avoids 1 km scatter).

## Accepted set

| Metric | Value |
|--------|------:|
| Selected | **41** |
| Styles | plastered_house **27**, traditional_compact **13**, narrow_urban **1** |
| Vertex counts | 4×37, 6×3, 8×1 |
| Height evidence | **41 estimated** (no `height` / `building:levels` on these ways) |
| Asset assignment | all `procedural_shell` |

Each manifest row records: OSM way ID, polygon, area, vertex count, source tags, distances, clearance, style, floors, height_source, chunk cell, asset assignment.

## Rejects (sample of reasons)

Reject file stores up to 500 rows (total counted higher). Top reasons in the truncated sample:

| Reason | Count (sample) |
|--------|---------------:|
| outside_target_cells | 317 |
| area_out_of_range | 94 |
| in_first_pilot | 61 |
| road_clearance | 16 |
| building_tag_* (school/apartments/…) | 12 |

Candidates outside the dense 180 m cluster are also recorded as `outside_dense_cluster` when a seed is active.

## Runtime validation

Godot `dhule_building_chunk_2_pilot.gd` re-checks clearance + overlap on the same rings:

```
CHUNK_MESH buildings=41 surfaces=7 accepted=41 rejected=0
CLEARANCE_REPORT … accepted=41
min front_clear_m ≈ 3.83 · min validator_clear_m ≈ 1.16
```

## Notes

- Heights without OSM evidence remain labelled **estimated**.  
- One elongated plot (`1527766249`, span 7.88×11.97 m) is the sole `narrow_urban` in this pocket — style order prefers narrow before compact.  
- Production Blosm and `scenes/main.tscn` untouched.
