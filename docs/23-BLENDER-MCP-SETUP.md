# 23 — Official Blender MCP setup (DriveViceCity)

Source: [Blender Lab MCP Server](https://www.blender.org/lab/mcp-server/) · add-on zip `mcp-1.0.3` · server clone `tools/blender_mcp`.

## Requirements met

| Piece | Location / version |
|-------|--------------------|
| Blender | `D:\Blender Foundation\Blender 5.2\blender.exe` (**5.2.3 LTS**, ≥ 5.1 required). Not on PATH by default — use full path or add that folder to PATH. |
| Add-on install status | `STATUS Installed "mcp"` via `blender --command extension install-file -r user_default -e mcp-1.0.3.zip` |
| Add-on | Installed from `C:\Users\Admin\Downloads\mcp-1.0.3.zip` (also copied under `tools/blender_mcp_1.0.3/`) |
| MCP Python package | `D:\drivevicecity\tools\blender_mcp\mcp` (official clone) |
| `uv` | `C:\Users\Admin\.local\bin\uv.exe` |
| Cursor config | `.cursor/mcp.json` → `blender` server via `uv run blender-mcp` |

## How to use (each session)

1. Launch Blender 5.2.
2. Preferences → Add-ons → enable **MCP** → **Start** server (default `localhost:9876`).
3. In Cursor, refresh MCP servers; `blender` should show tools.
4. Keep Blender open while the agent uses MCP for asset authoring.

**Security:** the server executes LLM-generated Python inside Blender with no sandbox. Use only on non-sensitive files.

## Asset export convention (Android-safe)

- Export **glTF Binary (.glb)**, metres, **front = +Z** (`MODEL_FRONT`).
- Separate wheel objects when applicable.
- Drop into `assets/models/…` and register in `AssetKit.NORMALIZE`.
- Do not rewrite `VehicleBody3D` / OSM JSON when swapping meshes.

## Not done by MCP alone

Playable Mumbai roads come from **OSM**, not from Blender MCP or `mumbai_city.glb`.
