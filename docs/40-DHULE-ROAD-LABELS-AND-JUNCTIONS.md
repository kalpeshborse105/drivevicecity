# Road labels and junctions

## Names

Floating labels are gone. A verified `name`, or `ref` when the name is empty, is painted on a sign whose post stands on the ground beside the carriageway. The sign is placed `half the road width + 2.6 m` off the centre line, and it is skipped if that point lands on another road or inside a building footprint.

There are 172 candidate signs across the named ways. Only 8 are shown at a time, the ones within 78 m of the camera, at least 34 m apart. The choice follows the camera, so the first 48 roads in the JSON no longer use up the cap. The spawn road `887431550` has no name, and the nearest verified name is Major District Road 46, about 260 m away, so the spawn itself stays unlabeled.

## Junctions

Centre lines are unchanged. Where ways already meet at an angle, the ribbon stops at a disc built from those endpoints, and the disc is drawn in the same asphalt batch. Straight splits are left alone. Roundabout approaches stop at the ring edge. The three mapped islands are unchanged. Counts are in `docs/39-DHULE-URBAN-LAYOUT-AUDIT.md`.

## Wheels

Wheel spin is visual. Forces, friction, and suspension are unchanged. Kit nodes named as tyres or road wheels rotate about the car's lateral axis. The procedural wheels do the same when they are visible. The autorickshaw mesh has no separate tyre nodes, so its physics wheels are shown and those roll.

On the isolated test the Carnival tyre rotation moved from `(0, 0, 0.06)` to `(0, 0, -2.56)` over the same run that reached about 74 km/h, and the car stayed on the road.

## Performance

Intel UHD 620, 1280×720. The previous production baseline was about 13 FPS and 1,684 draw calls.

| Scene | FPS | Draw calls |
| --- | ---: | ---: |
| Urban test, 52 ways | 29 | not sampled separately |
| Production `scenes/main.tscn`, overhead at the spawn | 19 | 1,680 |

This run measured 19 FPS and 1,680 draws. That is one sample, taken from the same kind of overhead view as the 13 FPS baseline. The road batch is still 3 draws. The 42 junction discs are inside that batch.

Production log: `PHASE1 map: 796 ways`, spawn `(-636.5, 881.8)`, `ROAD roundabouts 3`, `junctions 42`.

## Screenshots

- `docs/qa/40-spawn.png` — spawn, unnamed residential road
- `docs/qa/40-sign.png` — Major District Road 46, post on the ground
- `docs/qa/40-junction.png` — spawn-area grid
- `docs/qa/40-roundabout.png` — way 887725187
- `docs/qa/40-wheels.png` — Carnival after the wheels had rolled
- `docs/qa/40-production.png` — production scene

## Still open

- 279 mapped ends still stop where the source stops.
- Two centre lines cross without a shared node and have no disc.
- No verified square or park polygon exists in the current OSM extracts, so none was built.
- The autorickshaw's sculpted wheels are part of the body mesh. The rolling wheels on that vehicle are the physics-wheel meshes.

## Next phase

Building geometry. The road centre lines, the ribbon, and this sign pool can stay as they are.
