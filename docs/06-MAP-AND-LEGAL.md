# 06 — Map pipeline & legal

## Rules

1. **Do not** scrape, copy, or ship Google Maps tiles, 3D, or Street View.
2. Google Maps / Earth = **eyes only** (“does this junction exist?”).
3. Production map data = **OpenStreetMap** (ODbL — must credit OSM contributors).
4. Visual meshes/textures = **our Blender work** or clearly free (CC0 / compatible) licenses.
5. Prefer rewriting ideas from open repos; watch **GPL** (can force your game open-source if you copy code).

## Working pipeline (locked)

Google Map Tiles API can show a satellite photo. Enabling the API is free; every tile after that is billed. That photo is optional. It is not the city we ship.

The city we ship:

```
assets/maps/dhule_roads_game.json     real roads and place points
Downloads\dhulemap.osm                OpenStreetMap source clip
        ↓
Blender 4.5 + blosm 2.7.28
  OSM buildings / highways / water only
  Do not use blosm's Google 3D or satellite import
        ↓
assets/maps/dhule_blosm.glb
        ↓
Godot main scene, player car on that mesh
```

blosm is GPL-3. Keep the addon outside the game repo (Downloads or `D:\tools`). Do not copy its Python into `scripts/`. The mesh we export is geometry from OpenStreetMap, so the game still credits OSM.

One district per export. The whole of Dhule is the same step repeated, not one giant first file.

Repeat the first clip:

```powershell
& "D:\tools\blender-4.5.5-windows-x64\blender.exe" --background --factory-startup --python "D:\drivevicecity\tools\export_dhule_blosm.py"
```

That writes `assets/maps/dhule_blosm.glb`. The main scene is `scenes/dhule_blosm.tscn`.

## Credit text (keep for store + in-game About)

> Map data © OpenStreetMap contributors, available under ODbL.  
> https://www.openstreetmap.org/copyright

## Current map

Playable ground is the Blender export of Dhule OpenStreetMap (`assets/maps/dhule_blosm.glb`) in the main scene.  
`scenes/google_drive.tscn` remains the optional paid satellite test. It is not the shipped world.

## Free reference projects (study only)

| Project | Use |
|---------|-----|
| [OSM2World](https://osm2world.org/) | OSM → 3D export |
| [open-street-kart](https://github.com/Picorims/open-street-kart) | Godot + OSM race pattern (MPL-2.0) |
| [godot-openstreetmap](https://github.com/rodzill4/godot-openstreetmap/) | Ideas only (older) |

Check each license before copying code into this MIT project.
