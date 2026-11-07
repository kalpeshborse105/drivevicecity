# 55 — Dhule building style kit (Phase 2H.2)

Visual variants for **unclassified** footprints (`building=yes`). They change facade, height estimate, and roof detail only. They do **not** claim the OSM building is a shop, temple, school, or named business.

Code: `scripts/dhule_building_styles.gd` → `scripts/building_shell.gd`.

## Styles

| Key | Shell | Look | Estimated floors (if OSM silent) |
| --- | --- | --- | --- |
| **A** `plastered_house` | `family` | Flat RCC roof, parapet, modest windows, ground door, optional tank | 2 if area ≥ 72 m² else 1 |
| **B** `narrow_urban` | `row` | Narrow deep plot, estimated two-level face, sunshade/balcony when clear, flat roof | 2 if area ≥ 70 m² else 1 |
| **C** `traditional_compact` | `cottage` | Simple plaster, small openings, main door, subtle colour, low parapet | **1** |

Assignment uses plan metrics only (`choose`): under 72 m² → C; very narrow deep aspect → B; otherwise A with a stable id-based C/B mix. **Names and area bands never invent typology.**

## Height evidence

| Field | Meaning |
| --- | --- |
| `height_source: osm` | From `height` or `building:levels` |
| `height_source: estimated` | Conservative kit rule above — **not** surveyed |
| `source_levels` | Raw OSM value when present |
| `estimated_levels` | Kit floors when estimated |

No random floor rolls. Shop shutters / blank boards appear only when OSM has `shop` or `building=commercial|retail` (none in the 2H.2 set).

## Geometry contract

- Ground plan = OSM outer ring (all vertices kept).
- Walls inset 0.28 m; windows/sunshades sit outside plaster without changing the footprint.
- Roof = triangulated ring (`Geometry2D`); concave supported.
- **Holes / courtyards:** not supported. `dhule_city.osm` building ways are simple outer rings; filling a compound outline would invent mass. Rejected rather than forced.

## Collision

Each way gets `StaticBody3D` `hit_<osm_id>` (extruded prism) plus shared yard trimesh when steps exist. Solids are never stripped.

## City-scale note

This kit draws one chunk mesh for a neighbourhood. Full-city runtime must stay **chunk-batched** (doc 35/36): not one Godot node per 1,866 buildings.
