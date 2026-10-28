# Game kit (where your downloads go)

Downloads in `assets/incoming/` are **copied here** for the game to load:

| Folder | Used for |
|--------|----------|
| `buildings/` | Shop meshes (e.g. bhelpuri) along OSM streets |
| `roads/` | Avenue / India street dress meshes |
| `sidewalks/` | Sidewalk strips |
| `props/` | Lights, barriers, bullock cart |
| `vehicles/` | Garage bodies: Carnival, Safari, rickshaw, bus, truck |

`incoming/` stays as your download drop zone. Runtime paths are `res://assets/kit/...` via `scripts/asset_kit.gd`.

After adding new GLBs: copy into the matching kit folder → open Godot once (import) → Play.
