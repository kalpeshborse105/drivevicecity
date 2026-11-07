# 67 — Dhule shadow caster inventory (Phase 2H.4B.1)

**Baseline:** `91e10c8` · **Engine:** Godot 4.7.2  
**Probe:** `scripts/dev/shadow_qa_probe.gd --mode=inv`  
**Raw dump:** `docs/qa/67-shadow-caster-inventory.json` · log `docs/qa/_67_inv.log`

## Method

Runtime walk of every `GeometryInstance3D` with `cast_shadow != OFF` after `main.tscn` load and `DhuleShadowPolicy.apply_after_roads`. Each row records node path, mesh/name, world position, world AABB size, cast state, distance from `PlayerCar`, and class (`vehicle` / `building_chunk` / `tree_or_multimesh` / `prop` / `road` / `terrain` / `blosm` / `garage_preview` / `other`).

No source was assigned by looking at the screenshot alone.

## Active DirectionalLight3D

| Path | Shadow | Notes |
|------|--------|-------|
| `/root/Main/Sky3D/SunLight` | **on** | blur 1.5, opacity 0.72, bias 0.06, normal bias 2.0, 2 splits, max dist 90 m |
| `/root/Main/Sky3D/MoonLight` | off | energy 0 |
| Garage preview lights (2) | off | isolated `SubViewport` |

## Summary (post vehicle-kit disable)

| Class | Casters on |
|-------|------------|
| garage_preview | 389 (not in world sun) |
| other (street props / poles / shops…) | 127 |
| tree_or_multimesh | 2 |
| terrain | 0 after MouseQuad kill (was 1 helper) |
| vehicle | **0** |
| blosm buildings | **0** (giant joined AABB kept off) |
| road / marks | **0** |
| **Total on** | ~519 (mostly garage viewport) |

World casters near the Carnival spawn (`≈ −636.5, 881.8`) within **25 m**: **none** after production fix.

## Pre-fix vehicle casters (evidence)

Before Mode B production, inventory listed these under `PlayerCar` (distances ≈ 0.8–3 m):

| Node | Type | World AABB (m) | Issue |
|------|------|----------------|-------|
| `Object_22` | MeshInstance3D | ≈ 5.02 × 1.45 × 4.94 | Near-square paint envelope → oversized box stamp |
| `Object_10` | MeshInstance3D | ≈ 5.00 × 1.45 × 4.92 | Same |
| `TireSmokeL` / `TireSmokeR` | GPUParticles3D | particle AABB | Idle particle casters |
| Wheel `Mesh` / `Rim` ×4 | MeshInstance3D | wheel-sized | Extra stamps while rolling |
| `NavArrow/MeshInstance3D` | MeshInstance3D | prism | Hidden nav mesh still cast |

Carnival kit local AABBs are meaningless (thousands of units); world AABB after normalize is required.

## Blosm / chunk / roads

- Production Blosm joined buildings: plan ≈ **7121 m** → policy forces **cast off** (`off_giant_aabb_7121m`).
- Chunk pilot shells (`building_shell.gd`): cast **on** (genuine footprints).
- Roads, road marks, junctions, zebra / kit crossings: cast **off**.
- Terrain3D `MouseQuad` picking helper: cast **off** (invalid helper).

## Policy counters (sample boot)

```
SHADOW policy roads_off=1 marks_off=1 terrain_off=0 invalid_off=… blosm=off_giant_aabb_7121m lights=1 casters_on≈125
```

Garage preview meshes inflate the global “on” count but do not receive the world sun.
