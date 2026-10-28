# 19 — Cesium / Scenario (what we use, what we do not)

DriveViceCity stays on **Godot 4** + **OpenStreetMap** for the playable Dhule map.

## Cesium for Unreal / Cesium for Unity

**Not installed.** Those repos target Unreal and Unity. This project is Godot — their plugins cannot be dropped into `D:\drivevicecity`.

## 3D Tiles for Godot (Battle Road / Cesium Native)

There is a Godot plugin (“3D Tiles for Godot”) that streams Cesium ion / often **Google Photorealistic 3D Tiles**.

**We do not enable it for production play** because:

1. Project legal rule: never fetch/ship Google Maps / Earth / 3D / Street View into the game.
2. Globe-scale streaming fights our locked Phase 1 design: local OSM roads + own/kit art, mobile-friendly Android later.
3. Needs Cesium ion account + network at runtime; unstable for a free-roam delivery loop on mid-range PCs.

Google Maps / Earth remain **eyes-only** reference. Layout + names = OSM (`assets/maps/dhule_roads_game.json`).

## Scenario Labs skills (game-art / textures / skyboxes / 3D)

Useful later for **own art** (seamless asphalt, skyboxes, props) if you have a Scenario account. Skills are not wired into this repo yet.

Optional Phase 1 polish (manual): generate tileable road/ground/sky with Scenario → drop PNGs into `assets/kit/` → register in `scripts/asset_kit.gd`. Do **not** replace OSM geometry with AI city meshes that copy real Google/GTA layouts.

## What we use instead (current)

| Need | Source |
|------|--------|
| Roads | OSM ways + kit albedos `avenue_street` / `street_road` |
| Buildings | `scripts/building_kit.gd` (own) |
| Props / vehicles | `assets/kit/` free licensed GLB/FBX |
| Ground / sky | CC0 demo textures + procedural sky in `main.tscn` |
