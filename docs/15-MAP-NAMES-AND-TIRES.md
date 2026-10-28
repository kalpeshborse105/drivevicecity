# 15 — Real road names + tire fix (report update)

## Your question: Google road names?

**No Google fetch / scrape.** That breaks ToS and our free build rule.

| Source | Allowed? |
|--------|----------|
| Look at Google Maps with your eyes for feel | Yes |
| Download Google tiles / names / 3D | **No** |
| **OpenStreetMap** road geometry + names | **Yes** (ODbL credit) |

We already have OSM names in `dhule_roads_game.json`, e.g.:

- Sakri Road  
- State Highway 14  
- Dhule Malegaon Road  
- 80 Feet Road  

These now show as **street signs** in the dense map area.

## Tire / driving fix (from your screenshot report)

| Problem | Fix |
|---------|-----|
| Wrong wheel spin / burnout | Softer launch torque + higher friction |
| Wheel mesh axis wrong | Cylinder aligned to VehicleWheel3D **X** axis |
| 4WD spin | Switched to **RWD** drive + front steer |
| Collider fighting tires | Raised chassis collision |

## Phase plan (unchanged)

1. **MAP** (current) — OSM realism + names + city kits  
2. **VEHICLE** — hero mesh + customization  
3. **PLAY** — deeper features / Android  

Cursor rule saved: `.cursor/rules/drivevicecity.mdc` (always on for this project).
