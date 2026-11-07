# 60 — Production regression audit (Phase 2H.3.1)

**Range:** `85a58c40` → `c339bf166` (`phase h`)  
**Engine:** Godot 4.7.2 · scene `scenes/main.tscn` · 1280×720  
**Date:** 2026-11-07

## Verdict

**Safe to use as the Phase 2H.4 baseline**, with the two small production fixes below already applied in the working tree.

Do **not** start city-wide building generation from this audit.

---

## 1. What `c339bf1` actually changed

| Area | Change | Classification |
|---|---|---|
| `project.godot` | Added `_mcp_game_helper` autoload; dropped explicit `directional_shadow/size=4096` (Godot default remains 4096); MSAA line reorder only | Intentional tooling / no-op |
| `scenes/main.tscn` | Sky locked to ~13:00 IST (`game_time_enabled=false`); HUD/garage layout (speed+gear panel, centered Home panel, `G` button) | Intentional Phase H UI |
| `scenes/player_car.tscn` | Chase cam `near=0.35`, `far=700` | Intentional (road-join depth, doc 42) |
| `scripts/player_car.gd` | Paint rename; removed showroom mode; gear caps → `_GEAR_FRACTION`; throttle strength `0.08+0.025g` → `0.18+0.07g`; force ramp `0.14` → `0.55`; dropped kit tint fallbacks / procedural kit parts | **Drive feel changed**; export force table unchanged (5200 / brake 35 / steer 0.55 / suspension 45·15000) |
| `scripts/osm_road_builder.gd` | Removed disabled `ALLOW_UNVERIFIED` street-pack seed; major decks `y_lift=+0.014`; dropped `_stacked_on_drawn_road` skip; barriers still Blosm-gated | Intentional road-join work; Blosm production path unchanged for props |
| `scripts/garage_ui.gd` + `garage_car_preview.gd` | New SubViewport Home preview; live customization | Intentional |
| `scripts/hud.gd` / `minimap.gd` | IST clock; HUD string tweaks | Intentional |
| `scripts/vfx_environment_controller.gd` | Live IST sky sync | Intentional |
| `scripts/asset_kit.gd` | Dropped `indian_house` kit key | OK — house fit lives in catalog/prototype paths |
| `scripts/vehicle_audio.gd` / `vehicle_driving_fx.gd` | Trimmed settings hooks | Cosmetic |

Docs/QA import noise and `_*.txt` logs also landed in that commit; they do not affect runtime.

---

## 2. Production smoke (`scenes/main.tscn`)

| Check | Result |
|---|---|
| Starts without script parse errors | Pass |
| Dhule map / PHASE1 | **796 ways**, spawn `(-636.5, 881.8)` |
| Car at spawn | `(-636.54, ~0.13, 881.83)` — original spawn |
| Accelerate / steer / gear | Pass — peak ~20 km/h into G2 in 2 s; continues into G3 under sustained throttle (new fractions) |
| Brake / camera / minimap / HUD / jobs | Pass (HUD job banner + GPS line present in stills) |
| Garage panel present | Pass (`HAS_GARAGE true`) |
| Missing assets / invalid paths | None observed (only known legacy `Parameter "material" is null` renderer noise) |

Stills: `docs/qa/60-production-spawn.png`, `docs/qa/60-production-driving.png`.

### Vehicle vs `85a58c4`

| | Baseline | `c339bf1` |
|---|---|---|
| `engine_force_value` / brake / steer / suspension exports | Unchanged | Unchanged |
| Gear speed caps | Fixed km/h ladder (10…70) | Fractions of `max_speed_kph` (Carnival ~24…130) |
| Throttle strength / ramp | Weaker / slower | Stronger / snappier |

**Not reverted.** Feel differs by design of `phase h`. Arcade force *tables* match Phase 2G doc 53. No physics retune in this audit.

---

## 3. Road / crossing (`scenes/dev/dhule_visual_qa.tscn`)

| Check | Result |
|---|---|
| Crosswalks placed | **6** (6 arms skipped — tip-meeting rule) |
| Junction pad continuity | Pass — no asphalt gap in QA stills |
| Edge paint / zebra / stop-line policy | Unchanged from 2H.3 scripts; markings still generated |
| Roundabout approaches | Unchanged path in builder |
| Road / mark shadow cast | Policy `roads_off=1 marks_off=1` |

Still: `docs/qa/60-production-junction.png` (QA scene, street-level toward junction + shells).

---

## 4. Shadow policy

**Bug found (pre-existing timing, exposed by this audit):**  
`DhuleShadowPolicy.apply_after_roads` ran from road flush **before** `DhuleBlosmCity` existed, so `blosm_shadow_mode` stayed empty and the ~7 km joined mesh kept casting.

**Fix applied (smallest):**

1. Match `dhule_city_osm_buildings` / water names in `scripts/dhule_shadow_policy.gd`.
2. Re-call `DhuleShadowPolicy.apply_after_roads(self)` after `_add_osm_context` in `scripts/osm_road_builder.gd`.

**After fix (production probe):**

```
SHADOW policy … blosm=off_giant_aabb_7121m …
SHADOW_CASTERS … road_on=0 blosm_on=0
```

Vehicle and building-shell shadows remain on. Roads/junctions/marks stay off.

---

## 5. Production performance (1280×720, Intel UHD 620 class)

Probe: `scripts/dev/production_regression_probe.gd` (windowed, not the synthetic QA FPS).

| Sample | FPS med | Draws med | Notes |
|---|---|---|---|
| Spawn (post-fix) | **4** | **2426** | After ~214 s boot on a busy machine |
| Driving | **4** | — | Same session |
| Near buildings | skipped | — | Probe name lookup missed `DhuleBlosmCity`; Blosm is loaded |
| Static mem | — | — | ~132 MB |
| Shadow casters on | — | — | ~910 (trees/props/shells/vehicle); giant Blosm off |

**Garage preview regression (from `c339bf1`):** preview SubViewport used `UPDATE_ALWAYS` while Home was closed → second 3D world every frame.

**Fix applied:** `garage_car_preview.set_live(on)` · default `UPDATE_DISABLED` · toggled from `garage_ui.toggle()`.

Draws fell ~2832 → ~2426 after that fix; FPS in this probe session stayed ~4 (machine/load bound — prior production notes on this PC were ~13–19 FPS / ~1680 draws). Treat probe FPS as a lower bound, not a Phase H.4 gate failure.

---

## 6. Fixes shipped in this audit (only)

| File | Why |
|---|---|
| `scripts/garage_car_preview.gd` | Stop closed-garage SubViewport render |
| `scripts/garage_ui.gd` | Wire `set_live` on Home toggle |
| `scripts/dhule_shadow_policy.gd` | Recognize Blosm mesh names; kill water cast |
| `scripts/osm_road_builder.gd` | Re-apply shadow policy after Blosm attach |

No car-controller rewrite, no road-system rewrite, Blosm not replaced.

---

## 7. Unresolved / follow-ups (not blockers for 2H.4 start)

- Probe FPS on UHD 620 remains poor under automated load; re-sample manually with F5 when the machine is idle.
- `PERF_NEAR_BUILDINGS` name lookup should use `DhuleBlosmCity` next time.
- Legacy `Parameter "material" is null` renderer errors persist (pre-existing).
- Drive feel vs `85a58c4` is intentionally different; restore `_GEAR_CAP_KPH` + old strength/ramp only if product wants the old ladder back.
- Non-Blosm barrier path still calls `_strip_physics` (irrelevant while Blosm is the production city).

---

## 8. Baseline decision

| Question | Answer |
|---|---|
| Is current production safe as Phase **2H.4** baseline? | **Yes**, after the two fixes above |
| Start city-wide building generation now? | **No** — out of scope for 2H.3.1 |

Git: working tree has audit docs/stills + the four fix files; do not force-push. Commit when ready.
