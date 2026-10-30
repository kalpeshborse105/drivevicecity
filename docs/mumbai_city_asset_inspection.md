# Mumbai City Download — Initial Asset Inspection

## Scope and production safety

- Production `res://scenes/main.tscn` and `res://project.godot` were not changed.
- Existing Dhule OSM map/source data, player, physics, garage, missions, settings,
  navigation, minimap, and Android export settings were not changed.
- No network download or plugin install was performed.
- The three local GLBs remain in `res://assets/incoming/` untouched.

## Files located

Duplicate source copies exist under `C:/Users/Admin/Downloads/` and imported
project copies exist under `D:/drivevicecity/assets/incoming/`:

| File | Size | GLB scene nodes | Meshes | Materials / embedded images | Approx triangles | Godot bounds (m) |
|---|---:|---:|---:|---:|---:|---|
| `mumbai_city.glb` | 47,097,464 B (~44.9 MiB) | 867 | 651 | 60 / 0 | 774,240 | 3.04 × 0.74 × 2.33 |
| `city_map_free.glb` | 31,196,480 B (~29.8 MiB) | 35 | 30 | 26 / 26 | 349,042 | 410.79 × 46.90 × 373.70 |
| `old_city.glb` | 279,577,776 B (~266.6 MiB) | 213 | 128 | 30 / 25 | 4,942,362 | 67,716 × 22,062 × 67,716 |

Triangle counts are estimated from glTF triangle primitives / imported mesh
surface arrays. `mumbai_city.glb` uses an 867-node, 651-distinct-mesh hierarchy;
mesh node labels include city assets (e.g. petrol-pump components), but the GLB
has **no embedded texture images**. The other two have embedded textures.

Godot instantiated the files using its existing glTF/GLB scene importer. All
three contain mesh instances, and none contain `PhysicsBody3D` or
`CollisionShape3D` nodes. `mumbai_city.glb`'s imported scene is unexpectedly
only about 3 m across; do not treat that as verified real-world scale. `old_city`
has an extremely large and offset bound, consistent with a scale/origin/import
problem until proven otherwise. `city_map_free` has a city-sized bound and 30
mesh instances, but its model must not be assumed to encode a driveable road
network or gameplay navigation.

## Mumbai test scene

`res://scenes/mumbai_city_test.tscn` is isolated from production. It instances
only `assets/incoming/mumbai_city.glb`, with a camera and simple inspection
lighting. It deliberately adds **no collision**, car, AI, pedestrian system, or
invented road geometry. The imported model is not rewritten or optimized.

## License / attribution

The embedded glTF asset extras in `mumbai_city.glb` identify the exact supplied
Sketchfab source URL, title `mumbai city`, author `suveer__10`, and license
`CC-BY-4.0`. This confirms the local file's claimed source matches the URL in
the request. Preserve attribution to suveer__10 and comply with the CC BY 4.0
terms when distributing. The other embedded metadata identifies `city_map_free`
as Katydid's Sketchfab model under CC BY 4.0, and `old_city` as Katydid's
Sketchfab model under CC BY 4.0. No external download or license-file changes
were made.

## Phase A/B reinspection and visual assessment

- **Candidate selected for continued isolated inspection:** `mumbai_city.glb`.
  It is the only file whose embedded source metadata matches the exact supplied
  Mumbai Sketchfab URL. The isolated overview visually shows a compact,
  stylized city block with many buildings and street-like corridors. It is a
  good visual reference/test candidate, not yet a verified playable world.
- **Scale/orientation:** the GLB root has an up-axis conversion and a parent
  transform with a uniform `0.01` scale. Godot's imported scene measures about
  3.04 × 0.74 × 2.33 m. This looks miniature relative to a driving world; do not
  arbitrarily multiply scale until asset-author units/intent are confirmed.
- **Roads:** the overview shows a connected-looking grid of street corridors,
  but none of 867 nodes is named for roads/streets/lanes/sidewalks/intersections;
  the exported hierarchy is largely repeated city/house/building mesh parts.
  Road width, continuity at driving height, junction gaps, and safe lane geometry
  are therefore **not verified**. No road graph or navigation data exists.
- **Separate buildings:** 651 mesh instances indicate many pieces, but do not
  prove road/building segmentation or practical chunk streaming.
- **Collision:** none included. No collision was generated. Blanket collision
  over 651 pieces would be unsafe until road meshes are identified.
- **Traffic/pedestrians:** no routes, lane graph, sidewalks or navigation meshes
  were identified.
- **Other candidates:** `city_map_free` has city-sized imported bounds and
  textures, but live inspection shows an irregular, fragmented low-detail layout;
  its generic 30-node hierarchy offers no reliable roads/buildings separation.
  `old_city` remains unsuitable for a driving prototype as-is because it is
  ~267 MiB, ~4.94M triangles, and imports at an extreme 67.7 km × 22.1 km ×
  67.7 km bound. Its scene was not launched due to the disproportionate load risk.
- **Android risks:** Mumbai has 651 mesh instances and ~774k triangles; its
  47 MB source plus no embedded images is not proof of Android readiness. The
  much heavier old-city asset is particularly unsuitable without optimization.

## Phase C road feasibility (current follow-up)

- Imported scene root itself has scale `(1, 1, 1)`. GLB node 0 applies the
  Z-up-to-Y-up axis conversion; its child FBX scene node has a uniform `0.01`
  scale matrix. With those transforms preserved, Godot reports the city bounds
  as approximately **3.04 × 0.74 × 2.33 m**. No scale override was applied.
- The imported hierarchy contains **651 MeshInstance3D, 0 physics bodies and
  0 collision shapes**. No mesh/node name or material clearly identifies a
  road, street, lane, sidewalk, intersection or pavement. Mesh names are largely
  generic `polySurface` / `pCube` and asset/material labels such as house,
  construction building, petrol pump, bus, and city-of-dreams. Materials are
  mostly untextured flat StandardMaterial3D colors.
- A scene-wide geometry scan found only **two surface instances with >1 m by
  >1 m horizontal AABBs**, both spanning the same ~3.01 × 2.32 m area, and both
  associated with a house/lambert material label. This is not a safely
  attributable road surface. Smaller geometry does not establish a connected
  corridor; visual gaps in the overview are not reliable road evidence.
- The existing player car collision box is **1.9 m wide × 4.4 m long**, already
  larger than the entire imported city in its current authored scale. Do not
  rescale the model (prohibited in this phase), and do not place this car into
  the mini-scene.
- **No route is safe to author from current evidence.** The model has no
  road-specific geometry metadata, route width/continuity proof, or independently
  separable road deck to collide against. Manually painting a road over visible
  gaps would be arbitrary and could overlap buildings. No road mesh, collision,
  car, traffic, or pedestrian prototype was created.

### Stop condition / missing requirement

`mumbai_city.glb` is not currently a viable driveable world at its imported
scale. To continue safely, provide a road-ready city asset with documented
meter scale and separable road surfaces/collision or a verified road centerline
layout tied to this exact model. Alternatively, explicitly approve a new road
layout authoring phase and its scale assumptions. Until then, only use this GLB
as a small visual/reference asset. Do not claim geographic accuracy based only
on its name.

## Tests and confirmed issue

- Both `mumbai_city_test.tscn` and `city_map_free_test.tscn` launched live with
  no runtime errors; their rendered overviews were inspected.
- The original Mumbai inspection camera transform was serialized transposed,
  so it looked away from the model and rendered only the background. Fixed the
  camera basis in the test scene; it now frames the city. This was a confirmed
  **test-scene camera bug**, not a production gameplay bug.
- Existing Dhule `main.tscn` launched and built 420 OSM ways / 24 anchors.
- Direct headless `tools/smoke_test.gd`: **PASS** — map, vehicle mesh, inputs,
  anchors and collision-count guard all passed (18,199 meshes; 722 static bodies).
- Godot `run_tests` cannot run this legacy SceneTree smoke script as a unit test;
  direct headless execution is the applicable check and passed.
- Main-scene reload emitted existing GDScript warnings (name shadowing and
  narrowing conversions) but no runtime errors. They were not introduced or
  changed in this phase.
- The user has not provided reproduction steps for the reported ~15 bugs, so no
  gameplay bugs can be confirmed from this run. No gameplay fixes were made.
- Follow-up geometry scan: 651 meshes / 0 physics bodies / 0 collision shapes;
  no road-semantic mesh/material labels; two broad surfaces share one 3.01 ×
  2.32 m plan extent but are not identified as roads.
- Follow-up live launch of `mumbai_city_test.tscn`: completed 3 seconds at 119
  frames with no runtime errors; screenshot confirms the compact city asset.
  This is an inspection-only run, not a vehicle test.
- Follow-up direct headless Dhule smoke test: **PASS** (`SMOKE_TEST_RESULT=PASS`;
  420 roads, 24 anchors, 18,199 meshes, 722 static bodies).
- No car-on-road collision or driving result is claimed: no safe route could be
  established, and the existing car's 1.9 × 4.4 m collision box exceeds the
  model's imported dimensions.
