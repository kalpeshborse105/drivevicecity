# Dhule OSM building identity pipeline

Partitions `assets/models/environments/dhule_blosm_city.glb` by OSM way id. The production GLB, the road JSON, and the production scenes are not modified.

## Run

```
python D:\drivevicecity\blender_work\dhule_city_pipeline\scripts\partition_buildings.py
```

Blender is not required. The source is already a GLB. The same script also runs under `blender.exe --background --factory-startup --python`.

## Assignment

A triangle is assigned only when every vertex lies in one footprint, or within 0.20 m of that footprint and at least 0.50 m farther from every other footprint. The key is the OSM way id. Names are stored on the manifest and are not used as keys.

Triangles that meet two footprints, or that cross an edge by more than 0.20 m, stay whole in `export/unresolved_geometry.glb`. They are not cut.

## Outputs

| File | Role |
| --- | --- |
| `export/buildings/<OSM_ID>.glb` | Archive. One file per way that received confident triangles. `buildings/.gdignore` keeps Godot from importing these. |
| `export/unresolved_geometry.glb` | Triangles with no confident owner. |
| `export/city_water.glb` | The water primitive, copied unchanged. |
| `export/grouped_joined.glb` | Runtime-shaped mesh: assigned buildings in one node, unresolved in a second node. |
| `export/grouped_by_id.glb` | One node per way id, plus unresolved. Keeps `extras.osm_id`. Much more expensive to draw. |
| `export/neighbourhood_replaced.glb` | Isolated preview. Neighbour shells within 160 m of the court, with three detailed replacements. |
| `export/building_manifest.json` | All 1,866 footprints, including those with zero confident triangles. |
| `export/export_manifest.json` | Triangle totals, reasons, and the source SHA-256. |

Wall and roof materials are shared. The neighbourhood file adds the architecture materials once.

## Preview

`scenes/dev/dhule_city_pipeline_test.tscn` loads the neighbourhood file, the existing car, and road ribbons from the unchanged road JSON. Press C for the aerial camera. The label shows the OSM id under the camera.
