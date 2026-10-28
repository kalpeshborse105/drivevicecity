# 06 — Map pipeline & legal

## Rules

1. **Do not** scrape, copy, or ship Google Maps tiles, 3D, or Street View.
2. Google Maps / Earth = **eyes only** (“does this junction exist?”).
3. Production map data = **OpenStreetMap** (ODbL — must credit OSM contributors).
4. Visual meshes/textures = **our Blender work** or clearly free (CC0 / compatible) licenses.
5. Prefer rewriting ideas from open repos; watch **GPL** (can force your game open-source if you copy code).

## Planned free pipeline (P1)

```
OpenStreetMap (Dhule clip)
        ↓
Geofabrik India extract / Overpass
        ↓
OSM2World  →  glTF / OBJ   (or Blender OSM add-on)
        ↓
Clean in Blender (Indian shop kits, landmarks)
        ↓
Import to Godot → res://assets/maps/dhule_...
        ↓
Replace dhule_block_builder.gd procedural grid
```

## Credit text (keep for store + in-game About)

> Map data © OpenStreetMap contributors, available under ODbL.  
> https://www.openstreetmap.org/copyright

## Current map (P0)

`scripts/dhule_block_builder.gd` builds a **fake grid** with Dhule-flavored landmark *names*.  
It is **not** real geography. Good for driving feel only.

## Free reference projects (study only)

| Project | Use |
|---------|-----|
| [OSM2World](https://osm2world.org/) | OSM → 3D export |
| [open-street-kart](https://github.com/Picorims/open-street-kart) | Godot + OSM race pattern (MPL-2.0) |
| [godot-openstreetmap](https://github.com/rodzill4/godot-openstreetmap/) | Ideas only (older) |

Check each license before copying code into this MIT project.
