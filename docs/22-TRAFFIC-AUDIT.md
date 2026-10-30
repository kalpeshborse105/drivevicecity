# 22 — Traffic / navigation / delivery audit (30 Oct 2026)

## Current systems (preserved)

| System | Status |
|--------|--------|
| Player `VehicleBody3D` drive | OK — do not rewrite |
| Delivery jobs + anchors | OK — 24 pinned OSM anchors |
| Nav arrow / mission distance | OK — target tracking only |
| OSM roads in JSON | OK — 420 ways, Ring 1 ±1600 m |
| NPC traffic AI | **Missing** — no road-following traffic manager yet |

## Road network readiness for traffic

- Polylines exist in `dhule_roads_game.json` (`points`, `width`, `highway`).
- No lane graph / centreline graph is built at runtime for AI pathing.
- Intersections are geometric overlaps of road decks (no dedicated junction nodes).
- **Missing before expanding traffic coverage:**
  1. Build a lane centreline graph from OSM ways (snap endpoints within ~8–12 m).
  2. Detect T / cross junctions; store left-side driving offsets (−X when facing travel).
  3. Spawn sparse NPC cars only on majors first (primary/secondary).
  4. Obstacle avoid: ray ahead + soft steer; never rewrite player physics.

## Indian left-side convention

Drive on the **left**. When traveling along road direction `along`, curb/parking side is `+cross` or `−cross` consistently — pick **left = along × up** in Godot Y-up (`cross = along.cross(UP)` → left is `−cross` if along is forward… verify in a unit test before shipping AI).

## Recommended open references (formula only — do not rip assets)

- [Kenney Starter Kit Racing](https://github.com/KenneyNL/Starter-Kit-Racing) — MIT/CC0 smoke/sound *ideas*
- [DAShoe1/Godot-Easy-Vehicle-Physics](https://github.com/DAShoe1/Godot-Easy-Vehicle-Physics) — MIT vehicle patterns (not a drop-in replace)
- Avoid unpaid ArtStation packs / ripped GTA audio

## Sky3D

**Not installed.** Existing `WorldEnvironment` + `VFXEnvironmentController` (T presets) is sufficient for Phase 1. Revisit only with a separate test scene if SSR/sky quality still insufficient.

## Next traffic milestone (not started)

`scripts/traffic_manager.gd` — spawn ≤12 visual NPC cars on major polylines, left-side offset, stop at delivery zones clear of player. Test intersections + delivery completion before city-wide density.
