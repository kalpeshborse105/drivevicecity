# 49 — Building asset integration

Isolated scene: `scenes/dev/dhule_building_asset_test.tscn`.  
Fitter: `scripts/building_asset_fitter.gd`.  
Production Blosm city, `scenes/main.tscn`, roads, spawn, and car physics were not changed in this phase.

## Method

1. Load the same 24 spawn-area OSM footprints as the phase-2E neighbourhood test.
2. For cottage / family / row styles with area 55–120 m², try `indian_house.glb`.
3. Prepare the house from the raw mesh (longest plan axis on Z, grounded). Do not force the 8 m kit normalize.
4. Binary-search a uniform scale so every AABB corner stays inside the OSM ring with a 0.2 m inset.
5. Reject the asset if the scaled height would fall below 2.8 m, or if the placed AABB is closer than 0.5 m to the asphalt polygon.
6. Fall back to `BuildingShell` procedural geometry. Do not move the OSM ring.

Entrance yaw faces the road-side edge. That facing is an estimate; the GLB has no tagged front door metadata beyond its textured facade.

## Result on the 24 footprints

| Result | Count |
| --- | ---: |
| Fitted `indian_house.glb` | 5 |
| Procedural shell | 19 |
| Rejected for road overlap | 0 |

Fitted way ids: `1337953920`, `1337953919`, `1337953924`, `1337953918`, `1337953921`.  
Each report recorded `inside=true`, `road=false`, clearance from 3.84 m to 20.66 m, asset plan area about 50–56 m² inside a 75 m² ring.

Shop estimate `1337951728` and the large 265 m² outline `1337951715` kept procedural shells: no suitable complete GLB. Apartments, offices, warehouses, and civic buildings were not invented.

## Comparison shelf

East of the spawn the scene shows:

- Raw `indian_house`
- Kit-normalized 8 m `indian_house`
- Kit-normalized `bhelpuri` cart
- A label that the street pack is props only (the 56 MB pack is not instanced in the drive view)

## Performance

Godot 4.7.2, 1280×720, Intel UHD 620. Debug overlays off for the FPS rows.

| View | FPS median | Draws | Video MB | Static MB |
| --- | ---: | ---: | ---: | ---: |
| Asset test, street | 11.0 | 114 | 186.6 | 77.1 |
| Asset test, aerial | 30.0 | 80 | 186.6 | 77.1 |
| Phase-2E procedural-only (doc 47, street) | 13.0 | 42 | 147.9 | 68.1 |
| Phase-2E procedural-only (doc 47, aerial) | 26.0 | 28 | 147.9 | 68.1 |

Five textured houses raise draw calls and video memory. This scene is not faster than the procedural block. Collision bodies: one box per fitted house, one concave shell per procedural building, plus ground and optional yard walls.

## Controls

- C — aerial camera
- V — toggle footprint / asphalt debug overlays

## Pictures

- `docs/qa/48-street.png` — fitted house beside procedural neighbours
- `docs/qa/48-aerial.png` — mixed block
- `docs/qa/48-clearance.png` — asphalt (red), footprints (green), asset boxes (blue)
- `docs/qa/48-compare.png` — shelf comparison
- `docs/qa/48-collision.png` — drive toward a fitted house
