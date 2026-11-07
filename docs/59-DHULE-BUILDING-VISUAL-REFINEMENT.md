# 59 — Building visual refinement (Phase 2H.3)

Scope: existing 16-building prototype / visual QA subset only. Production Blosm untouched. Heights remain **estimated** unless OSM provides levels.

## Changes (`building_shell.gd`)

| Detail | Behaviour |
| --- | --- |
| Windows | Recessed frame + inset glass; style-tuned size (cottage smaller, row taller, family wider) |
| Glass | Cooler tint, metallic 0.35, roughness 0.12 |
| Doors | Frame + recessed leaf + sill |
| Sunshades | Kept / slightly deeper on family & row |
| Parapet / tank / balcony / plinth | Existing kit; styles A/B/C still map through `dhule_building_styles.gd` |
| Footprint | Unchanged OSM rings; trim stays outside plaster without expanding ground plan |
| Collision | `hit_<id>` bodies unchanged |

No invented shop names or unverified identities.

## QA

`scenes/dev/dhule_visual_qa.tscn` (B = building detail, G = collision). Screenshots: `docs/qa/59-buildings-street.png`, `docs/qa/59-buildings-aerial.png`.

PERF (UHD 620, 1280×720, visual QA): fps_med ≈ 10, draws_med ≈ 210 (synthetic junctions + OSM slice + shells + diagnostics). Prototype block alone previously ~44 FPS — full QA is heavier by design.

## Not done

City-wide generation. Production integration of shells.
