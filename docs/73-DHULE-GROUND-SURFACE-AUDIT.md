# 73 — Ground surface audit (Phase 2H.4B.3)

**Baseline:** `58fa44d` · **Engine:** Godot 4.7.2  
**Recording:** `C:\Users\Admin\Videos\Recording 2026-11-07 171750.mp4` (~28 s, Carnival, Mode B)  
**Frames:** `docs/qa/73-recording-frames/frame_*.png`  
**Inventory:** `docs/qa/73-ground-surface-inventory.json` · probe `scripts/dev/ground_surface_qa_probe.gd`

## Recording symptoms

- Vehicle Mode B OK — no giant detached car stamp.
- Open terrain shows **large irregular / rectangular dark regions** beside roads while driving (~17:16 IST).
- Light yellow-green textured ground vs darker brown/green hard-edged patches (patchwork).
- Production scene (`main.tscn`), not the 48-building pilot green slab.

## Runtime inventory (near spawn neighbourhood)

| Kind | Count (scene) | Notes |
|------|---------------|-------|
| `ground_slab` | 6 | Includes **4400×1×4400 m** drive box — **cast was ON** |
| `ground_overlay` | 89 | Thin boxes; many 16–42 m with flat scrub/earth colours — **cast ON** when created before batch |
| `multimesh_box_batch` | 12 | StreetKit flush — cast already OFF |
| `terrain3d` | 1 | Horizon ring — cast OFF by script |
| other (props/lamps…) | 186 | |

Critical pre-fix nodes:

- `/root/Main/DhuleMap` ground `BoxMesh` **4400 m**, `cast=true`, textured `ground037`.
- Dozens of pre-batch `MeshInstance3D` overlays, e.g. aabb ≈ 28×0.07×30 m, albedo `(0.28, 0.38, 0.22)` scrub / `(0.45, 0.38, 0.28)` earth, **`cast=true`**.

Source code: `osm_road_builder.gd` `_add_ground()` runs **before** `StreetKit.begin_box_batch()`, so slab + 32 dirt patches were individual meshes with Godot default shadow casting.

## Controlled A/B (same chase camera)

| Mode | Change | Right-terrain band avg luminance | Dark fraction |
|------|--------|----------------------------------:|--------------:|
| **A** | Directional shadows ON | **7.2** | **0.998** |
| **B** | Directional shadows OFF | **187** | 0.003 |
| **C** | Shadows ON, dark overlays hidden | **145** | 0.005 |

Stills: `docs/qa/73-ab-a.png`, `73-ab-b.png`, `73-ab-c.png`.

### Conclusion (evidence, not guess)

1. **Primary:** Directional shadows cast by the **giant ground slab** and **flat dirt/scrub overlay boxes** → giant dark terrain stamps (Mode A nearly black; Mode B clears them).
2. **Secondary:** Overlay **albedo** is much darker / flatter than the textured base → remaining patchwork when shadows are off (Mode B still shows brown rectangles).
3. **Not** vehicle kit shadows (Mode B policy already off).
4. **Not** Terrain3D horizon (cast already off; far ring only).
5. **Not** Blosm giant mesh (already cast off).

## Production vs pilot

Pilot (`dhule_building_chunk_pilot.tscn`) uses a solid green debug ground — ignore for this audit. Production drive surface is `DhuleMap` slab + overlays + roads.
