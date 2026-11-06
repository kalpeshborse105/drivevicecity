# 13 — Official build order (your plan, locked)

Based on the latest screenshot: streets exist, but still **blocky**.  
We follow **your order** from now on.

---

## Your plan = our plan

| Phase | Focus | Goal |
|-------|--------|------|
| **PHASE 1 — MAP** | Own whole map design, more realistic | Dhule streets look like a real Indian city (stylized → richer) |
| **PHASE 2 — VEHICLE** | Own vehicle design + full customization | Hero car/van, paint, wheels, body options |
| **PHASE 3 — PLAY** | Driving feel + missions + features | Physics polish, traffic, audio, economy, Android |

**Important rule:** keep the current game **playable as a test drive** while we upgrade art.  
We do **not** delete jobs/controls — we improve how the world and cars look, then deepen play.

**References (formula only):** GTA Vice City / GTA V feel of “city + free drive + jobs”; BUSID feel of “local map + vehicle progression”.  
**Never** copy their assets / trademarks.

**Maps:** OpenStreetMap geometry is the real world we ship. Blender + the blosm addon turns that into 3D. Google satellite is an optional paid Map Tiles view, not the city we build. Never scrape Google tiles.

---

## Screenshot check (what we still need)

| Seen now | Verdict |
|----------|---------|
| OSM roads + jobs + minimap + van | Keep (systems OK) |
| Pink/tan box buildings | Phase 1 — need roofs, windows, shops, less empty lots |
| Flat grey asphalt | Phase 1 — need better road surface / lanes |
| Blocky red van | Phase 2 — hero mesh + customization |
| Tall yellow debug-like marker | Clean now — use flat ring / small arrow |

---

## PHASE 1 — Map (current)

### Correct workflow (locked)

The photograph of Dhule is the paid Google part. The free real city is the OpenStreetMap layout, dressed in Blender.

```
dhule_roads_game.json + dhulemap.osm   (real roads, footprints, place names)
        ↓
Blender 4.5 + blosm addon (OSM import only — no Google 3D / satellite button)
        ↓
simple 3D buildings + roads, one district at a time
        ↓
export .glb → assets/maps/ → Godot main scene + player car
```

1. **1A** Import one Dhule district (Agra Road / Panzara first), not all of India  
2. **1B** Keep real GPS positions from the JSON and OSM file  
3. **1C** blosm simple-3D buildings and highways; water where the river is mapped  
4. **1D** Export glb and drive it in Godot. Credit OpenStreetMap on screen  
5. **1E** Repeat the same import for the next district. Hand-dress shops only after the block is in-game  

Exit Phase 1 when: a drive from spawn follows a **real Dhule street** with building blocks on real footprints.

Google Map Tiles stays a separate optional scene (`scenes/google_drive.tscn`). It needs the paid Map Tiles API. It is not this workflow.

---

## PHASE 2 — Vehicle

1. Own hero **sedan** mesh (Blender → Godot), still free/own  
2. Own **delivery van** mesh  
3. Customization: paint, wheels, body kits, maybe stickers  
4. Garage UI shows real previews  

Exit Phase 2 when: vehicle reads clearly in screenshots next to reference games’ *silhouette quality* (not same polycount).

---

## PHASE 3 — Play & features

1. Driving feel polish (weight, brake, camera)  
2. Traffic + pedestrians (simple)  
3. More mission types / career  
4. Audio  
5. Android / Play Store  

---

## What we will NOT do yet

- Whole India map  
- Photoreal GTA V clone  
- Paid Asset Store city packs  
- New big feature systems before Phase 1–2 art foundation  

---

## Now

**PHASE 1 — Blender district import.**  
First clip is central Dhule (`dhulemap.osm`, about 20.890–20.910 N, 74.760–74.789 E).  
Detail: [06-MAP-AND-LEGAL.md](06-MAP-AND-LEGAL.md).
