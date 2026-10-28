# 18 — Third-party kit credits (incoming → kit)

Free assets used from `assets/incoming/` → organized into `assets/kit/`.

| File in kit | Credit / source note |
|-------------|----------------------|
| `roads/avenue_street.glb` (+ `_b`) | `road__avenue__street` from incoming — albedo on major OSM roads; 12 m tiles near spawn |
| `roads/street_road.glb` | `street_road.glb` from incoming — albedo on residential / between-building roads |
| `roads/india_street.glb` | India street OSS — ~8 m mesh tiles between buildings near spawn |
| `roads/avenue.glb` / `avenue_hq.glb` | Legacy km-scale dioramas — reference only (not tiled) |
| `sidewalks/sidewalk_8m*.glb` / `sidewalk_tiles.glb` | Sidewalk GLBs from incoming |
| `buildings/bhelpuri_shop.glb` | Bhelpuri shop by Ajay — credit author |
| `props/barriers.glb` | Metal/concrete barriers |
| `props/street_light*.fbx` + `props/street_lights/` | Street Lights Pack 01 (meshes + textures) |
| `props/bullock_cart.glb` | Farmer bullock cart (prop only) |
| `vehicles/carnival.glb` | Kia Carnival GLB (visual only; brand not claimed) |
| `vehicles/tata_safari.glb` | 2021 Tata Safari GLB (visual) |
| `vehicles/autorickshaw.glb` | Low poly autorickshaw |
| `vehicles/bus.glb` | Best bus |
| `vehicles/tata_truck.glb` | Tata Signa cargo truck (garage Truck) |
| `vehicles/camry.glb` | Present but **not** loaded by default (large / Android) |

**Not used in runtime:** Unity packages (`.unitypackage`), Blender/Sketchfab plugin zips, raw `gltf.zip` archives (extract to kit if needed later).

### Real sizes (what the kit meshes actually are)

Measured with `godot --headless --path . -s res://tools/probe_kit.gd`. `scripts/asset_kit.gd` → `NORMALIZE` rescales + re-orients every entry so it lands at this size facing −Z; `AssetKit.normalized(path)` is what the car and the map use.

| Kit file | Raw problem | Normalized |
|----------|-------------|------------|
| `buildings/bhelpuri_shop.glb` | It is a **3 m street cart**, not a building | 2.6 m cart, placed on sidewalks only; buildings now come from `scripts/building_kit.gd` (own art) |
| `vehicles/carnival.glb` | modelled along X | 5.1 m, yaw π |
| `vehicles/tata_safari.glb` | — | 4.7 m, yaw π |
| `vehicles/autorickshaw.glb` | — | 2.9 m, yaw π |
| `vehicles/bus.glb` | 21 cm tall | 11 m, yaw π |
| `vehicles/tata_truck.glb` | 15 m | 12 m, yaw π |
| `props/barriers.glb` | — | 5.9 m |
| `props/bullock_cart.glb` | 95 m armature spike on Y | **disabled** until re-exported without bones |
| `roads/avenue.glb`, `sidewalks/sidewalk_tiles.glb` | ~1 km / 794 m dioramas | reference only (`"tiles"` key aliases `sidewalk_8m.glb`) |

If a vehicle drives backwards in game, flip its `yaw` in `NORMALIZE` (π ↔ 0).

## Terrain3D demo (`demo/assets/`)

Used at runtime for off-road scenery only (OSM strips remain the driveable network):

| Asset | Path | License / credit |
|-------|------|------------------|
| RockA / RockB / RockC | `demo/assets/models/Rock*.glb` | ambientCG **Rock030** — [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) ([ambientCG Rock030](https://ambientcg.com/view?id=Rock030)) |
| Tunnel | `demo/assets/models/Tunnel.glb` | Same Terrain3D demo pack; placed far from spawn, physics stripped (visual prop) |
| Ground037 textures | `demo/assets/textures/ground037_*` | ambientCG **Ground037** — CC0 ([ambientCG Ground037](https://ambientcg.com/view?id=Ground037)); see `demo/assets/textures/asset_licenses.txt` |

## Road Generator demos (`road_demos/`)

Editor/reference only for road mesh generation — **not** used to replace OSM at runtime.

| Asset | Path | Use |
|-------|------|-----|
| Edge barrier CSG | `road_demos/.../edge_barrier.tscn` | Editor demo only (needs Path3D parent) |
| Kit barriers | `assets/kit/props/barriers.glb` | Used as roadside scenery stand-in |

Map roads still follow OpenStreetMap geometry: © OpenStreetMap contributors (ODbL).

## Customization

Press **G**, **Esc** or **Customize** (HUD). Tabs: Home / Vehicles / Paint / Kits / Settings. Loadout saved to `user://drivevicecity.cfg`; default body is the Carnival.

## Own art (no credit needed)

- `scripts/building_kit.gd` — multi-storey Indian facades, landmark variants (hospital / school / temple / bank) on OSM footprints and POIs.
- `scripts/street_kit.gd` — trees (neem / peepal / ashoka), lamps, bus stops, market stalls, water towers, hoardings, dustbin pairs, compound walls with gates, parked-car silhouettes.
