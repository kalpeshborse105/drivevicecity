# 45 — Landmarks and vehicle paint

## Landmarks

The seven requested places were checked against `assets/maps/dhule_city.osm` and `assets/maps/dhulemap.osm`.

| Place | In the playable OSM |
| --- | --- |
| Paanch Kandil market junction | No named node or way |
| Granth Bhavan | No |
| Mahadev Statue / Hanging Bridge | No |
| Rajwade Research Institute | No |
| Netaji Subhash Chandra Bose Statue | No |
| Veer Savarkar Statue | No. `Veer Savarkar Marg` is a road name already in the road set |
| New Swaminarayan Temple | No |

No model was placed. A position that is not in the map extract would be an invented landmark.

## Paint

Body colour was being blended onto every bright surface, so a light kit became one colour. Glass, tyres, lights, seats, and the dash now keep the material that came with the model. Chrome, mirrors, and bumpers stay a separate metal. Only a body, paint, primary, or chassis surface, or an otherwise unnamed bright panel, takes the selected colour.

The palette is white, black, silver, grey, red, blue, dark blue, green, brown, and yellow. Index 0 is white, which is what the production HUD showed (`Carnival · White`).

Red paint on three kits, counted from the surface override:

| Vehicle | Surfaces turned red | Protected surfaces that turned red |
| --- | ---: | ---: |
| Carnival | 142 | 0 |
| Tata Safari | 123 | 0 |
| Camry | 62 | 0 |

Driving forces, gears, and steering were not changed. The profile still sets its own force and top speed when the vehicle is swapped. That path was left as it was.
