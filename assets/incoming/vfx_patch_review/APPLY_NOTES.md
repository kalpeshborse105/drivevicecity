# VFX patch review (30 Oct 2026)

Zip: `drivevicecity_godot4_dhule_vfx_patch.zip`

| Piece | Verdict |
|-------|---------|
| `vfx_environment_controller.gd` | **Used** (toned down: no SSIL, lighter SSR) |
| `dhule_pbr_asphalt.gdshader` | **Kept** under `shaders/` for later wet-road pass |
| `game_bootstrap.gd` (full replace) | **Not used** — merged VFX spawn only |
| `minimap.gd` “Google Maps-style” | **Rejected** — legal/branding; keep OSM minimap |

No Google tiles, no SAT imagery, no scraped Street View.
