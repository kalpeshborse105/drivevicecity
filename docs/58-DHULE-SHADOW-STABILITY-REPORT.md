# 58 — Shadow stability report (Phase 2H.3)

## Symptom

Unstable dark patches on empty terrain while driving — not attached to nearby buildings.

## Verified non-causes

| Candidate | Finding |
| --- | --- |
| Road ribbons / marks / junctions | Already `cast_shadow = OFF` in `RoadSurface` — confirmed |
| Horizon Terrain3D | `cast_shadows = OFF` — confirmed |
| Road MultiMesh paint/curbs | Were ON by default → now **OFF** via `StreetKit._commit_batch(..., false)` |
| Trees | Still **ON** (attached canopy/trunk shadows) |

## Measured cause

`DhuleShadowPolicy` + diagnostic (`S` in visual QA):

- Road/mark casters correctly off after policy.
- Joined Blosm city mesh AABB is multi-kilometre. When that mesh casts, directional cascade shadows smear and flicker on empty ground far from any facade.
- Policy: if buildings mesh plan span **> 1500 m**, set `cast_shadow = OFF` and record `blosm_shadow_mode=off_giant_aabb_*`. Chunked / prototype shells keep attached shadows.

Lights tuned (without editing `main.tscn`): parallel 4-split, `max_distance=110`, higher bias/pancake.

## Acceptance

| Rule | Status |
| --- | --- |
| Roads / marks / junctions do not cast | yes |
| Trees / solid props / vehicles can cast | yes |
| Prototype shells cast attached shadows | yes |
| Giant Blosm joined mesh does not paint empty terrain | yes (disabled when AABB huge) |
| No global “shadows off” | yes — selective |

Diagnostic screenshot: `docs/qa/58-shadow-diag.png`. Moving camera: `docs/qa/58-shadow-moving.png`.

## City-scale note

Attached building shadows at district scale need **chunked** meshes (docs 35–36), not one city-wide AABB.
