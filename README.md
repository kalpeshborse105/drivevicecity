# DriveViceCity

Free-roam driving game prototype — **Dhule, Maharashtra (India)**.  
Engine: **Godot 4.7** · Folder: `D:\drivevicecity` · Status: **P3 playable**

**No paid map APIs / no paid asset packs.** OSM Dhule roads + **original** car/van kits + shopfronts.  
Paint, sedan/van, parcel/food/passenger, minimap, garage.

## Quick start

1. Open this folder in **Cursor** (already OK if workspace is `D:\drivevicecity`).
2. Open the same folder in **Godot 4.7** → `project.godot`.
3. Press **F5** to play.

| Key | Action |
|-----|--------|
| W / ↑ | Accelerate |
| S / ↓ | Brake / reverse |
| A D / ← → | Steer |
| Space | Handbrake |
| R | Reset |
| P | Cycle paint |
| V | Sedan / Delivery Van |
| G | Garage panel |

## How to play

→ **[docs/USER-GUIDE.md](docs/USER-GUIDE.md)**

## Build order (locked)

1. **Map** realism (own design) → 2. **Vehicle** design + customization → 3. **Play** features  

→ **[docs/13-BUILD-ORDER.md](docs/13-BUILD-ORDER.md)** · refs: [GTA/BUSID direction](docs/11-DIRECTION-VS-REFERENCES.md)

## Documentation (full working docs)

Start here → **[docs/INDEX.md](docs/INDEX.md)**

| Doc | Topic |
|-----|--------|
| [01-SETUP](docs/01-SETUP.md) | Install & open IDE + Godot |
| [02-HOW-TO-RUN](docs/02-HOW-TO-RUN.md) | Play & test checklist |
| [03-PROJECT-STRUCTURE](docs/03-PROJECT-STRUCTURE.md) | Files & scene graph |
| [04-WORKLOG](docs/04-WORKLOG.md) | Step-by-step what we did |
| [05-ROADMAP](docs/05-ROADMAP.md) | P0 → P4 plan |
| [06-MAP-AND-LEGAL](docs/06-MAP-AND-LEGAL.md) | OSM pipeline, legal |
| [07-PLAY-STORE](docs/07-PLAY-STORE.md) | Publish checklist |

## Project layout

```
drivevicecity/
  docs/           ← working documentation
  scenes/         ← main.tscn, player_car.tscn
  scripts/        ← car, city builder, HUD
  project.godot
```

## Jobs

Colored zones: **Parcel** / **Food** / **Passenger** — follow the yellow arrow.  
Mapping + vehicles: [docs/09-P2-VEHICLES-AND-JOBS.md](docs/09-P2-VEHICLES-AND-JOBS.md)

## Test

```powershell
godot --path D:\drivevicecity --headless -s res://tools/smoke_test.gd
```

Details: [docs/10-TEST-AND-VISUALS.md](docs/10-TEST-AND-VISUALS.md)

## Next

See [docs/05-ROADMAP.md](docs/05-ROADMAP.md) — Android export smoke build.
