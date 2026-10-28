# 04 — Work log (step by step)

Record of what we already completed. Newest at bottom of each day.

---

## 2026-10-28 — R&D + P0 scaffold

### Step 1 — Idea R&D (done)

- Goal: free-roam Dhule city drive + later delivery missions + vehicle customization.
- Verdict: **idea OK**, must **phase** (no full India map in v1).
- Hard rule: **no Google Maps data**; use **OpenStreetMap** later + own Blender assets.
- Engine choice: **Godot 4** (fully free). Play org account already available for later publish.
- R&D canvas (Cursor): `C:\Users\Admin\.cursor\projects\d\canvases\dhule-city-game-rnd.canvas.tsx`

### Step 2 — Create project folder (done)

- Created: `D:\drivevicecity`
- Cursor workspace rooted on this folder.

### Step 3 — Install engine (done)

- Installed via winget: **Godot Engine 4.7.2**
- Package id: `GodotEngine.GodotEngine`
- Project imported successfully (`--import` exit 0).

### Step 4 — P0 game files (done)

| Item | Status |
|------|--------|
| `project.godot` + input map | Done |
| Driveable `VehicleBody3D` car | Done |
| Chase camera | Done |
| Procedural Dhule-style block map | Done |
| Landmark labels (placeholder names) | Done |
| India-afternoon environment | Done |
| HUD (speed + controls hint) | Done |
| README + MIT license | Done |

### Step 5 — Documentation pack (done)

- Added `docs/` index + setup / run / structure / worklog / roadmap / map-legal / play-store.

### Step 6 — IDE open on game folder (done)

- Workspace is `D:\drivevicecity` — edit code here, play in Godot with **F5**.

### Step 7 — Docs pack (done)

- Full `docs/` set (setup, run, structure, worklog, roadmap, map/legal, play store).

---

## 2026-10-28 — P1 OSM + delivery

### Step 8 — Download Dhule OSM (done)

- Overpass / OSM API clip around Dhule center.
- Tool: `tools/osm_to_game_json.py` → `assets/maps/dhule_roads_game.json`
- ~285 ways, ~20 delivery anchors, ±900 m clip.

### Step 9 — Runtime map + missions (done)

- `osm_road_builder.gd` builds roads + sparse buildings.
- `delivery_mission.gd` + `delivery_zone.tscn`: green pickup → orange deliver → cash.
- `game_bootstrap.gd` spawns car on map and starts jobs.
- HUD shows mission / ₹ / delivery count.
- Doc: `docs/08-P1-OSM-AND-DELIVERY.md`

### How to test P1

1. Godot **F5**
2. Complete **10 deliveries** (exit criteria)
3. Confirm R reset still works; no soft-lock if you miss a zone

---

---

## 2026-10-28 — P2 mapping + vehicles + jobs

### Audit findings

- Spawn was on map edge; car had no road heading; floaty suspension.

### Fixes / features

- Regenerated `dhule_roads_game.json` with core `spawn` + `hx/hz` headings  
- Car spawns grounded and faces road; blue SPAWN pad  
- Nav arrow + distance HUD  
- **P** paint, **V** sedan/van  
- Parcel / Food / Passenger jobs  
- Doc: `docs/09-P2-VEHICLES-AND-JOBS.md`

### Test

1. F5 → confirm spawn on road + heading  
2. Follow arrow through 3+ mixed jobs  
3. P/V customization  

---

---

## 2026-10-28 — Test + original visuals + UI

### Tested

- Headless main load: OSM 285 ways, core spawn + heading OK  
- Map JSON integrity (anchors/headings) OK  
- Added `tools/smoke_test.gd` for repeatable PASS/FAIL  

### Built (original, no paid packs)

- `vehicle_mesh_builder.gd` — sedan + delivery van kits  
- Shopfronts / awnings / sidewalks / lamp posts on map  
- Minimap (top-right) + Garage UI (**G**)  

### Docs

- `docs/10-TEST-AND-VISUALS.md`

---

---

## 2026-10-28 — User guide + direction from screenshot

### Clarified

- Screenshot = correct systems, **weak city density / debug clutter**
- Right references: learn **formula** from GTA / BUSID; build **own** Dhule India game
- v1 north star closer to **BUSID-like local jobs** than GTA V graphics

### Docs added

- `docs/USER-GUIDE.md` — how to play  
- `docs/11-DIRECTION-VS-REFERENCES.md` — screenshot vs big games + S1–S8 steps  

### Small fix toward S1/S2

- Removed giant world SPAWN label + OSM Label3D watermark  
- OSM credit on HUD; denser shopfronts near spawn  

---

---

## 2026-10-28 — S2 density + S3 camera/markings

### Built

- `scripts/street_kit.gd` — shop rows, lamps, trees, parked stubs, billboards  
- Continuous sidewalks + edge lines + denser core around spawn (~320 m)  
- Chase camera higher / speed pull-back / look farther ahead  
- Doc: `docs/12-S2-STREET-DENSITY.md`

### Test

F5 from spawn — streets should show shop boards instead of empty desert.

---

---

## 2026-10-28 — Locked build order from screenshot

### Decision (user)

1. Whole **map** design realistic (own) first  
2. Then **vehicle** design + customization  
3. Then deeper **play** / run features  

Doc: `docs/13-BUILD-ORDER.md`

### Phase 1A started

- Flat GPS arrow + ring pickup zones (no tall yellow debug beam)  
- Shop kits: windows, roofs, pillars, compound walls  
- Darker asphalt  

### Still in Phase 1

- More lot fill, sky/lighting, landmarks  
- Then Phase 2 hero vehicle  

---

## 2026-10-28 — Phase 1C/1D/1E

- Filled lots + ground variety  
- India afternoon sky / sun / SSAO / fog  
- Water tower, bus stop, market stalls  
- Doc: `docs/14-PHASE1-LOTS-SKY.md`  

Next: finish map polish or start **Phase 2 vehicle**.

---

## 2026-10-28 — Tire fix + OSM road names + Cursor rule

- Fixed wheel mesh axis (spin on X) + RWD grip / soft launch  
- OSM street name signs (Sakri Road, SH 14, etc.) — **not Google**  
- Cursor always-on rule: `.cursor/rules/drivevicecity.mdc`  
- Doc: `docs/15-MAP-NAMES-AND-TIRES.md`

## 2026-10-28 — Phase 1 audit pass (map realism)

- Audit: `docs/16-PHASE1-AUDIT.md` · refs: `docs/17-REFERENCES.md`
- Fixed nav arrow **yaw-only** (stops yellow prism through roof)
- OSM clip: keep **all** in-bounds runs → regen `dhule_roads_game.json` (285 ways)
- Shared material cache + fewer decorative collisions in `street_kit.gd`
- Safer filled lots (clear of road samples) · quieter road-name signs
- Softer Maharashtra daylight (less orange fog / bloom)
- Smoke: `godot --headless --path D:\drivevicecity -s res://tools/smoke_test.gd`

**Still Phase 1:** F5 drive-through, delivery jobs, FPS note. No Phase 2 yet.

When you finish a session, append a short dated block here (what changed + how to test).
