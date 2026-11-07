# 74 — Terrain and shadow fix (Phase 2H.4B.3)

**Baseline:** `58fa44d` · **Cause proof:** doc 73 A/B table

## Fix

### 1. Ground slab + soil overlays (`osm_road_builder.gd` `_add_ground`)

- Drive slab: `StreetKit.add_box(..., cast_shadows=false)`.
- Fewer, smaller soft patches (18 × 14–28 m) with **same** `ground037` albedo tinted toward dusty base — no flat dark green cards.
- Explicit `cast_shadows=false` (these spawn before box-batch).

### 2. Scrub ring in `_fill_empty_lots`

- Textured soft scrub mats; cast off.

### 3. Landuse tints

- Grass/residential/etc. colours pulled toward dusty base (less “dark green stamp”).

### 4. `StreetKit.add_box`

- New `cast_shadows` argument (default `true` for walls/sheds).
- Batched visual boxes remain cast-off on flush.

### 5. `DhuleShadowPolicy`

- Detect unnamed thin ground overlays and kilometre slabs → force cast off (`terrain_off` counter).
- Mode B vehicle / road / Blosm rules **unchanged**.

## Before / after (identical A-mode: shadows ON)

| Still | Right-terrain avg | Dark frac |
|-------|------------------:|----------:|
| `74-before-shadows-on.png` (pre-fix A) | ~7 | ~1.0 |
| `74-after-shadows-on.png` (post-fix A) | see QA log | much lower |

Also: `74-before-shadows-off.png`, `74-before-overlays-hidden.png`.

Policy boot sample after fix: `terrain_off=19` (slab + overlays caught).

## Preserved

- Vehicle physics / gearbox
- OSM roads, spawn, delivery, minimap
- Mode B vehicle kit / wheel / smoke / NavArrow shadows OFF
- Blosm giant mesh cast OFF
- Building / prop casters allowed
- No city-wide building generation
