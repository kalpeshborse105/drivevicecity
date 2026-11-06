# DriveViceCity — Phase 1C: Codebase health and push

Date: 6 Nov 2026.

## 1. Git status

Before this commit, `main` was `6ba7e8c` (`v4`) and matched `origin/main`. There were no unpushed local commits and no remote commits missing locally.

The working tree already held unrelated edits: map scripts, `scenes/main.tscn`, `project.godot`, `assets/maps/dhule_roads_game.json`, docs 04, 06, 13, and INDEX, the Ziva addon, and `assets/maps/ATTRIBUTION.txt`. Untracked work included `osm_racer/`, Blosm exports, `dhulemap.osm`, the Google drive scene, and the Godot MCP addon. None of that was discarded.

After the geographic commit, those same local edits are still unstaged. `main` is ahead of `origin/main` by this data commit until the push in this phase.

## 2. Files committed

Commit `8c51508164659f25cc8c3ba98156a7d5848b7644` on `main`:

`feat(map): complete Dhule canonical geographic data`

- `.gitignore`
- `data/dhule/roads.geojson` (799)
- `data/dhule/buildings.geojson` (254)
- `data/dhule/waterways.geojson` (2)
- `data/dhule/natural.geojson` (1)
- `data/dhule/landuse.geojson` (4)
- `data/dhule/leisure.geojson` (6)
- `data/dhule/railway.geojson` (1)
- `data/dhule/amenities.geojson` (3)
- `data/dhule/places.geojson` (81)
- `data/dhule/route_relations.json` (4 relations, 5,565 members)
- `data/dhule/boundaries.geojson` (2, geometry null)
- `data/dhule/manifest.json`
- `docs/25-GEOJSON-EXPORT-VALIDATION.md`
- `docs/26-DHULE-GEOGRAPHIC-DATA-LAYERS.md`
- `tools/export_dhule_geojson.py`
- `tools/export_dhule_layers.py`

This health report is committed after that SHA so the hash above can be written down. No `git add .` was used.

## 3. Commit and GitHub

- Data commit: `8c51508164659f25cc8c3ba98156a7d5848b7644`
- URL: https://github.com/kalpeshborse105/drivevicecity/commit/8c51508164659f25cc8c3ba98156a7d5848b7644
- Branch pushed: `main`, fast-forward only, no force push

## 4. Tests actually run

| Check | Result |
| --- | --- |
| `python -m py_compile` on both exporters | Pass |
| Syntax parse of all 11 files in `tools/*.py` | Pass |
| Manifest filenames and feature counts against the files on disk | Pass. Boundary geometries are both null. Route file has 4 relations and 5,565 members. License is ODbL-1.0. `source_timestamp` is null. `latest_element_timestamp` is `2026-11-05T08:21:22Z`. `export_date` is `2026-11-06`. |
| Godot 4.7.2 `--headless --path D:\drivevicecity --import --quit` | Did not pass. The process exited with code `-1073740940` while reimporting assets. Before that it printed pre-existing UID duplicate warnings between `assets/models/buildings/shops/` and `assets/kit/buildings/`. |
| `tools/dhule_live_smoke.gd` | Not run. It requires `main_scene` to be `res://osm_racer/scenes/title_screen.tscn` and then downloads OSM. The playable boot scene is `res://scenes/main.tscn`. |
| `tools/google_map_smoke.gd` | Not run. It loads the untracked Google drive scene and calls the Map Tiles API. |

The earlier Phase 1A and 1B checks still stand: way and node ids, raw tags, and coordinates matched `dhulemap.osm`, and Shapely accepted the written geometries. Those checks were not repeated in full during this pass.

## 5. Cleanup that was applied

No files were deleted.

`.gitignore` now also ignores:

- `google key.txt` and `*api*key*.txt`
- zip archives under `assets/incoming/`, including the two 150.71 MB `gltf.zip` copies
- `assets/incoming/old_city.glb` (266.63 MB)
- `*.blend1`
- `.mcp.json`
- `__pycache__/` and `*.pyc`

`*.osm.pbf` and `*.mbtiles` were already ignored. That covers `western-zone-261027.osm.pbf` (211.44 MB) and `western-zone-shortbread-1.0.mbtiles` (496.79 MB).

## 6. Files intentionally preserved

Left on disk and out of this commit:

- `osm_racer/`. It is a separate prototype. Uncommitted `project.godot` autoloads `osm_racer/scripts/game_lang.gd`. The committed boot scene remains `scenes/main.tscn`. Smoke tools also reference the racer. It was not deleted.
- Blosm outputs: `assets/maps/dhule_blosm.glb`, `assets/models/environments/dhule_blosm_city.blend`, `dhule_blosm_city.glb`, and `scenes/dhule_blosm.tscn`.
- `assets/maps/dhulemap.osm`, the source the exporters read.
- `assets/maps/dhule_roads_game.json` and its local backups.
- Playable scripts, `scenes/main.tscn`, and `project.godot` local edits.
- `assets/models/props/dhule_chowk_statue.glb`.
- `scenes/google_drive.tscn` and `scripts/google_map_drive.gd`.
- Older converters `tools/convert_dhulemap_osm.py`, `tools/osm_to_game_json.py`, `tools/mbtiles_dhule_merge.py`, and `tools/enrich_dhule_map.py`. The two new exporters write different files. The older scripts still feed the playable JSON, so they stay.
- Tracked vehicle meshes, including both copies of the Camry GLB.

## 7. Cleanup candidates

Not deleted:

- Duplicate shop import: Godot reported the same UIDs for `assets/models/buildings/shops/bhelpuri_shop*` and `assets/kit/buildings/bhelpuri_shop*`.
- Duplicate tracked vehicle binaries: `assets/incoming/2025_toyota_camry_xv80_hybrid.glb` and `assets/kit/vehicles/camry.glb` are each 53.10 MB. Safari and Carnival also exist under both `assets/incoming/` and `assets/kit/vehicles/`.
- `assets/incoming/mumbai_city.glb` at 44.92 MB, already tracked.
- `assets/maps/dhule_roads_game_bak.json` and `assets/maps/dhule_roads_game_pre_new_map.json`.
- Ziva working-tree edits, including changed binaries and removed dependency DLLs under `addons/ziva_agent/`.
- `addons/godot_mcp_toolkit/`, untracked.
- `docs/INDEX.md` and `assets/maps/ATTRIBUTION.txt` have local edits and were not updated to link docs 25–27.
- `assets/models/environments/dhule_blosm_city.blend1` remains on disk and is now ignored.

## 8. Large files and gitignore

Ignored and not pushed: the 150.71 MB zip pair, `old_city.glb`, the PBF, and the MBTiles file.

Already on `main` from earlier commits, under GitHub’s 100 MB hard limit and above or near the 50 MB warning:

| Tracked file | Size |
| --- | ---: |
| `assets/kit/vehicles/camry.glb` | 53.10 MB |
| `assets/incoming/2025_toyota_camry_xv80_hybrid.glb` | 53.10 MB |
| `assets/incoming/mumbai_city.glb` | 44.92 MB |

This phase did not rewrite history to remove them.

## 9. Security and licensing

`google key.txt` is ignored. It was not staged and its value is not recorded here. No `.env` file was part of the commit. `.mcp.json` is local editor config and is now ignored.

Geographic layers carry `© OpenStreetMap contributors` and ODbL-1.0. The Blosm addon is not in the repo. Licenses for the tracked vehicle GLBs were not reviewed in this pass.

Boundary geometry is still null because the outer ways are absent from `dhulemap.osm`. Route member references are retained. The exporters do not write `dhule_roads_game.json`, `scenes/main.tscn`, or the vehicle scripts. `export_dhule_layers.py` only reads the existing road and building GeoJSON to copy their feature counts into the manifest.

## 10. Playable gameplay

This commit does not change vehicle physics, road building, missions, HUD, `scenes/main.tscn`, or `project.godot`. Those files still have separate uncommitted edits in the working tree. The playable JSON was not replaced with GeoJSON.

No Blender, 3D generation, or Godot integration was started.
