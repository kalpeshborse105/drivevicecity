# 56 — Dhule building prototype report (Phase 2H.2)

Isolated scene `scenes/dev/dhule_building_prototype.tscn`. Production Blosm, roads, spawn, missions, minimap, and vehicle forces were not modified. Local WIP in `player_car.gd` / `asset_kit.gd` left unstaged.

**Baseline:** `d2df4b0`. **Controls:** C aerial · F footprint outlines · G collision debug · H info labels.

## Selection

Source: `assets/maps/dhule_city.osm` rings (not JSON boxes). Prefer 72–180 m² near spawn; include irregular rings and the only two quads in-band within ~200 m.

All 16 accepted. All are `building=yes` with **no** `height`, `building:levels`, `shop`, or `amenity`. Every height below is **estimated**.

| OSM id | Verts | Area m² | Dist spawn m | Style | Est. floors | Front clear m | Validator clear m |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| 1337953920 | 17 | 75.3 | 16.7 | traditional_compact | 1 | 4.64 | 2.23 |
| 1337953903 | 16 | 83.9 | 21.1 | plastered_house | 2 | 11.63 | 9.24 |
| 1337951730 | 12 | 76.7 | 21.9 | plastered_house | 2 | 12.51 | 10.19 |
| 1337953921 | 17 | 75.4 | 30.8 | narrow_urban | 2 | 21.46 | 19.05 |
| 1337953918 | 17 | 75.4 | 34.7 | plastered_house | 2 | 18.27 | 15.94 |
| 1337953905 | 16 | 84.0 | 36.0 | narrow_urban | 2 | 12.00 | 11.39 |
| 1337953904 | 16 | 84.0 | 36.4 | traditional_compact | 1 | 24.46 | 22.07 |
| 1337952466 | 12 | 76.7 | 37.7 | plastered_house | 2 | 4.73 | 4.54 |
| 1337953902 | 16 | 84.0 | 41.0 | plastered_house | 2 | 28.12 | 25.73 |
| 1337953919 | 17 | 75.4 | 41.3 | plastered_house | 2 | 12.46 | 12.17 |
| 1337952468 | 12 | 76.7 | 48.7 | traditional_compact | 1 | 28.33 | 25.73 |
| 1337952467 | 12 | 76.7 | 52.1 | plastered_house | 2 | 9.94 | 7.33 |
| 1337951722 | 12 | 66.9 | 53.4 | traditional_compact | 1 | 43.27 | 41.82 |
| 1337951728 | 8 | 86.2 | 59.8 | traditional_compact | 1 | 35.57 | 31.70 |
| 1337951691 | 4 | 89.8 | 193.3 | narrow_urban | 2 | 1.51 | 1.11 |
| 1337951692 | 4 | 89.8 | 199.0 | narrow_urban | 2 | 1.13 | 0.73 |

Style counts: A plastered_house **7**, B narrow_urban **4**, C traditional_compact **5**. Non-quad **14**, quad **2**. In preferred band 72–180: **15** (one compact under 72 m² for style C).

Rejected: **0** (road clearance ≥ 0.5 m via front edge + Phase 2G `AssetPlacementValidator`).

## Metadata per building

Stored in runtime `_meta` / console `BUILDING_PROTO`:

- `osm_id`, `building` tag, `source_levels`, `estimated_levels`, `height_source` (`osm`|`estimated`)
- `area_m2`, `style_variant`, `collision`, clearances

## Geometry

Extrusion follows the OSM ring (`BuildingShell`). Concave / stepped plans kept. Roof triangulated inside the ring. No courtyard fill. Facade trim does not expand the ground footprint.

**Hole limitation:** simple outer rings only. Multipolygon inners are absent on these ways; hole support was not added.

## Collision

Car drove into way `1337953920`: peak 13.9 km/h → 0.2 km/h at (−637.78, 0.11, 890.27). Bodies: 16× `hit_<id>` + ground + yard = **18** static bodies.

## Performance (1280×720, Intel UHD 620)

| Metric | Value |
| --- | ---: |
| FPS median | 44 |
| Draw calls median | 181 |
| Objects median | 319 |
| Static bodies | 18 |
| Buildings | 16 |
| Chunk meshes | 1 visual shell (7 surfaces) |

**City scale:** do not ship one node per building. Keep chunk meshes + side OSM id buffer (docs 35–36).

## Screenshots

- `docs/qa/56-aerial.png` — rings + shells
- `docs/qa/56-street.png` — street level
- `docs/qa/56-collision.png` — car stopped on contact

## Production

Not integrated. Blosm remains the city. Approve this block before any wider generation.

## Left unchanged

`scenes/main.tscn`, Blosm GLB, OSM roads/buildings source files, spawn, delivery, minimap, vehicle force tables.
