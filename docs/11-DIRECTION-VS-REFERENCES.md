# 11 — Direction check (screenshot vs GTA / BUSID)

**Verdict: systems direction is correct. Visuals are still early grey-box — much more art work needed.**  
We do **not** try to copy Rockstar / other commercial games’ assets. We **learn their product formula** and build our own Dhule India version with free OSM + original art.

---

## What your screenshot proves (28 Oct 2026)

### Working (keep)

- OSM Dhule roads under the car (real map backbone)
- Mission text + ₹ economy stub
- Sedan + paint (Green)
- Minimap + status “OK map · 24 anchors”
- Drive loop is playable

### Not ready (screenshot problems)

| What you see | Why it looks “wrong” vs big games | Fix order |
|--------------|-----------------------------------|-----------|
| Huge “SPAWN” + yellow pillar | Debug marker, not game art | Remove / shrink (done next) |
| Giant OSM text in world | Credit belongs in menu/HUD, not sky | Move to small HUD/about |
| Empty brown desert | City density missing near camera | Dense shop rows + props next |
| Flat grey road ribbons | No lanes, kerbs, markings, sidewalks enough | Road kit pass |
| Block car | Kitbash boxes, not hero mesh | Blender original car later |
| No traffic / people / audio | Living city missing | After density pass |
| Soft tan fog everywhere | Atmosphere OK as base, needs sky/buildings | Lighting + skybox pass |

**This is normal** after P0–P3 systems work. GTA and BUSID also started as grey boxes internally — players only see the polished years.

---

## Reference games — what we take (formula only)

### GTA Vice City / GTA V (Rockstar) — learn formula, never copy assets

| Pillar | What players feel | Our Dhule version |
|--------|-------------------|-------------------|
| Place identity | City is the star | Dhule + later India towns |
| Free roam | Fun just to drive | OSM roads first (done) |
| Camera | Clear chase cam | Improve framing next |
| Vehicles | Readable silhouette + garage | Own sedan/van → Blender hero car |
| Jobs | Short loops that pay | Parcel / food / passenger (started) |
| Density | Streets feel full | Shop rows, props, traffic later |
| Audio | Engine, city hum | Free/own SFX later |

**Do not:** rip GTA maps, cars, UI, music, or trademarks (“Vice City” style name is our own product story — keep legal name **DriveViceCity** / own branding on store).

### BUSID (Bus Simulator Indonesia) — closer product cousin

| Pillar | Lesson for us |
|--------|----------------|
| Local country roads + culture | India / Maharashtra signage, shop boards, vehicles |
| Job = route / delivery fantasy | Our parcel–food–passenger loop |
| Map familiarity | Real OSM layout players recognize |
| Progressive unlock | Better bus/car over time (our garage start) |
| Mobile-friendly scope | Prefer stylized-real over full GTA V fidelity on phones |

**BUSID-like scope is the smarter mobile target than full GTA V.**  
GTA V quality on phone as a tiny team = years / huge budget.  
**Local map + clear jobs + improving art** = shippable Play Store path.

---

## Are we going the right way?

**Yes**, if we keep this order:

```
1. Playable drive on REAL roads     ✅ (you have this)
2. Simple jobs that pay             ✅ (started)
3. City DENSITY + readable vehicles ← YOU ARE HERE (next work)
4. Audio + traffic + polish
5. Android / Play Store
6. Bigger map / more vehicles
```

**Wrong way:** jump to whole India map, or try to look like GTA V screenshots before streets feel busy.

---

## Step-by-step from this screenshot

| Step | Focus | Exit when… |
|------|--------|------------|
| **S1** | Remove debug clutter (SPAWN beam, huge OSM 3D text) | First view looks like a game, not a debug tool |
| **S2** | Dense Indian street kit near roads (shops, trees, poles) | Looking forward you see a street, not empty sand |
| **S3** | Better chase camera + road markings | Driving feels clearer |
| **S4** | One Blender “hero” sedan (still our own model) | Car reads as a car at a glance |
| **S5** | Engine + city ambient audio (free/own) | World feels alive |
| **S6** | Light traffic AI (simple) | Roads not empty |
| **S7** | Android export smoke | APK/AAB runs on phone |
| **S8** | Play closed test | Friends can install |

---

## Honest expectation

| Target | Time reality (small team) |
|--------|---------------------------|
| Fun Dhule delivery drive (stylized) | Months, doable |
| BUSID-like local job game | Many months |
| GTA V look-alike | Not realistic without studio + budget — **don’t aim this for v1** |

**Right brand promise for store later:**  
“Drive and deliver in Dhule — real roads, Indian street feel.”  
Not: “GTA 5 clone.”

---

## Related docs

- [USER-GUIDE.md](USER-GUIDE.md) — how to play  
- [05-ROADMAP.md](05-ROADMAP.md) — phases  
- [06-MAP-AND-LEGAL.md](06-MAP-AND-LEGAL.md) — OSM only, no Google Maps scrape  
