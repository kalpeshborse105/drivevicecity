"""Optional DEM import. Does not download anything.

Place a GeoTIFF you are allowed to use at:

    blender_work/dhule_gis_test/dem/dhule_srtm.tif

NASA SRTM, redistributed by OpenTopography, is the source BlenderGIS
already knows. It needs a free OpenTopography API key. This script does
not call that service.

BlenderGIS 2.2.14 cannot be enabled from a background Blender 5.2.3
process (prefs.py looks up the addon key during register and raises
KeyError). Import the raster from the Blender window instead.
"""

from pathlib import Path

DEM = Path(r"D:\drivevicecity\blender_work\dhule_gis_test\dem\dhule_srtm.tif")

print("DEM_PRESENT", DEM.exists(), DEM)
print("HEADLESS_IMPORT", "not available")
print("UI_STEPS")
print("1. Enable BlenderGIS in Edit > Preferences > Add-ons. Do not use a background enable.")
print("2. Open sessions_court_test.blend.")
print("3. Do not use GIS > Web geodata > Basemap. That menu can request Google and Bing tiles.")
print("4. If you already downloaded an SRTM GeoTIFF, use GIS > Import > Georeferenced raster.")
print("5. Set the raster mode to DEM. Keep the scene origin at longitude 74.777, latitude 20.902.")
print("6. Put the result in the Terrain collection. Do not replace dhule_blosm_city.glb.")
