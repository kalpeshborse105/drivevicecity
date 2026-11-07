# 79 — Two-neighbourhood chunk manager (Phase 2H.4D)

**Baseline:** `cbe718e` · **Engine:** Godot 4.7.2  
**Manager:** `scripts/dhule_building_chunk_manager.gd`  
**Scene:** `scenes/dev/dhule_two_neighbourhoods_test.tscn`  
**Probe:** `scripts/dev/two_chunk_probe.gd`

## Scope

Stream the **two existing** Dhule building pilots through one reusable manager:

| Chunk ID | Source | Buildings | Geographic origin (approx.) |
|----------|--------|----------:|-------------------------------|
| `pilot_n1` | `docs/qa/64-chunk-pilot-manifest.json` + clearance allow-list | **48** | `(-620.6, 912.7)` |
| `pilot_n2` | `docs/qa/76-chunk2-pilot-manifest.json` + clearance | **41** | `(-160.9, 1698.2)` |

Distance between nests ≈ **910 m**. Chunks stay at original OSM coordinates — not pulled together for convenience.

No new buildings. No city-wide generation. `scenes/main.tscn` and production Blosm untouched.

## Manager behaviour

- Stable string chunk IDs (`pilot_n1`, `pilot_n2`).
- Each def stores geographic `origin`, manifest path, optional clearance allow-list.
- **Load radius** 480 m / **unload radius** 720 m (hysteresis).
- Distance streaming when `auto_stream` and not `manual_lock`.
- Double-load blocked via `_busy` + `is_loaded`.
- Visual root + all `hit_*` / yard `StaticBody3D` freed together on unload (no ghost collision).
- OSM way IDs kept on shell meta / per-body `hit_<id>` names.
- Shared 7 materials via `BuildingShell.shared_materials()` (process-wide cache).
- Meshes built once per load — not rebuilt while the chunk stays loaded.
- Safe fallback: missing manifest / empty specs / shell failure → `chunk_failed`, host discarded.

## Test scene controls

| Key | Action |
|-----|--------|
| C | Aerial follow |
| 1 / 2 | Jump to nest A / B |
| I | OSM ID labels (loaded chunks only) |
| G | Collision debug |
| O | Chunk boundary rings (load radius) |
| B | Blosm compare (cast off) |
| H | Shadow inspect |

## Architecture reuse

- `BuildingShell.add_neighbourhood` for each chunk host  
- `DhuleBuildingStyles` for facade families  
- Clearance JSON from pilots 1 & 2 as the accepted ID sets (exact OSM rings)

See docs 80–81 for collision and performance results.
