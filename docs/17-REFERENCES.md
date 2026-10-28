# 17 — Saved references (legal + later use)

## Map data (Phase 1 — use OSM)

| Source | URL | Notes |
|--------|-----|--------|
| Geofabrik India Western Zone | https://download.geofabrik.de/asia/india/western-zone.html | Local files (gitignored): `western-zone-261027.osm.pbf`, `western-zone-shortbread-1.0.mbtiles`. Playable map uses a **Dhule clip only**. ODbL. |
| Sky3D (optional) | https://github.com/TokisanGames/Sky3D | MIT day/night addon. **Not installed** this pass — it replaces WorldEnvironment and can change driving readability. |
| OSM copyright | https://www.openstreetmap.org/copyright | Always credit © OpenStreetMap contributors |

**Google Maps:** eyes-only. Never scrape tiles/3D/Street View into the game.

## Godot tools

| Tool | URL | Notes |
|------|-----|--------|
| Godot Asset Store | https://store.godotengine.org/ | Prefer MIT/compatible free assets |
| Orca AI for Godot | https://store.godotengine.org/asset/cold-atom/orca-ai-agent-for-godot/ | Local zip: `C:\Users\Admin\Downloads\orca-v1.3.0.zip` — optional editor helper; MIT; needs Godot 4.7.2 |

## Vehicles (Phase 2 only — do not import yet)

Browse: https://sketchfab.com/3d-models

| Model | URL | Licence caution |
|-------|-----|-----------------|
| 2015 Dodge Challenger LB | https://sketchfab.com/3d-models/2015-dodge-challenger-lbperformance-db846e9b985e4ae4934a5d9b6d1683f2 | Often **CC-BY-NC-SA** + may be based on game IP — **not** for commercial Play Store without clear rights |
| 1996 Roush Mustang | https://sketchfab.com/3d-models/1996-jack-roush-edition-ford-mustang-gt-71e33d42df9143919b554161a5963aca | Same NC / game-based risk |
| 2009 Audi RS6 | https://sketchfab.com/3d-models/2009-audi-rs6-63719bba5217434c94fed1ee7a985142 | Same — verify licence before any download |

Prefer **own Blender** Indian cars (Swift-like / Innova-like / van) for commercial release.

## Not for this Godot project

| Tool | URL | Why |
|------|-----|-----|
| Cesium for Unreal | https://cesium.com/platform/cesium-for-unreal/ | Unreal-only; needs approval to change engine |
| cesium-unreal GitHub | https://github.com/CesiumGS/cesium-unreal | Same |

## How you download a Sketchfab model (when we start Phase 2)

1. Open the model page → check **Download** is available to you.  
2. Read **Licence** (CC0 / CC-BY OK for many games; **NC** = no commercial Play Store).  
3. Download **glTF / GLB** if offered.  
4. Put file in `D:\drivevicecity\assets\vehicles\incoming\` and tell the agent the path.  
5. Do **not** download models that say “from Forza / NFS / CSR” for a commercial app unless you own rights.

## Blender

https://www.blender.org/ — for own Phase 2 hero meshes.
