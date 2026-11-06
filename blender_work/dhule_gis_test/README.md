# Dhule GIS test

This folder is a Blender inspection scene for the Sessions Court neighbourhood. It is not the production city.

The production buildings stay in `assets/models/environments/dhule_blosm_city.glb`. The production roads stay in `assets/maps/dhule_roads_game.json`. Nothing here replaces either file.

## Origin

- Latitude 20.902, longitude 74.777
- Blender X east, Y north, Z up
- After glTF export, Godot reads that as X east, Y up, Z south
- Metres: 111320 per degree of latitude, and 111320 × cos(20.902°) per degree of longitude

That is the same projection as the game JSON. BlenderGIS’s default UTM zone does not match it.

## What was built

`build_sessions_court_test.py` reads the local OSM and the road JSON. It keeps footprints whose centre sits in Godot X −820…−420 and Z 680…1080. Footprints are flat. They are not extruded, so they are not a second set of buildings.

| Output | Contents |
| --- | --- |
| `sessions_court_test.blend` | Collections `OSM_Footprints`, `OSM_Roads`, `OSM_Landmarks`, `Terrain`, `IndianCityKit` |
| `export/sessions_court_reference.glb` | Footprints, road ribbons, named empties, and a flat ground plane |
| `export/indian_city_kit.glb` | Reusable kit shapes, parked at Blender X = 2500, away from the court |
| `sessions_court_manifest.json` | Counts from the last build |

Way `482794524` is the Dhule District & Sessions Court footprint. Way `887431550` is the spawn road. OSM way ids are stored on the objects. Node ids inside `dhule_city.osm` were renumbered when that file was written, so only the way id is the OSM id.

The ground plane is flat at height 0. No DEM was downloaded.

Rebuild:

```
"D:\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python "D:\drivevicecity\blender_work\dhule_gis_test\build_sessions_court_test.py"
```

## BlenderGIS in the Blender window

Installed copy: `C:\Users\Admin\AppData\Roaming\Blender Foundation\Blender\5.2\scripts\addons\BlenderGIS-2215`

Version in `bl_info`: 2.2.14. The version gate refuses Blender 6 and later. Blender 5.2.3 gets past that gate. GDAL, PyProj, and Pillow are not installed, so reprojection is limited to WGS84, UTM, and Web Mercator.

A background `addon_utils.enable("BlenderGIS-2215")` fails. `prefs.py` reads `preferences.addons["BlenderGIS-2215"]` during `register()` and raises `KeyError`. Use the addon from the Blender window, where it is already enabled.

Do not use **GIS > Web geodata > Basemap**. That operator (`view3d.map_start`) can request `mt0.google.com` satellite tiles, and the current Blender log shows it already did. Do not copy those tiles into this project.

Manual OSM import, if you want to compare it with this test scene:

1. Open `sessions_court_test.blend`.
2. Leave the existing collections untouched.
3. Create a new collection named `BlenderGIS_Compare`.
4. Before importing, set the scene CRS and origin yourself. GIS > set CRS (`geoscene.set_crs`) only offers the saved presets. The presets are Web Mercator and WGS84 lat/lon. WGS84 is marked as unsuitable as a scene CRS. There is no preset for the game’s 111320-metre projection.
5. **GIS > Import > Open Street Map xml (.osm)** runs `importgis.osm_file`. If the scene has no CRS, the operator picks a UTM zone from the file centre and puts the origin on that centre. That will not line up with the Godot spawn.
6. In the file dialog, turn **Buildings extrusion** off. The default is on, with a 20 m height and a random-height threshold. That would invent building heights.
7. Turn **Separate objects** on if you need the OSM id. The id is written to the object property `id` only in that mode.

Manual elevation, only with a file you are allowed to use:

1. Register at OpenTopography and request an API key. The addon’s DEM operator (`importgis.dem_query`) downloads NASA SRTM 30 m or 90 m from OpenTopography. It opens a dialog and refuses to run without a key.
2. Or save a GeoTIFF as `dem/dhule_srtm.tif` and use **GIS > Import > Georeferenced raster** (`importgis.georaster`), mode DEM.
3. Put the mesh in `Terrain`. Do not export it over the Blosm city.

`import_licensed_dem.py` only prints those steps. It does not download a DEM.

Godot GLB export is Blender’s own glTF exporter, `bpy.ops.export_scene.gltf`. BlenderGIS exports a shapefile (`exportgis.shapefile`) and does not write GLB.

## Kit

`IndianCityKit` holds a single-storey house, a two-storey house, a kirana shop, a commercial block, a compound wall, a gate, a rooftop tank, a balcony, a door, and a window. They are reusable shapes. They are not placed on a real footprint, and they are not in the production scene.
