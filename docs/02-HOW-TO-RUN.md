# 02 — How to run & test

## Play

1. In Godot, press **F5** (or top-right Play).
2. You spawn on **real Dhule OSM roads** (clipped center).
3. Drive to the **green PICK UP** zone, then the **orange DELIVER** zone.
4. Earn ₹ and get the next job automatically.

## Controls

| Input | Action |
|-------|--------|
| **W** / ↑ | Accelerate |
| **S** / ↓ | Brake / reverse (when slow) |
| **A** **D** / ← → | Steer |
| **Space** | Handbrake |
| **R** | Reset car to spawn |

## Quick test checklist (P1)

- [ ] Game starts without crash; roads look like a city network
- [ ] Car moves / steers / handbrake / R reset
- [ ] Green pickup zone appears; entering it arms parcel
- [ ] Orange dropoff appears; entering it pays ₹ and starts next job
- [ ] HUD shows km/h, mission text, cash, delivery count
- [ ] Can complete **10 deliveries** without soft-lock
- [ ] OSM attribution visible near spawn (Label3D)

## If something breaks

| Problem | Fix |
|---------|-----|
| Black screen / no car | Confirm Main Scene = `scenes/main.tscn` in Project Settings → Application |
| Script error on F5 | Open **Debugger → Errors**; fix the `.gd` line shown |
| Car falls through world | City builder must run `_ready()` (node `DhuleBlock` in `main.tscn`) |
| Controls dead | Project → Project Settings → Input Map: `accelerate`, `brake`, `steer_left`, `steer_right`, `handbrake`, `reset_car` |

## Export (later — not P0)

Android / Play Store export is **Phase P2–P3**. See [07-PLAY-STORE.md](07-PLAY-STORE.md).
