# DriveViceCity — How to Play (User Guide)

**Game:** free drive + delivery jobs in **Dhule, Maharashtra**  
**Engine:** Godot 4 · **Controls:** keyboard (gamepad later)

---

## Start the game

1. Open **Godot 4.7**
2. Open project folder `D:\drivevicecity` (file `project.godot`)
3. Press **F5** (Play)
4. You spawn on a real OpenStreetMap road near Dhule center (blue pad)

---

## Goal

Earn money (₹) by completing jobs:

1. Follow the **yellow arrow** (and green/colored zone) to **PICK UP**
2. Drive into the glowing cylinder
3. Follow the next zone to **DELIVER / DROP**
4. Get paid → next job starts automatically

Job types (random):

| Job | Pickup feel | You carry |
|-----|-------------|-----------|
| **Parcel** | Green zone | Parcel |
| **Food** | Red zone | Food |
| **Passenger** | Blue zone | Rider |

---

## Controls

| Key | Action |
|-----|--------|
| **W** / ↑ | Accelerate |
| **S** / ↓ | Brake / reverse (when slow) |
| **A** **D** / ← → | Steer |
| **Space** | Handbrake |
| **R** | Reset car to spawn |
| **P** | Next paint color |
| **V** | Switch Sedan ↔ Delivery Van |
| **G** | Open / close Garage panel |

---

## HUD (on screen)

| Where | Meaning |
|-------|---------|
| Top left | Title, cash ₹, jobs done, cargo, vehicle name |
| Top center | Current mission text |
| Top right | Status + **minimap** (you = blue, target often green) |
| Center distance | “Target X m” while a job is active |
| Bottom left | Speed km/h |
| Bottom right | Control reminder |
| Yellow arrow above car | Points to active pickup/dropoff |

---

## Tips

- Stay on the **dark grey roads** — that layout is real Dhule **OpenStreetMap** data (not Google).  
- Look for green **street name signs** (e.g. Sakri Road, State Highway 14).
- If stuck or flipped → press **R**.
- Van is heavier / better for “delivery feel”; Sedan turns quicker.
- Garage (**G**) is the same as **P** / **V**, with buttons.

---

## What this build is (honest)

This is an **early playable prototype**, not a finished GTA-like product.

**Already working:** drive, real road layout, jobs, paint, van, minimap, garage, denser shop streets near spawn.  
**Still early:** stylized shops (not photoreal), simple car kits, no traffic/audio yet.

Build order: **Map → Vehicle → Play** — see [13-BUILD-ORDER.md](13-BUILD-ORDER.md).  
References (formula only): [11-DIRECTION-VS-REFERENCES.md](11-DIRECTION-VS-REFERENCES.md).

---

## Map credit

Map data © OpenStreetMap contributors (ODbL).  
https://www.openstreetmap.org/copyright
