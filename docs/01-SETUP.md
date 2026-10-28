# 01 — Setup

## Tools (all free)

| Tool | Why | Install |
|------|-----|---------|
| **Godot 4.7+** | Game engine | `winget install GodotEngine.GodotEngine` |
| **Cursor / VS Code** | Code + docs | Already open on `D:\drivevicecity` |
| **Git** (optional) | Version history | Comes with many Windows setups |
| **Blender** (later) | Custom 3D map/vehicles | https://www.blender.org (when we leave procedural map) |

## Open in Cursor (IDE)

1. **File → Open Folder** → `D:\drivevicecity`
2. You should see `project.godot`, `scenes/`, `scripts/`, `docs/`
3. Edit `.gd` scripts and docs here; scenes are easier in Godot

## Open in Godot

1. Start **Godot Engine 4.7**
2. **Import** → browse to `D:\drivevicecity\project.godot` → Import & Edit  
   (or from terminal:)
   ```powershell
   & "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" --path "D:\drivevicecity"
   ```
3. Main scene is already set: `res://scenes/main.tscn`

## One-time checks

- [ ] Godot opens project with no red errors in bottom panel
- [ ] `scripts/player_car.gd`, `dhule_block_builder.gd`, `hud.gd` show in FileSystem
- [ ] Cursor workspace root is `D:\drivevicecity` (not `D:\` alone)

## Do not install / pay for (v1)

- Google Maps SDK / Mapbox paid tiers / paid city asset packs  
- Paid car packs (we build or use free CC0 later)
