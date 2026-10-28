# 16 — Phase 1 audit (28 Oct 2026)

## Confirmed bugs

| Bug | Evidence | Fix priority |
|-----|----------|--------------|
| Yellow marker clips through car roof | Screenshot; `nav_arrow.gd` uses full `look_at` which can pitch prism vertical | P0 |
| OSM `clip_polyline` keeps only longest in-bounds run | `tools/osm_to_game_json.py` | P0 |
| Decorative props create too many `StaticBody3D` | `street_kit.gd` collisions on sheds/walls/shops | P1 |
| New `StandardMaterial3D` per box | Every `StreetKit.mat()` / `add_box` | P1 |
| Filled lots can sit on/near roads | Random placement with no road clearance | P1 |
| Tall Label3D / sign posts feel like debug clutter | Road-name posts + zone labels | P1 |

## Potential bugs (need F5 manual test)

- Tire grip after last RWD fix (was improved; re-verify)
- Junction gaps from multi-run clip after converter change
- Minimap SubViewport cost on weak GPUs
- Delivery zone torus hard to see on bright asphalt

## Visual weaknesses (screenshot)

- Flat box buildings, washed warm sky/fog
- Floating thin poles / brown protrusions
- Empty-looking lots vs busy Indian street
- No textures (expected for Phase 1 procedural)

## Performance risks

- Dense core: hundreds of shops × many child meshes + collisions
- Per-call material allocation
- No LODs / no mesh batching yet

## Missing / invalid resources

- No Blender hero cars yet (Phase 2)
- Raw Geofabrik western-zone not required (local Dhule JSON exists)
- Sketchfab cars: Phase 2 only; licences often NC — verify before download
- Cesium for Unreal: **not** for this Godot project
- Orca zip present at Downloads — optional; not required for map work

## Smallest safe plan (this pass)

1. Fix nav arrow yaw-only (stop roof clip)  
2. Fix OSM clip → emit **all** continuous runs  
3. Shared material cache + fewer decorative collisions  
4. Safer lot placement (away from spawn road corridor)  
5. Soften lighting/fog; quieter road-name signs  
6. Save references doc + download guide for Phase 2  
7. Smoke test  

**Not in this pass:** Unreal/Cesium, Sketchfab import, full Western Zone download, Phase 2 vehicles.

## Implementation result (same day)

| Item | Status |
|------|--------|
| Nav yaw-only | Done (`scripts/nav_arrow.gd`) |
| Multi-run OSM clip + regen | Done — 285 ways / ~1554 segs / 24 anchors |
| Material cache + fewer collisions | Done (`street_kit.gd`) |
| Safer lots + quieter signs | Done (`osm_road_builder.gd`) |
| Softer fog / sun | Done (`scenes/main.tscn`) |
| Refs saved | Done (`docs/17-REFERENCES.md`) |
| Headless smoke | See worklog / agent report |
| F5 visual / delivery / FPS | Pending manual |

**Best next step:** F5 drive core streets; confirm nav arrow flat, no lot blocking roads, jobs still complete.
