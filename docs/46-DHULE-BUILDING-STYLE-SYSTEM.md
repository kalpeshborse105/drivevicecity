# 46 — Dhule building style system

The shells follow the OSM ring. A style only changes height, openings, and roof details. It does not replace the polygon with a rectangle, and it does not invent a business name.

`scripts/building_shell.gd` draws every shell in one mesh. Plaster uses a vertex colour. The other slots are roof, glass, dark openings, metal, brick accents, and a small exterior lamp. The test neighbourhood is one chunk, `Chunk_spawn`, because these 24 plans sit in one block. The way id is on that mesh and on a body named `hit_<id>`.

## What the Blosm mesh contains

`assets/models/environments/dhule_blosm_city.glb` is still the production city. Docs 35 and 36 measured it: 25,251 building triangles, shared wall and roof materials, no way id stored on the mesh. 1,730 footprints match under the 0.20 m rule. 136 footprints have geometry that fails that rule. Heights in that mesh are extruded boxes, not surveyed elevations. This phase does not split or replace that file.

## Styles

| Style | When it is used | Height |
| --- | --- | --- |
| Cottage | Area under 72 m², and the road face is not a narrow row | 3.15 m, one floor. Estimated. |
| Family | Area at least 72 m², or a single outline between 180 and 500 m² | One floor at 3.15 m, or two floors at 6.1 m. Estimated unless `height` or `building:levels` is present. |
| Row | Road face shorter than 4.6 m and the longest side longer than 8 m | One floor under 72 m², otherwise two. Side walls within 2.05 m of a neighbour stay blank. |
| Shop | A real `shop` tag or `building=commercial` / `retail`, or the one visual estimate below | Ground shutter and a blank board. Upper floor only when the floor rule says two. |
| Commercial | Same tags, area at least 160 m² | Wider shutter bays. Not used in this block. |
| Apartment | `building=apartments`, or a verified floor count of 3 or more | One floor band per storey and balconies. Not used in this block. |

Older names still map: `compact` to cottage, `urban` to family, `mixed` to shop.

Walls are 0.28 m thick. Windows and sunshades sit just outside the plaster. Doors, steps, and lamps are on the road edge only. A step is added only when the asphalt is more than 2.8 m away. A roof tank is not put on every cottage. A stair head is only on an outline of at least 180 m², or on an apartment. Brick is a base course or a parapet cap, not a whole invented facade.

Plaster colours are warm white, cream, light yellow, pale peach, muted pink, light grey, and exposed concrete. Neighbours do not share one colour just because their way ids are close. Window width and sunshade depth change with the way id. No two of those choices are a surveyed facade.

## Shopfronts and names

No footprint in this block has a `shop`, `amenity`, or `name` tag. `data/dhule/city_shops.json` still has no shop within 400 m of the spawn. The only shutter is way `1337951728`. Its outline is real. Calling it a shop is a visual estimate: it has the widest road face in the set, 19.1 m, on road `887431550`. The board has no text.

## Compound walls

A low wall is built only between two side edges that are 0.45 m to 2.35 m apart. The street edge is left open. Four of those walls were generated for this block. They are not a mapped boundary.
