# 68 — Vehicle shadow A/B/C test (Phase 2H.4B.1)

**Baseline:** `91e10c8` · Carnival kit · same spawn · live IST sun  
**Probe:** `scripts/dev/shadow_qa_probe.gd --mode=A|B|C`  
**Stills:** `docs/qa/68-vehicle-shadow-{a,b,c}.png`

## Constraints (unchanged)

Engine force, brake, steering, suspension, gearbox, collision, and vehicle model dimensions were not modified.

## Configurations

| Mode | Rule | Resulting casters under `PlayerCar` |
|------|------|-------------------------------------|
| **A** | Top-2 car-sized **world** AABBs (prior 2H.4B pick) | `Object_22` + `Object_10` |
| **B** | All vehicle-kit + wheel + FX + nav geometry cast **off** | **0** |
| **C** | Single elongated chassis (plan aspect ≥ 1.35, plan 2.5–6.5 m) | **none found → all off** |

### Mode A keep log

```
VEH_KEEP Object_22 vol≈21–36 plan≈5.0–5.3
VEH_KEEP Object_10 vol≈21–36 plan≈5.0–5.3
VEH_CASTERS_ON 2
```

Both envelopes are near-square (~5×5 m plan) — paint/shell helpers, not a body silhouette.

### Mode C

```
VEH_KEEP_SINGLE none — all off
```

No elongated Carnival body mesh survived the filter.

## Visual comparison

| Mode | Still | Outline vs vehicle |
|------|-------|--------------------|
| A | `68-vehicle-shadow-a.png` | Detached oversized rectangle (often offset beside the car) — **reject** |
| B | `68-vehicle-shadow-b.png` | No directional kit stamp; mild SSAO contact only — **accept** |
| C | `68-vehicle-shadow-c.png` | Same as B (no chassis candidate) |

Luminance check (open-terrain Mode A vs Mode B on-road): Mode A shows a distinct dark side blob; Mode B has no detached plan-sized stamp ahead of the car (`road_ahead` remains bright).

## Decision

**Keep vehicle-kit shadow casting disabled (Mode B)** in production.

`player_car.gd` `_optimize_kit_shadows` turns every kit `GeometryInstance3D` off. Wheels, `TireSmoke*`, and `NavArrow` are also forced off. Broken kit envelopes are not preferred over no vehicle shadow.

Sun/policy lighting held constant across A/B/C (blur 1.5, opacity 0.72, max dist 90 m, 2 blended splits).
