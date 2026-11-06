# Dhule building replacement test

The production file `assets/models/environments/dhule_blosm_city.glb` is not modified.

`build_replacement.py` reads that file, deletes only the triangles whose centroids fall inside three OSM footprints, and writes a separate GLB with the detailed models in those footprints.

```
"D:\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python "D:\drivevicecity\blender_work\dhule_building_replacement\build_replacement.py"
```

Open `scenes/dev/dhule_building_replacement_test.tscn` in Godot. WASD drives the existing car. C toggles the aerial camera. The HUD shows the OSM id hit by a ray from the camera, ignoring the ground.

The report is `docs/34-DHULE-BUILDING-REPLACEMENT-REPORT.md`.
