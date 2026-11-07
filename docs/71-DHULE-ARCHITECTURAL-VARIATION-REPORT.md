# 71 — Architectural variation report (Phase 2H.4B.2)

**Baseline:** `a2e9e16` · **Scene:** `scenes/dev/dhule_building_chunk_pilot.tscn` (production untouched)  
**Manifest:** `docs/qa/64-chunk-pilot-manifest.json` — **48** accepted OSM footprints preserved.

## Source of truth (unchanged)

For every building: OSM id, polygon ring, world position, road clearance ≥ 0.5 m, per-id concave collision (`hit_<osm_id>`), single batched visual shell.

No footprint stretching. No invented business names. No city-wide generation.

## Style mapping

| Doc style | Manifest key | Shell family | Floors (estimated) |
|-----------|--------------|--------------|--------------------|
| A compact residential | `traditional_compact` | `cottage` | 1 |
| B urban family | `plastered_house` | `family` | 1–2 |
| C narrow urban | `narrow_urban` | `row` | 1–2 |

Assignment remains `DhuleBuildingStyles.choose` (area / aspect / OSM id). Stable across runs.

## Variation seeds (per OSM id)

`hash(osm_id)` drives:

- Plaster tint (10 restrained Maharashtra tones)
- Facade recipe 0–3 (flush / stone plinth / wide panes / vertical stack)
- Entrance 0–2 (wood leaf / twin leaf / steel grill door)
- Window spacing, grill density, balcony / tank eligibility

Same id → same facade every boot.

## Facade features (batched into 7 surfaces)

| Feature | Surfaces used | Notes |
|---------|---------------|-------|
| Plaster walls + colour | plaster | Vertex colours |
| Stone / brick plinth | brick | |
| Recessed windows + sill | dark + glass + plaster | On **exterior** skin |
| Window grills / mullions | metal + dark | |
| Chajja / sunshade | plaster (concrete tone) | |
| Door + lintel | dark + plaster | Three entrance recipes |
| Balcony slab + rail | plaster + metal + dark | Family / narrow when clear |
| RCC roof + parapet coping | roof + plaster | |
| Parapet posts | plaster | Longer fronts |
| Roof tank | metal | Selected by style + seed |
| Porch lamp | lamp | Road face |
| Compound walls | plaster | Existing neighbour logic |

Shop / shutter / blank board path remains for tagged commercial styles only — **none** of the 48 pilot buildings are tagged shops.

## Materials

Shared mats (still 7): plaster, roof/concrete, glass (opaque, less plastic), dark wood/steel, metal rails/tanks, brick/stone, lamp. Roughness raised; metallic lowered on plaster/glass.

## GLB policy

`indian_house.glb` evaluated; pilot stays procedural for batching (see doc 70).
