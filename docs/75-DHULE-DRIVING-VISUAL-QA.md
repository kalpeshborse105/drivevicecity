# 75 — Driving visual QA (Phase 2H.4B.3)

**Baseline:** `58fa44d` · **Scene:** `scenes/main.tscn` · 1280×720  
**Probe:** `scripts/dev/ground_surface_qa_probe.gd --mode=drive` (afternoon sun locked for stills)  
**Recording reference:** `Recording 2026-11-07 171750.mp4`

## Route coverage

| Shot | File |
|------|------|
| After fix, shadows ON | `docs/qa/74-after-shadows-on.png` |
| Before (shadows ON) | `docs/qa/74-before-shadows-on.png` |
| Before (shadows OFF) | `docs/qa/74-before-shadows-off.png` |
| Drive 1–4 | `docs/qa/75-drive-1.png` … `75-drive-4.png` |

Spawn → straight → open terrain → junction covered in drive sequence (same Carnival, Mode B).

## Results

| Check | Result |
|-------|--------|
| No unexplained giant dark terrain stamps | **Pass** — ground slab/overlays no longer cast |
| Vehicle Mode B unchanged | **Pass** |
| Genuine building shadows remain | **Pass** (soft building contact in after still) |
| Roads / Blosm giant cast off | **Pass** |
| Soft soil variation (not hard black cards) | **Pass** — textured tints |
| Physics / OSM roads / spawn / delivery | Untouched |

## Perf sample (drive probe)

See `docs/qa/_75_drive.log` (`PERF ground_qa …`). Capture-time FPS is not a settled playtest; draw cost unchanged in intent (no new casters).

## Buildings note

Production still shows Blosm block silhouettes at distance (expected). Facade detail work stays in the **pilot** scene from 2H.4B.2 — not expanded here.

## Acceptance

Open terrain no longer goes pitch-black from self-shadowing ground geometry. Mode B vehicle policy preserved. No city-wide building generation.
