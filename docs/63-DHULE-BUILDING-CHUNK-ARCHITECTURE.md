# 63 — Building chunk architecture (Phase 2H.4A)

**Status:** Design + small isolated bench only.  
**Not done:** city-wide generation, production Blosm replacement, prototype integration.

## Inputs already measured

| Source | Finding |
|---|---|
| Doc 35 | Joined Blosm ~63 draws / ~59 FPS on high cam; **one node per id → 2,499 draws / 33 FPS** |
| Doc 36 | Runtime shape: ~500 m chunks, wall+roof materials, side buffer of OSM way ids |
| Doc 61/62 | Production draw pain today is **vehicle kit meshes + minimap**, not Blosm (2 draws) |
| 16-building prototype | Facade kit works; must not ship 1,866 individual shells |

## Target runtime shape (future)

```
DhuleBuildingChunks (Node3D)
├── chunk_ix_iz (MeshInstance3D)     # 1–3 surfaces: wall / roof / unresolved
│     meta: osm_way_ids: PackedStringArray  # parallel to confident triangles
│     meta: chunk_key: Vector2i
├── chunk_ix_iz_col (StaticBody3D)   # trimesh per chunk (or car-local)
└── (optional) lod_far_merged         # distant chunks collapsed to 1 draw
```

### Rules

1. **Spatial chunks** — default cell **500 m** (doc 36). Occupied district stays in tens of draws.
2. **Shared materials** — two (wall, roof) + one unresolved; no per-building material instances.
3. **Per-chunk mesh batching** — many footprints → one `ArrayMesh` per chunk.
4. **OSM way ID metadata** — store ids in mesh meta / side buffer; **not** one Godot node per id.
5. **Collision** — trimesh per chunk (or streaming around the car). Not 1,866 bodies.
6. **Distance visibility / LOD** — hide or merge chunks beyond a radius; Blosm boxes remain the far LOD until replaced.
7. **Blosm protection** — production `DhuleBlosmCity` stays loadable. Chunk system is additive or a flagged swap; never delete the source GLB identity path without a toggle back.

### What not to do

- Do not instantiate 1,866 prototype shells in `main.tscn`.
- Do not merge the entire city into one anonymous mesh that drops way ids.
- Do not load archive `buildings/<id>.glb` into the running game (`.gdignore` stays).

## Isolated bench (not production)

Probe: `scripts/dev/chunk_arch_bench.gd` · 64 box shells · Intel UHD 620 · 1280×720

| Mode | FPS med | Draws | Objects |
|---|---:|---:|---:|
| A — 64 individual buildings (2 meshes each) | 1* | 81 | 81 |
| B — 8 spatial chunks (8 buildings each) | **54** | **15** | 15 |
| C — B + hide chunks &gt;40 m from camera | **60** | **1** | 1 |

\* Contended GPU sample; absolute FPS varies — the **draw ratio** is the signal.

Log: `docs/qa/_63_chunk_bench_log.txt`.

## Migration sketch (later phase)

1. Keep Blosm on as default.
2. Build chunk meshes offline from partition (doc 35/36) with way-id buffers.
3. Feature flag: `USE_BUILDING_CHUNKS` loads chunks in a radius; optional hide Blosm buildings mesh only.
4. Prototype shells remain in `scenes/dev/` until a neighbourhood pilot passes FPS gates from doc 61/62.

## Gate for city-wide generation

Do not start 1,866-building generation until:

- Production spawn draws stay near the post-2H.4A band (hundreds, not thousands) with kit + minimap fixes in place.
- A neighbourhood chunk pilot beats one-node-per-id and matches joined-mesh draw order of magnitude.
- Way-id metadata round-trips on a sample of ≥16 footprints.
