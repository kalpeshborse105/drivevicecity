# 09 — P2: Map/vehicle mapping + paint + job types

## Map / vehicle audit (fixed)

| Issue found | Fix |
|-------------|-----|
| Spawn on map **edge** (z≈772) | Prefer core anchors within ~420 m of Dhule center |
| Car spawned with **no road heading** | JSON now stores `hx/hz`; car `set_spawn(pos, heading)` faces road |
| Car floated **too high** | Grounded spawn ~0.55 m; stronger suspension |
| Hard to find mission zones | Yellow **nav arrow** + HUD distance (meters) |
| Anchors not road-aligned | Anchors taken from road midpoints with tangent |

Spawn pad (blue cylinder + “SPAWN” label) marks the mapped start point.

## P2 features

| Control | Action |
|---------|--------|
| **P** | Cycle paint (7 colors) |
| **V** | Toggle **Sedan** / **Delivery Van** |
| WASD / Space / R | Drive / handbrake / reset (same as P1) |

### Job types (random each job)

- **Parcel** — green pickup → orange drop  
- **Food** — red pickup → yellow drop  
- **Passenger** — blue pickup → purple drop  

## Verify mapping in-game

1. Press **F5**
2. Confirm blue **SPAWN** pad under the car and roads under the wheels  
3. Car should face along the road (not sideways into dirt)  
4. Yellow arrow points to active zone; HUD shows distance in meters  
5. Press **P** / **V** and confirm body color / van shape change  

## Regenerated data

```powershell
python tools/osm_to_game_json.py
```

Creates `assets/maps/dhule_roads_game.json` with `spawn` + `delivery_anchors` including headings.
