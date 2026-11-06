# Phase 2B.4 — Production spawn test

Godot 4.7.2. Production scene `scenes/main.tscn`. Window 1280×720, Vulkan Forward+, Intel UHD Graphics 620.

The playable spawn is the single `spawn` object in `assets/maps/dhule_roads_game.json`. `scripts/osm_road_builder.gd` reads that object in `_resolve_spawn`. `scripts/game_bootstrap.gd` passes the result to `PlayerCar.set_spawn`. `scenes/main.tscn` does not store a spawn. No second spawn record was added.

`_anchor_from_dict` uses `x`, `z`, `hx`, and `hz`. It does not read a JSON `y`. The builder then lifts the point, and `set_spawn` places the body at y = 0.42 with local +Z along the stored heading. The suspension settles near y = 0.13.

## File changed

`assets/maps/dhule_roads_game.json` — the `spawn` object only. The 796 road ways were not rewritten.

```json
"spawn":{"x":-636.54,"z":881.83,"hx":-0.72,"hz":-0.694,"road":"887431550","highway":"residential"}
```

The `road` string is the OSM way id. The builder stores it and does not move the way. `highway` matches that way: residential, width 7 m, 18 points.

Not modified: `scenes/main.tscn`, `scripts/player_car.gd`, `scripts/osm_road_builder.gd`, `assets/models/environments/dhule_blosm_city.glb`, and `data/dhule/`.

## Measured spawn

| Check | Result |
| --- | --- |
| Map log | `spawn=(-636.5,881.8)`, 796 ways |
| Body position | (−636.54, 0.34, 881.83) before the suspension settled |
| Nose (local +Z) | (−0.720, −0.694) |
| Distance to way `887431550` centre line | 0.0003 m |
| Ground ray | hit at 0.3 m, static ground body |
| Building ray, left / right | 20.3 m / 15.6 m, `dhule_city_osm_buildings_col` |
| Building ray, ahead 25 m | clear |
| OSM shops | 5 |
| Landmarks / flyovers / demo scenery | 0 / 0 / 0 |

Approximate GPS on the driving view: 20.8941°N, 74.7709°E.

The street-kit batch at this spawn is 71 boxes. The same builder, at the old junction, batched 100. Tree and sign sites already reject the carriageway, footprints, and a 12 m circle around the spawn. The new point sits in a built block, so more of those existing sites are rejected. Road geometry and the building mesh are unchanged.

## Drive, reset, and systems

Godot 4.7.2 launched `scenes/main.tscn`. After the map log, the test held accelerate for 6.5 s, steered left and then right, applied the handbrake, then braked.

| Check | Result |
| --- | --- |
| Distance driven | 23.46 m |
| End position | (−654.02, 0.13, 866.19) |
| Body height while moving | 0.01–0.20 |
| End distance to the same centre line | 0.87 m (road width 7 m) |
| Ground ray at the end | hit at 0.1 m |
| Fall through the ground | no |
| R reset | (−636.54, 0.13, 881.83), 0.00 m from the spawn XZ |
| Delivery | “Parcel job @ residential — go to pickup”, 28 anchors |
| HUD | speed, cash, target distance, control hint |
| Minimap | GPS readout, SAT view, car marker |
| Garage | `GaragePanel` was open when the map finished |

The junction view shows the car still on the carriageway, with blocks on both sides and the brake lights on. Side rays of 40 m missed at the stop because that stretch is more open than the spawn; the car remained under a metre from the centre line.

FPS after the map had loaded, sampled on the settled view: 18, 21, and 20.

## Errors

No new GDScript errors.

These messages were already present before this spawn change:

- `project.godot` still autoloads `res://osm_racer/scripts/game_lang.gd`. That folder was removed earlier, so startup reports three load errors. This phase did not edit `project.godot`.
- Four renderer lines: `Parameter "material" is null`.

## Screenshots

- `docs/qa/31-spawn-aerial.png` — car on the curved residential road, blocks on both sides.
- `docs/qa/31-spawn-drive.png` — centre-line view at the spawn. GPS 20.8941°N 74.7709°E. Parcel job estimated ₹175. Target 870 m.
- `docs/qa/31-spawn-junction.png` — same road after the drive. Brake lights on. GPS 20.8942°N 74.7707°E. Parcel job still active.

The garage panel was hidden only inside the temporary capture script so the street stayed visible. That script was deleted. It is not part of the game.

## Addon inventory

Read only. Nothing was enabled, disabled, moved, or edited.

`assets/` contains no `plugin.cfg`. BlenderGIS is a Blender add-on. It is not installed in this Godot project, and it was not changed.

Editor plugins enabled in `project.godot`: Orca, Road Generator, Terrain3D, Godot MCP Toolkit.

| Addon | Version | Godot 4.7.2 | What it does | Use on this project | Enabled | Overhead |
| --- | --- | --- | --- | --- | --- | --- |
| Sky3D | 2.1 | GDScript plugin, no engine pin in `plugin.cfg` | Day and night sky | Environment only if a Sky3D node is placed later. The city does not use it. | No | None while disabled |
| Godot AI | 4.3.1 | Requires Godot 4.7 or newer | Editor MCP and AI tools | Editor help. No map, vehicle, or runtime role while disabled. | No | None while disabled. Enabling it can register a game autoload. |
| Godot MCP Toolkit | 1.1.2 | Godot 4.2+ | Localhost bridge so an assistant can drive the editor | Editor tooling. The drive scene does not use it. | Yes, and autoload `MCPRuntimeServer` | Listens on 127.0.0.1 during play (port 6570 or 6571) |
| Orca | 1.3.0 | Editor plugin, no engine pin in `plugin.cfg` | Editor AI assistant | Editor only | Yes | Editor process only |
| Ziva Installer | 0.2.6 | GDExtension minimum 4.2 | Installs the Ziva editor agent | Editor install helper. `addons/ziva_agent` is a second GDExtension, minimum 4.2, with no `plugin.cfg`. | Plugin off | Both native libraries still load with the project |
| Road Generator | 0.9.5 | Editor plugin, no engine pin in `plugin.cfg` | Editable roads and lane traffic | Production roads stay on `osm_road_builder`. The main scene does not instance this plugin. | Yes | Editor process only |
| Terrain3D | 1.0.2 | GDExtension minimum 4.4 | Editable terrain | The Dhule ground is the flat OSM ground at y = 0. The drive scene does not instance Terrain3D. | Yes | Native library loads at startup |
| TerraBrush | no `plugin.cfg` | GDExtension minimum 4.5 | Terrain brush | Not an enabled editor plugin. Not instanced by the drive scene. | No | Native library loads because the `.gdextension` file is in the project |

None of these add-ons place the Sessions Court buildings or the OSM roads. Leaving them as they are keeps the current map, vehicle, and play path on the existing scripts.
