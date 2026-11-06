# Dhule architecture prototype

Separate from the production city. The Blosm mesh at `assets/models/environments/dhule_blosm_city.glb` is unchanged.

## Build

```
"D:\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python "D:\drivevicecity\blender_work\dhule_architecture\build_architecture.py"
```

`build_architecture.py` reads `assets/maps/dhule_city.osm` and `assets/maps/dhule_roads_game.json`. It keeps the game origin (20.902 N, 74.777 E, X east, Z south).

## Outputs

- `architecture_source.blend` — source scene
- `export/dhule_architecture_test.glb` — the Sessions Court prototype, with hidden collision prisms named `col_<osm id>`
- `reusable_assets/` — house, shop, and component meshes. These are not placed on OSM footprints
- `building_metadata.json`
- `validation.csv`

The Godot preview is `scenes/dev/dhule_architecture_test.tscn`. It instances `scenes/player_car.tscn` and does not use `scenes/main.tscn`. WASD drives. C toggles the aerial camera. The test report is `docs/33-DHULE-ARCHITECTURE-PROTOTYPE.md`.

Way `482794524` is a four-corner outline of about 17,178 m². A solid fill would cover the courtyard, so the mesh is a 14 m wing around that outline and the interior stays open. Height is estimated. The twelve smaller footprints are `building=yes` with no shop tag and no height tag.

None of the five OSM shops fall in this block. The kirana and commercial meshes stay in the library at Godot X = 4500.
