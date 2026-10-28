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

**Maps:** OpenStreetMap only for data/names. Google Maps = eyes-only reference. Never scrape Google.

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

Do in this order:

1. **1A** Clean markers + richer road surface (asphalt tone, lanes, sidewalks)  
2. **1B** Building kits: windows, roofs, shop variety, less pink boxes  
3. **1C** Ground / lots / walls so empty tan slabs disappear  
4. **1D** Sky / lighting / fog for India afternoon (not washed desert)  
5. **1E** Landmark props (water tower, market stall, bus stop) on OSM points  

Exit Phase 1 when: 30-second drive from spawn looks like a **busy Dhule street**, not a prototype sandbox.

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

**PHASE 1 in progress**

- 1A markers/roads ✅ · 1B windows/roofs ✅  
- 1C lots/ground ✅ · 1D sky/light ✅ · 1E landmarks started ✅  

Next after more map polish: **PHASE 2 — Vehicle**.  
Detail: [14-PHASE1-LOTS-SKY.md](14-PHASE1-LOTS-SKY.md)
