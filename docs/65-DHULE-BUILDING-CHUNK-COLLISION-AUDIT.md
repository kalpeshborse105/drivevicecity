# 65 — Chunk pilot collision & clearance audit

## Clearance (machine-readable)

File: `docs/qa/64-chunk-pilot-clearance.json`

| Metric | Value |
|---|---:|
| Margin | 0.5 m outside asphalt |
| Accepted | 48 |
| Rejected | 13 |
| Reject reasons | `road_overlap` (front edge and/or AABB vs road segments) |

Rejected IDs are listed in the JSON and the pilot log (`docs/qa/_64_chunk_pilot_log.txt`). Invalid footprints are **not** moved randomly.

## Collision generation

`BuildingShell._body` builds a `ConcavePolygonShape3D` from the **exact OSM ring** extruded to estimated height, named `hit_<osm_id>`, meta `osm_id`.

Visual mesh remains a single batched shell. Collision is separate (per accepted footprint).

## Drive probe

Automated aim at first accepted id `1337953920`:

```
DRIVE_HIT id=1337953920 speed=19.7 peak=19.7
```

Still: `docs/qa/65-chunk-collision.png`. Residual speed suggests the approach vector may have grazed past the footprint or needs a longer contact sample — collision shapes are present (`hit_*` bodies). Manual F6 drive in the pilot scene with **G** collision debug is the confirmation path.

Player car physics exports were **not** changed.

## Road / neighbour rules

- Asphalt clearance via `AssetPlacementValidator.asphalt_clearance`.
- Front-edge road distance &lt; 0.5 m → reject.
- Overlapping previously accepted footprints → reject.
- Courtyards / junctions covered by road segment tests in the spawn neighbourhood.
