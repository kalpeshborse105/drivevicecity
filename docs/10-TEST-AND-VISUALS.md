# 10 — Testing + original visuals

## Automated smoke test

```powershell
$g = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
& $g --path "D:\drivevicecity" --headless -s res://tools/smoke_test.gd
```

Expect: `SMOKE_TEST_RESULT=PASS`

Checks:

- OSM game JSON (roads, core spawn, headings, anchors)
- Original sedan/van mesh builders
- Input actions present

## Manual playtest

1. **F5** in Godot  
2. Confirm **original sedan** (hood/cabin/lights/glass) on blue SPAWN pad, facing road  
3. Yellow arrow + minimap (top-right) + distance HUD  
4. Drive into job zone → complete delivery  
5. **P** / **V** or **G** garage — paint + sedan/van  
6. Note Indian shop boards / awnings / lamp posts along roads  

## What “original models” means here

All vehicle and street meshes are **authored in-project** (GDScript box kits).  
No paid Asset Store packs. Not photoreal AAA yet — stylized-realistic India street look on real OSM roads.

## Still placeholder vs real

| Piece | Status |
|-------|--------|
| Road **layout** | Real OSM Dhule |
| Road **surface art** | Own procedural asphalt strips |
| Buildings | Own Indian shopfront kits (not OSM footprints) |
| Cars | Own low-poly sedan + delivery van kits |
| Photogrammetry / Blender hero assets | Later (optional) |
