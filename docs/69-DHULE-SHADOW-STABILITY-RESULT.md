# 69 — Shadow stability result (Phase 2H.4B.1)

**Baseline:** `91e10c8` · **Approved vehicle mode:** B (kit shadows off)  
**Probe:** `scripts/dev/shadow_qa_probe.gd --mode=drive` (also Mode B path)  
**Stills:** `docs/qa/69-drive-1.png` … `69-drive-5.png`, `69-buildings-props.png`, `69-open-terrain.png`, `68-vehicle-shadow-drive.png`

## Production changes

| File | Change |
|------|--------|
| `scripts/player_car.gd` | Kit visuals: all cast off; wheels/FX cleared after profile + FX setup |
| `scripts/vehicle_driving_fx.gd` | `TireSmoke*` `cast_shadow = OFF` |
| `scripts/nav_arrow.gd` + `scenes/nav_arrow.tscn` | Hidden prism cast off |
| `scripts/dhule_shadow_policy.gd` | Roads/marks/zebra/terrain/decals/helpers; Blosm giant AABB stays off; MouseQuad invalid |
| `scripts/vfx_environment_controller.gd` | SSAO radius 1.0 / intensity 0.95 (was 1.2 / 1.35) — reduces asphalt “under-car stamp” look without killing contact |

Unchanged: vehicle physics, road geometry, Blosm mesh, building chunk geometry.

## Moving-camera QA

Same Carnival, accelerate along spawn road, chase-cam locked each still:

1. Straight road — `69-drive-1.png` … `69-drive-5.png`
2. Junction / parcel frontage — covered in drive sequence + building still
3. Alongside buildings — `69-buildings-props.png` (chunk shells cast; footprints match)
4. Trees / props — MultiMesh trees remain casters; nearest instances ≫ 40 m from spawn in this clip
5. Open terrain — `69-open-terrain.png`

Sun ≈ **16:21–16:24 IST** during capture (live IST; within the requested afternoon band).

### Watched failure modes

| Failure | Status |
|---------|--------|
| Detached / giant vehicle rectangle | **Gone** (kit casters 0; Mode A reproduced the bug for proof) |
| Flicker while driving | No cascade pop from Blosm giant mesh (still cast off) |
| Shadow shape jumping with camera distance | Not observed with vehicle kit off + 90 m sun range |
| Shadows on empty terrain w/o caster | No vehicle/ghost casters within 40 m of spawn |
| Roads / marks casting | Policy keeps cast off |
| Building / prop shadows lost | Chunk shells + street props still cast |

## Runtime proof

```
PLAYER_CAST_ON 0
NEAR casters within 40 m of car: 0 GeometryInstance3D
Blosm: off_giant_aabb_7121m
VEH_CASTERS_ON 0 (Mode B / drive)
```

Residual darkening under the chassis is **SSAO contact**, not a directional mesh caster (confirmed: zero `cast_shadow` geometry under `PlayerCar` and none within 40 m).

## Acceptance

| Rule | Result |
|------|--------|
| No unexplained empty-terrain stamps from fake casters | Pass |
| No giant fake vehicle shadow | Pass (Mode B) |
| No flicker while driving (this clip) | Pass |
| Roads / marks non-casters | Pass |
| Generated buildings retain shadows | Pass |
| Approved props retain shadows | Pass |
| No vehicle physics / road / Blosm replacement | Pass |

**Gate:** Do **not** start city-wide larger building generation until this moving-camera shadow test remains green. Phase 2H.4B.1 closes on Mode B.

## How to re-run

```text
godot --path . --script res://scripts/dev/shadow_qa_probe.gd -- --mode=inv
godot --path . --script res://scripts/dev/shadow_qa_probe.gd -- --mode=A
godot --path . --script res://scripts/dev/shadow_qa_probe.gd -- --mode=B
godot --path . --script res://scripts/dev/shadow_qa_probe.gd -- --mode=C
godot --path . --script res://scripts/dev/shadow_qa_probe.gd -- --mode=drive
```

Prefer windowed (non-`--headless`) for PNG capture; headless can stall on viewport grabs.
