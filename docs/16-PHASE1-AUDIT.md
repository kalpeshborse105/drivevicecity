# 16 — Phase 1 audit (28 Oct 2026)

Baseline commit: `2d5701c` (audit). Validation pass continued after that commit.

## Confirmed bugs (original)

| Bug | Evidence | Fix priority |
|-----|----------|--------------|
| Yellow marker clips through car roof | Screenshot; `look_at` pitch | P0 — fixed yaw-only |
| OSM `clip_polyline` keeps only longest run | Converter | P0 — fixed (`clip_polyline_runs`) |
| Too many decorative `StaticBody3D` | `street_kit.gd` | P1 — fixed (shells/walls only) |
| New `StandardMaterial3D` per box | `StreetKit.mat` | P1 — fixed (cache) |
| Filled lots on/near roads | Random lots | P1 — fixed (road samples) |
| Tall Label3D clutter | Road-name posts | P1 — quieter signs |

## Validation results (post-`2d5701c`)

| Check | Result | How |
|-------|--------|-----|
| Git HEAD / audit commit | `2d5701c` present; working tree had follow-up fixes this session | `git log` |
| Nav arrow yaw-only (no `look_at`) | **PASS** (code) | smoke + `nav_arrow.gd` |
| OSM multi-run clip present | **PASS** (code) | `clip_polyline_runs` |
| Multi-run needed in current Dhule clip? | **N/A impact** — 0 ways re-enter square clip; fix remains correct | Python count on raw OSM |
| Regenerated JSON loads | **PASS** — 285 roads, 24 anchors, spawn (−13.09, −86.21) | smoke |
| OSM attribution in JSON + HUD | **PASS** | smoke + `hud.gd` |
| Material cache no cross-pollution | **PASS** after fix (alpha key + `mat_emissive`) | smoke |
| Lots clear roads / spawn / anchors | **PASS** (code) — anchors clearance added this pass | `osm_road_builder.gd` |
| Lighting / fog softened | **PASS** (scene values) | `main.tscn` — F5 look still pending |
| Headless smoke | **PASS** | Godot 4.7.2 `godot.exe` via WinGet Links |
| Map build mesh/body counts | **PASS** — meshes≈10998, StaticBody3D≈582 (~5%) | smoke `_check_map_build_counts` |
| F5 visual / drive / jobs / FPS | **PENDING (you)** | see checklist below |

## Potential bugs (still need F5)

- Tire grip / soft launch feel
- Junction visual gaps / overlap
- Minimap SubViewport cost while driving
- Delivery zone visibility on bright asphalt
- Dense-core hitch with ~11k MeshInstances

## Visual weaknesses (still Phase 1)

- Flat procedural boxes (expected until more facade variety)
- Possible floating poles / thin props
- Not photoreal — target = coherent Indian town drive

## Performance note (automated, not FPS)

- Dense map build: **~11k meshes / ~582 static bodies**
- Collision ratio is healthy; mesh count is the main risk for laptop/Android later
- **FPS not measured** — requires your F5 run

## Missing / out of scope

- No Sketchfab / Blender hero cars (Phase 2)
- No Geofabrik full Western Zone download
- No Cesium / Unreal
- Orca optional (`C:\Users\Admin\Downloads\orca-v1.3.0.zip`) — not required for map work

## This validation pass — code fixes

1. Stop mutating shared materials (glass alpha in cache key; `mat_emissive` for lamps)
2. Filled lots also clear **delivery anchors** (22 m)
3. Smoke test expanded: attribution, nav yaw, material cache, map mesh/body counts

## Manual F5 checklist (pending — please run)

Open `D:\drivevicecity` in Godot 4.7.2 → **F5** on `scenes/main.tscn`:

1. [ ] Spawn on road, facing along road (not into wall)
2. [ ] Drive 30 s through core — junctions feel connected
3. [ ] No lot/shop blocking the carriageway
4. [ ] Yellow GPS arrow flat above car (not through roof)
5. [ ] W/S/A/D, brake, Space, **R** reset feel OK
6. [ ] Complete 2+ pickup → drop-off jobs (cash updates)
7. [ ] Minimap + “Target … m” update
8. [ ] **G** garage, **P** paint, **V** van
9. [ ] Note FPS / hitch in dense centre (Task Manager or Godot monitor)

Reply with fails + any FPS note; Phase 1 stays open until this passes.

## Phase 1 exit

**Not met yet** — automated checks OK; manual drive-through still required (`docs/13-BUILD-ORDER.md` unchanged).

## Development pass (same day, after validation)

| Change | Notes |
|--------|--------|
| Mixed shop/home kits | Awnings, balconies, parapets, roof tanks — procedural |
| Drive corridor | Wider setback; parked stubs only on wide majors |
| Roads | Wear patches + longer segment overlap |
| Density | shops~273 · meshes≈9192 · bodies≈487 (smoke PASS) |

**Best next step:** F5 checklist; report what still looks wrong before Phase 2.
