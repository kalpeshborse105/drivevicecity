# 44 — Building variation

The repeated blocks in the production view are the Blosm city mesh. This pass did not replace it. `scenes/main.tscn` still instances `assets/models/environments/dhule_blosm_city.glb`.

The spawn prototype from the previous phase is still the place where footprints are individual. Those 16 ways keep their OSM rings and way ids. Four are one-floor houses at an estimated 3.55 m. Twelve are two-floor houses at an estimated 6.25 m. None of them has a shop tag, so none has a shutter or a business name. Heights remain estimates.

A city-wide restyle was not built. One draw and one physics body per building is already known to be too heavy on this GPU (doc 35: about 2,499 draws). The prototype batches 16 shells into one mesh. Extending that to the whole city means chunks, with the way id stored beside the mesh, and it should happen only after the Blosm mesh is deliberately retired.

No new building screenshot was taken in this pass. The production frame `docs/qa/43-production.png` still shows the Blosm blocks, with the home panel open.
