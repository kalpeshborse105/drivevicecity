# Vehicle facing (Godot 4 VehicleBody3D)

## Canonical directions

| Constant | Vector | Role |
|---|---|---|
| `Vector3.MODEL_FRONT` | `(0, 0, +1)` | Drive forward, headlights, steering axle |
| `Vector3.MODEL_REAR` | `(0, 0, −1)` | Chase cam, exhaust, rear axle |

Official reference: [godot-demo-projects `3d/truck_town`](https://github.com/godotengine/godot-demo-projects/tree/master/3d/truck_town) — steering wheels on **+Z**, exterior camera on **−Z**, positive `engine_force` / turbo along `basis.z`.

Docs: [VehicleBody3D](https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html) — local forward is `MODEL_FRONT`.

## DriveViceCity wiring

- Kit GLBs: `AssetKit.NORMALIZE` yaw **0** so glTF nose stays on **+Z**.
- Procedural sedan: headlights already at **+Z** (`vehicle_mesh_builder.gd`).
- Spawn: `Basis.looking_at(-heading)` so **+Z** points along OSM road heading (`Basis.looking_at` aims **−Z**).
- Chase: offset on **−Z**; `look_at` toward **+Z**.
- Minimap wedge: uses `basis.z`.

Do **not** flip the mesh 180° to “fix” a grille-in-camera bug — that usually means the chase pivot is on the wrong side.
