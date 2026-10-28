# 03 — Project structure

```
D:\drivevicecity\
├── project.godot
├── icon.svg / LICENSE / README.md
├── docs/                  # Working documentation
├── assets/maps/           # OSM-derived dhule_roads_game.json + attribution
├── tools/osm_to_game_json.py
├── scenes/
│   ├── main.tscn
│   ├── player_car.tscn
│   └── delivery_zone.tscn
└── scripts/
    ├── game_bootstrap.gd
    ├── osm_road_builder.gd
    ├── delivery_mission.gd
    ├── delivery_zone.gd
    ├── player_car.gd
    ├── hud.gd
    └── dhule_block_builder.gd   # P0 placeholder (unused by main)
```

## Scene graph (`main.tscn`)

```
Main (Node3D + game_bootstrap.gd)
├── WorldEnvironment
├── Sun
├── DhuleMap               # osm_road_builder.gd
├── PlayerCar
├── DeliveryMission        # delivery_mission.gd + zone scene
└── HUD
    └── Root (Speed / Title / Stats / Mission / Hint)
```

## Car graph (`player_car.tscn`)

```
PlayerCar (VehicleBody3D + player_car.gd)
├── BodyMesh / Cabin
├── CollisionShape3D
├── WheelFL / WheelFR      # steering + traction
├── WheelRL / WheelRR      # traction
└── CameraPivot / Camera3D # chase cam
```

## What each script owns

| Script | Responsibility | Do not put here |
|--------|----------------|-----------------|
| `player_car.gd` | Throttle, brake, steer, handbrake, reset, speed helper | Missions, UI layout |
| `dhule_block_builder.gd` | Roads, buildings, landmarks, trees (placeholder) | Vehicle physics |
| `hud.gd` | Read car speed, show text | Physics |

## Generated (ignore in Git)

`.godot/` — editor cache / imports. Safe to delete; Godot recreates it.
