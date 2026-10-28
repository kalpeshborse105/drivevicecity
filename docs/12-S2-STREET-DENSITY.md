# 12 — S2 Street density + S3 camera/markings

## Goal

Fix the screenshot problem: empty brown desert → **readable Indian street** when looking forward.

## What changed

| Area | Change |
|------|--------|
| `street_kit.gd` | Own shop rows, awnings, boards, lamps, trees, parked stubs, billboards |
| `osm_road_builder.gd` | Dense dress within ~320 m of spawn; medium to ~520 m |
| Roads | White edge lines + center dashes + curbs + sidewalk ribbons |
| Ground | Occasional green patches so sand feels less empty |
| Camera | Higher chase pivot, speed pull-back, look farther ahead |

## Density rules

- **Dense (≤320 m from spawn):** shop rows both sides, lamps, trees, some parked stubs  
- **Medium (≤520 m):** thinner shops / props  
- **Farther:** roads only (perf)

## How to check

1. Godot **F5**
2. Look ahead from spawn — you should see shop boards / awnings / sidewalks, not empty sand  
3. Drive 100–200 m — streets stay dressed  
4. Minimap still works; jobs still work  

## Still next (S4+)

- Blender hero sedan (own model)  
- Audio  
- Simple traffic AI  
- Android export  
