# Phase 2B.5 — BlenderGIS and Dhule pipeline audit

Godot 4.7.2. Blender 5.2.3 at `D:\Blender Foundation\Blender 5.2\blender.exe`. No production spawn, road, scene, or Blosm file was edited. Nothing was committed.

## 1. What the running game actually loaded

The production scene is `scenes/main.tscn` (`project.godot` `run/main_scene`). `DhuleMap` uses `scripts/osm_road_builder.gd` and does not override `map_json_path`. That export defaults to `res://assets/maps/dhule_roads_game.json`.

The spawn object on disk is still the Sessions Court record:

```json
{"x": -636.54, "z": 881.83, "hx": -0.72, "hz": -0.694, "road": "887431550", "highway": "residential"}
```

There is one `spawn` key. `scenes/main.tscn` places `PlayerCar` at (0, 0.55, 0) until `map_ready`. `game_bootstrap.gd` then calls `set_spawn` with the JSON point. No other spawn override is wired to the production scene.

The Phase 2B.4 launch was Godot 4.7.2 console, Vulkan, Intel UHD 620, `--path D:\drivevicecity`, scripted load of `res://scenes/main.tscn`. Its log line was `spawn=(-636.5,881.8)`. No Godot process was running when this audit started. Blender 5.2.3 was open from `D:\Blender Foundation\Blender 5.2\blender.exe`.

### GPS

`scripts/minimap.gd` writes the minimap header from the car position:

```text
lat = 20.902 - (z / 111320)
lon = 74.777 + (x / (111320 * cos(20.902°)))
```

For the spawn (−636.54, 881.83) that is 20.8941°N, 74.7709°E. The saved driving screenshot says that. The frame after the short drive says 20.8942°N, 74.7707°E. Crops: `docs/qa/31-spawn-drive-gps.png` and `docs/qa/31-spawn-junction-gps.png`.

20.9024°N, 74.7786°E is a different point. The same formula puts it near Godot (166, −45), about 170 m from the map origin and about 1.2 km from the Sessions Court spawn. The label’s first text, before a car exists, is the origin itself: `20.9020°N 74.7770°E`. The scene-file car at (0, 0.55, 0) produces that origin pair until the map finishes and `set_spawn` runs.

The minimap also draws hardcoded pins, including one named “Dhule Court” at (−240, −120). Those pins are not the GPS readout and they are not the OSM court.

## 2. Installed BlenderGIS

| Item | Value |
| --- | --- |
| Folder | `%APPDATA%\Blender Foundation\Blender\5.2\scripts\addons\BlenderGIS-2215` |
| `bl_info` version | 2.2.14 |
| Declared Blender minimum | 2.83.0 |
| Version gate | Raises if `bpy.app.version[0] > 5`, so Blender 6 is refused and 5.2.3 is allowed through |
| GDAL / PyProj / Pillow | Not installed |
| ImageIO FreeImage | Present inside the addon |

The addon runs in the interactive Blender window. `C:\Users\Admin\.bgis\bgis.log` shows sessions on 6 Nov 2026 that called `view3d.map_start` and requested `http://mt0.google.com/vt/lyrs=s` tiles. Those tiles must stay out of this project.

A background enable does not work. `addon_utils.enable("BlenderGIS-2215")` under Blender 5.2.3 `--factory-startup` dies in `prefs.py` while reading `preferences.addons["BlenderGIS-2215"]` during `register()` (`KeyError`). Operators are not available to a headless script after that failure. The window path is the one that works. This audit did not enable or disable the addon in the open Blender.

### Operators that exist in the source

Import: `importgis.osm_file`, `importgis.osm_query`, `importgis.georaster`, `importgis.asc_file`, `importgis.shapefile`, `importgis.dem_query`.

Export: `exportgis.shapefile` only. There is no BlenderGIS GLB exporter. Godot GLB is Blender’s `export_scene.gltf`.

Scene: `geoscene.set_crs`, `geoscene.init_org`, `geoscene.edit_org_geo`, `geoscene.edit_org_prj`.

Web: `view3d.map_start`, `view3d.map_viewer`, `view3d.map_search`.

Mesh and terrain: `tesselation.delaunay`, `tesselation.voronoi`, `earth.sphere`, `earth.curvature`, `object.drop`, `analysis.nodes`, plus the `reclass.*` node tools.

### What those operators can and cannot do here

OSM buildings: `importgis.osm_file` reads a local `.osm`. Closed `building` ways become polygons. `buildingsExtrusion` defaults to on, with a 20 m default height and a random threshold, which invents heights when OSM has none. `separate` defaults to off. The OSM id is stored on the object only when `separate` is on (`obj["id"]`).

If the scene has no CRS, the file importer chooses a UTM EPSG from the file centre and sets the origin there. Without GDAL or PyProj, reprojection is the built-in WGS84 ↔ UTM / Web Mercator path, or a network EPSG lookup. A custom equirectangular CRS that matches 111320 m/degree cannot be applied reliably. UTM metres will not sit on the Godot roads.

DEM: `importgis.dem_query` is labeled “Get elevation (SRTM)”. It needs an already georeferenced scene, an orthographic top view or a selected mesh, and it downloads a GeoTIFF from OpenTopography. The default servers are SRTM 30 m and 90 m. Both require an OpenTopography API key. NASA SRTM is a permitted elevation source. This phase did not download it. `importgis.georaster` can load a GeoTIFF already on disk, with mode `DEM`, subdivision `subsurf`, and optional interpolation. Terrain node tools (`analysis.nodes`, `reclass.*`) classify an existing terrain. They do not create Dhule elevation by themselves.

Basemap textures: `view3d.map_start` serves Google satellite and map, OSM Mapnik, Bing, and Esri. Google, Bing, and the other commercial image layers are not inputs for this game.

CRS presets in `prefs.py`: EPSG:3857 Web Mercator, and EPSG:4326 with a note that lat/lon must not be the scene CRS.

## 3. Test pipeline that was actually run

`blender_work/dhule_gis_test/build_sessions_court_test.py` does not call BlenderGIS. It uses the game projection on the local files, because that is the path that lines up with the spawn.

Window, Godot metres: X −820 to −420, Z 680 to 1080.

Result, from `sessions_court_manifest.json`:

- 88 flat footprints, 0 extruded
- 1 named landmark empty (way `482794524`, Dhule District & Sessions Court, is in the footprint set)
- 17 road ribbons copied from the existing JSON, including way `887431550`
- flat ground plane, no DEM
- 10 kit meshes in `IndianCityKit`, at Blender X = 2500, not on the court

Outputs:

- `blender_work/dhule_gis_test/sessions_court_test.blend`
- `blender_work/dhule_gis_test/export/sessions_court_reference.glb`
- `blender_work/dhule_gis_test/export/indian_city_kit.glb`

The reference GLB is for inspection. It is not a replacement for `dhule_blosm_city.glb`. Footprints are outlines of the same OSM ways, not a second solid city.

`import_licensed_dem.py` only prints the manual DEM steps. Exact UI steps are in `blender_work/dhule_gis_test/README.md`.

## 4. Kit

The kit GLB contains: single-storey house, two-storey house, kirana shop, commercial building, compound wall, gate, rooftop water tank, balcony, door, window. Each object is marked as a reusable visual. None of them were added to `scenes/main.tscn` or to the Blosm mesh.

## 5. Dependency audit

Nothing was deleted.

### Production path

`scenes/main.tscn` → `scripts/game_bootstrap.gd`, `scripts/osm_road_builder.gd`, `scenes/player_car.tscn` / `scripts/player_car.gd`, `scripts/hud.gd`, `scripts/minimap.gd`, `scripts/garage_ui.gd`, `scripts/delivery_mission.gd`, `scripts/asset_kit.gd`.

Map data: `assets/maps/dhule_roads_game.json`, `assets/models/environments/dhule_blosm_city.glb`, `data/dhule/city_shops.json` (five named OSM shops). When the Blosm file exists, the builder skips sidewalks, kerbs, invented landmarks, flyovers, demo scenery, and random speed breakers. It still places the five OSM shops and a reduced tree and lamp pass.

Autoloads: `GameSettings`, `MCPRuntimeServer`. `GameLang` still points at `res://osm_racer/scripts/game_lang.gd`. That file is not on disk. The 2B.4 log reported the failed autoload. This phase left `project.godot` alone.

### Duplicate or idle generators

| Piece | Role now |
| --- | --- |
| `scripts/osm_road_builder.gd` | Production roads and the Blosm instance |
| `scripts/mumbai_city_builder.gd`, `scenes/mumbai_playable_test.tscn`, `scenes/mumbai_city_test.tscn`, `assets/maps/mumbai_fort_roads_game.json` | Separate city test |
| `scripts/dhule_block_builder.gd` | Procedural block, not the production scene |
| `scripts/dev/dhule_block_drive_test.gd`, `scenes/dev/dhule_block_drive_test.tscn` | 60-building drive test |
| `scripts/street_kit.gd`, `scripts/streetscape_kit.gd`, `scripts/building_kit.gd`, `scripts/roadside_props_kit.gd` | Procedural streets and shopfronts. Landmark and heavy dress paths return early while the Blosm mesh is present |
| `addons/road-generator` | Editor road tool. Enabled. Not instanced by `main.tscn` |
| `scenes/google_drive.tscn`, `scripts/google_map_drive.gd` | Separate Google-tiles drive. Not the production scene |
| `scenes/dhule_blosm.tscn` | Mesh viewer, not the game |
| `scenes/city_map_free_test.tscn`, `demo/assets/scenes/PrimitivesCity.tscn`, `demo/assets/scenes/BuildingBlocks.tscn` | Old demos |
| `osm_racer/` | Removed from disk. The autoload line remains |

### Duplicate files

- `assets/kit/buildings/bhelpuri_shop.glb` and `assets/models/buildings/shops/bhelpuri_shop.glb`
- `assets/maps/dhule_roads_game_bak.json` and `assets/maps/dhule_roads_game_pre_new_map.json` beside the live road file
- `assets/incoming/vfx_patch_review/scripts/` copies of `minimap.gd`, `game_bootstrap.gd`, and `vfx_environment_controller.gd`

### Addons

The Godot addon inventory from `docs/31-PHASE2B4-SPAWN-TEST-REPORT.md` still applies. Enabled editor plugins: Orca, Road Generator, Terrain3D, Godot MCP Toolkit. Sky3D, Godot AI, and Ziva Installer are present and not enabled. TerraBrush and the Ziva GDExtensions still load as native libraries. None of them were switched.

## Cleanup proposal

Do this in a later pass, after a play test, and do not do it as part of the GIS experiment.

1. Remove the `GameLang` autoload only together with a startup test, because the missing script already prints three errors.
2. Keep `osm_road_builder.gd`, the Blosm GLB, the live road JSON, and the five-shop file.
3. Archive, rather than delete in place, the Mumbai scenes, the block-drive test, `google_drive.tscn`, and the demo city scenes once nothing references them.
4. Leave Road Generator, Terrain3D, and TerraBrush disabled for the production play path until a phase actually instances them. Do not flip them in `project.godot` until that phase.
5. Keep one bhelpuri GLB and one road-JSON backup. Drop the extra copies only after checking `asset_kit.gd` paths.
6. Do not import BlenderGIS basemap tiles, and do not extrude a second building mesh over the Blosm city.
