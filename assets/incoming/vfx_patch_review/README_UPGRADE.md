# DriveViceCity — Dhule Realistic Google Map & High-VFX Upgrade Patch (Godot 4.7)

This patch upgrades your repository (`https://github.com/kalpeshborse105/drivevicecity`) with:
1. **Google Maps-Style Dhule Navigation Minimap (`scripts/minimap.gd`)**:
   - Real-time GPS latitude/longitude readout (`20.9020° N, 74.7770° E` origin matching `assets/maps/dhule_roads_game.json`).
   - Direct cyan/blue GPS route polyline from `PlayerCar` to the active `DeliveryMission` target.
   - Landmark pins for **Agra Road (NH-3)**, **BAPS Shri Swaminarayan Mandir**, **Chhatrapati Shivaji Maharaj Statue**, **Panzara River Bridge**, **Deopur Vidyanagri**, and **Rajwade Sanshodhan Mandal**.
   - `SAT` / `MAP` mode toggle button alongside `+` and `-` zoom controls.
2. **Real High-VFX Lighting, SSR & Weather Controller (`scripts/vfx_environment_controller.gd`)**:
   - Enables **ACES Filmic Tonemapping**, **Screen-Space Reflections (SSR)**, **SSAO**, **SSIL**, and **HDR Softlight Bloom**.
   - Press **`T`** at runtime to cycle 4 atmospheric presets: *Golden Hour Dhule*, *Sunny Highway Noon*, *Vice City Neon Night*, and *Monsoon Wet Road*.
3. **Wet/Dry PBR Asphalt Shader (`shaders/dhule_pbr_asphalt.gdshader`)**:
   - Procedural micro-grain asphalt, reflective monsoon puddles, curb wear, and Indian highway dashed yellow center lines.
4. **Updated Bootstrap (`scripts/game_bootstrap.gd`)**:
   - Automatically attaches `VFXEnvironmentController` and wires `DeliveryMission.target_changed` into the upgraded `Minimap`.

## How to Apply to `D:\drivevicecity`
1. Extract this `.zip` directly into your `D:\drivevicecity` project root folder.
2. Open `project.godot` in **Godot 4.7** and press **F5**.
