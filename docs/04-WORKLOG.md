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

---

## 2026-10-28 — Validate audit `2d5701c` + small fixes

- Confirmed HEAD audit commit; refs still in `docs/17-REFERENCES.md`
- Smoke **PASS** (expanded): attribution, nav yaw-only, material cache, map build counts  
  - meshes≈10998 · StaticBody3D≈582 · roads=285 · anchors=24
- Fixed shared-mat mutation (alpha cache + `mat_emissive`)
- Lots now clear delivery anchors (22 m) as well as roads/spawn
- Current Dhule clip: **0** OSM ways need multi-run split (square clip); converter still preserves all runs
- **F5 manual checklist pending** (recorded in `docs/16-PHASE1-AUDIT.md`)
- Phase 1 **not** exited; Phase 2 not started

---

## 2026-10-28 — Phase 1 map development (OSM + own kits)

Used **existing Dhule OSM JSON** + original `street_kit` (no Sketchfab / Cesium / Geofabrik full download).

- Shops + homes frontages (awnings, balconies, parapets, rooftop tanks, compound walls)
- Clearer drive corridor (wider setback, fewer parked stubs on narrow roads)
- Road wear patches + longer segment overlap at junctions
- Utility poles; calmer prop density
- Smoke **PASS** — meshes≈9192 · StaticBody≈487 · shops~273 (down from ~11k / 425)

**Still Phase 1:** F5 drive. Phase 2 vehicles only when you say so (Sketchfab = licence check first).

---

## 2026-10-28 — More realistic Phase 1 assets + test

- Smoke **PASS**; main scene headless boot **OK** (4s quit)
- Procedural asphalt/sidewalk grain (`NoiseTexture2D`)
- Zebra crossings + speed breakers on busy majors
- New props: roadside shrine, chai stall, auto-rickshaw stub
- Delivery zone brighter ring / quieter label
- Counts: meshes≈9355 · bodies≈504 · landmarks~18

**Your turn:** F5 visual drive. No Phase 2 yet.

---

## 2026-10-28 — Fix: car stuck + spawn corridor

Screenshot: building wall jammed car (0 km/h), glass in lane.

- Vehicle: `can_sleep=false`, stronger engine, higher chassis, wake on input
- Map: no shops/walls within ~38 m of spawn; wider setback; home front walls no collision
- Landmarks pushed off the spawn lane

Retest: **R** then hold **W**.

---

## 2026-10-28 — Faster drive + garage customization (Phase 2 start)

- Arcade power: AWD · engine ~520 · top ~145 km/h (was crawling at 2 km/h)
- Garage **G**: 10 paints · Sedan/Van · kits (Stock/Spoiler/Roof/Sport) · rims
- Own procedural meshes only — **no** Sketchfab NC / game-ripped cars
- Smoke PASS expected after relaunch

---

## 2026-10-28 — Dhule clip from local OSM (map only)

- Audited `western-zone-261027.osm.pbf` (221 MB, full western zone) and Shortbread MBTiles (z0–14, ODbL, bounds cover western India).
- **Did not** load either file into the running scene.
- PBF full-file Python scan was too slow on this laptop; converter still supports it (`tools/osm_to_game_json.py`).
- Used **25 Dhule z14 tiles** from MBTiles: 320 building footprints, 1 water, 12 POIs merged into `dhule_roads_game.json`. Roads, spawn, jobs unchanged.
- Raw PBF/MBTiles gitignored.
- Sky3D not vendored (MIT, but replaces the sky).

---

## 2026-10-28 — S2 roads: junctions + 6 OSM flyovers

- Addons present, not enabled as the map: Road Generator (MIT editor curves), Terrain3D (C++ heightmap), Orca.
- OSM stays the road geometry. Junction caps added. 6 bridge lines from Dhule tiles drawn as decks + ramps.
- Car physics not changed. Canvas updated: Android + touch pad is the product target; roads still come first.
- Smoke exit 0. F5 still needed to see flyovers.

---

## 2026-10-28 — Car unstuck; Road Generator enabled as editor tool

- Flyover decks had physics and were sitting on the drive line. They are visual only now, and skipped near spawn.
- `addons/road-generator` (MIT, already in the project) enabled for the editor. OSM roads still drive the map.
- Audit note: addon can rebuild meshes at runtime if a `RoadPoint` graph is built in code (no OSM importer). Keep OSM as source of truth; borrow SegGeo/lane UV/`density`/intersection ideas later — do **not** procgen full Dhule on Android startup.
- Did not replace the car with the other GitHub vehicle projects. Those would overwrite the drive that already worked.

---

## 2026-10-29 — Road flicker + props-on-lane fix

- Stalls/bus stops were placed at centerline±8 m (still on asphalt for wide roads). New `_off_carriageway` + half-width-aware `_near_road`; all landmarks/spawn carts pushed to sidewalk; physics stripped.
- Roads: **only** `avenue_street` (main) + `street_road` (sub) kit albedos on a single deck. Removed zebra/wear/dashes/edge lines/mesh tiles that z-fought (yellow on/off flicker + lag). Mesh count ~17k → ~8.6k.
- Smoke PASS.

## 2026-10-29 — Phase 1C–1E: lots, light, landmarks

- 1C: richer courtyards (4 walls + gate, tree, shed, parked stub, bins); ~72 lots + scrub patches; darker ground tint.
- 1D: India afternoon sky (deeper blue / warmer horizon), lower exposure, denser fog, warmer sun.
- 1E: landmarks on 12 delivery anchors (bus stop / shrine / stall / hoarding / tree); second water tower.
- Smoke: `lots~105 landmarks~70` · PASS.

## 2026-10-29 — Drive fix, look orbit, minimap zoom, Indian road textures

- Drive: front axle now at Godot −Z; kit mesh yaw + `_drive_sign` aligned so **W goes away from chase cam**. RMB / drag / touch = 360° look (recenters after ~2 s).
- Minimap: default closer zoom, **+/−** buttons + wheel/pinch, yellow arrow marker at centre (car always centred).
- Floating: stronger AABB ground-snap; tunnel prop removed; rocks normalized.
- Roads: `street_road` + `avenue_street` kit albedos on all OSM strips (street between buildings, avenue on majors). Mesh tiles (`india_street` / `avenue_street`) near spawn. Controls guide in Home → Settings.
- Test: F5 → Esc → click view → W should grow buildings ahead. Map **+** to zoom. Drag RMB to orbit.

## 2026-10-29 — Phase 1B: real facades, kit normalization, Home dashboard

- **Finding:** all 320 OSM footprints came with `h=8`, and the “bhelpuri shop” GLB is a 3 m street **cart**, not a building — it had been scaled up and used as every shop. That is why the street read as rows of identical carts.
- `scripts/building_kit.gd` (new): one ArrayMesh per footprint — floors from plan area, bands, parapet, roof tanks, window grids, balconies, shutters + signboards; `landmark()` for named POIs (hospital / school / temple / bank). Own art, single collision box each.
- `scripts/asset_kit.gd`: `NORMALIZE` table + `normalized()` — every kit mesh lands at real size and faces −Z (bus was 21 cm, Carnival modelled along X, truck 15 m). `tools/probe_kit.gd` prints raw vs normalized AABBs. Bullock cart disabled (95 m bone spike). `avenue.glb` / `sidewalk_tiles.glb` are km-scale dioramas → reference only.
- Ground uses the CC0 `demo/` Ground037 albedo + normal (triplanar). Carts moved to sidewalks; bus/truck/rickshaw parked as street props; richer trees / lamps / stalls in `street_kit.gd`.
- Play: WASD also read via physical keys; game window grabs focus; Home opens on start (G / Esc closes). Default body Carnival; loadout saved to `user://drivevicecity.cfg`.
- Test: F5 → Esc → click view → W. Headless: `godot --headless --path . -s res://tools/smoke_test.gd`.

When you finish a session, append a short dated block here (what changed + how to test).
