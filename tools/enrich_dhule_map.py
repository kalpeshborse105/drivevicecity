"""
enrich_dhule_map.py
====================
Reads  assets/maps/dhule_pois_overpass.json  (fetched from Overpass API)
and   assets/maps/dhule_roads_game.json      (existing game map)

Outputs an enriched  dhule_roads_game.json  with:
  - real named buildings placed at correct lat/lon → game-XZ
  - real POIs (shops, amenities, hospitals, colleges, etc.)
  - named road signs patched with actual OSM name tags

Run:
    python tools/enrich_dhule_map.py
"""

import json, math, sys, re, os

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
BASE = "D:/drivevicecity"
OVERPASS_JSON = f"{BASE}/assets/maps/dhule_pois_overpass.json"
GAME_JSON     = f"{BASE}/assets/maps/dhule_roads_game.json"
OUT_JSON      = f"{BASE}/assets/maps/dhule_roads_game.json"  # overwrite in-place
BACKUP_JSON   = f"{BASE}/assets/maps/dhule_roads_game_bak.json"

# ---------------------------------------------------------------------------
# Lat/lon → game-XZ (same projection as the Python OSM pipeline)
#   origin = 20.902, 74.777  (from dhule_roads_game.json header)
#   x  = (lon - origin_lon) * meters_per_degree_lon
#   z  = -(lat - origin_lat) * meters_per_degree_lat   (Godot z grows south)
# ---------------------------------------------------------------------------
ORIGIN_LAT = 20.902
ORIGIN_LON = 74.777
R_EARTH    = 6_371_000.0

def lat_lon_to_xz(lat: float, lon: float):
    lat_m = R_EARTH * math.radians(1.0)
    lon_m = R_EARTH * math.cos(math.radians(ORIGIN_LAT)) * math.radians(1.0)
    x = (lon - ORIGIN_LON) * lon_m
    z = -(lat - ORIGIN_LAT) * lat_m
    return round(x, 2), round(z, 2)

CLIP_R = 1600.0  # metres — same as the existing game clip radius

def in_clip(x, z):
    return math.sqrt(x*x + z*z) <= CLIP_R * 1.05  # 5 % margin

# ---------------------------------------------------------------------------
# Amenity / shop → game POI kind mapping
# ---------------------------------------------------------------------------
AMENITY_KIND = {
    "hospital": "hospital", "clinic": "hospital", "doctors": "hospital",
    "pharmacy": "medical", "dentist": "medical",
    "school": "school", "college": "school", "university": "school",
    "library": "school",
    "place_of_worship": "temple", "temple": "temple",
    "bank": "bank", "atm": "bank",
    "police": "police",
    "fire_station": "fire_station",
    "bus_station": "bus_station", "bus_stop": "bus_station",
    "marketplace": "marketplace", "market": "marketplace",
    "restaurant": "restaurant", "fast_food": "restaurant",
    "cafe": "cafe", "bar": "cafe",
    "fuel": "fuel",
    "post_office": "post_office",
    "cinema": "cinema", "theatre": "cinema",
    "park": "park", "playground": "park",
    "blood_bank": "hospital",
    "courthouse": "government", "government": "government",
    "community_centre": "community",
}
SHOP_KIND = {
    "supermarket": "market", "grocery": "market",
    "convenience": "market", "general": "market",
    "car_parts": "auto", "tyres": "auto", "fuel": "auto",
    "clothes": "clothes", "tailor": "clothes",
    "electronics": "electronics", "mobile": "electronics",
    "hardware": "hardware", "tools": "hardware",
    "pharmacy": "medical", "medical_supply": "medical",
    "beauty": "salon", "hairdresser": "salon",
    "bakery": "food", "sweet": "food", "confectionery": "food",
    "newsagent": "market",
    "jewellery": "jewellery", "gold": "jewellery",
    "furniture": "furniture",
    "books": "books", "stationery": "books",
    "optician": "optical",
}
BUILDING_KIND = {
    "hospital": "hospital", "clinic": "hospital",
    "school": "school", "college": "school", "university": "school",
    "church": "temple", "temple": "temple", "mosque": "temple",
    "government": "government", "courthouse": "government",
    "retail": "commercial", "commercial": "commercial",
    "residential": "residential",
    "yes": "yes",
}

def clean_name(n: str) -> str:
    n = n.strip()
    # Remove very long descriptions (keep first sentence or 50 chars)
    if len(n) > 60:
        n = n[:60].rsplit(" ", 1)[0] + "…"
    return n

# ---------------------------------------------------------------------------
# Load files
# ---------------------------------------------------------------------------
print("Loading game JSON …")
with open(GAME_JSON, encoding="utf-8") as f:
    game = json.load(f)

print("Loading Overpass JSON …")
with open(OVERPASS_JSON, encoding="utf-8") as f:
    overpass = json.load(f)

# Back up original
with open(BACKUP_JSON, "w", encoding="utf-8") as f:
    json.dump(game, f, ensure_ascii=False)
print(f"Backed up original to {BACKUP_JSON}")

elems = overpass.get("elements", [])
print(f"Overpass elements: {len(elems)}")

# ---------------------------------------------------------------------------
# Build new POI list from existing + Overpass
# ---------------------------------------------------------------------------
existing_pois = {p["name"].lower(): p for p in game.get("pois", []) if p.get("name")}
new_pois = {}

stats = {"nodes": 0, "ways": 0, "skipped": 0, "added_pois": 0, "added_bld": 0}

for elem in elems:
    tags = elem.get("tags", {})
    name = tags.get("name", "").strip()
    if not name:
        continue

    etype = elem.get("type", "")

    # Get coordinates
    if etype == "node":
        lat, lon = elem.get("lat"), elem.get("lon")
    elif etype == "way":
        center = elem.get("center", {})
        lat, lon = center.get("lat"), center.get("lon")
    else:
        stats["skipped"] += 1
        continue

    if lat is None or lon is None:
        stats["skipped"] += 1
        continue

    x, z = lat_lon_to_xz(lat, lon)
    if not in_clip(x, z):
        stats["skipped"] += 1
        continue

    # Determine kind
    amenity = tags.get("amenity", "")
    shop    = tags.get("shop", "")
    building= tags.get("building", "")
    office  = tags.get("office", "")
    tourism = tags.get("tourism", "")

    kind = "landmark"
    if amenity:
        kind = AMENITY_KIND.get(amenity, "landmark")
    elif shop:
        kind = SHOP_KIND.get(shop, "market")
    elif building and building != "yes":
        kind = BUILDING_KIND.get(building, "commercial")
    elif office:
        kind = "office"
    elif tourism:
        kind = "tourism"

    poi = {"name": clean_name(name), "kind": kind, "x": x, "z": z}

    # Only add each unique name once (prefer first occurrence)
    key = name.lower()
    if key not in new_pois and key not in existing_pois:
        new_pois[key] = poi
        stats["added_pois"] += 1

    if etype == "node":
        stats["nodes"] += 1
    else:
        stats["ways"] += 1

# Merge: existing first, then new
merged_pois = list(existing_pois.values()) + list(new_pois.values())
game["pois"] = merged_pois
print(f"POIs: {len(existing_pois)} existing + {stats['added_pois']} new = {len(merged_pois)} total")

# ---------------------------------------------------------------------------
# Enrich buildings: add "name" field to buildings near real named-way footprints
# ---------------------------------------------------------------------------
# Build a list of real named buildings from Overpass (ways with building + name)
real_named = []
for elem in elems:
    tags = elem.get("tags", {})
    name = tags.get("name", "").strip()
    if not name:
        continue
    if elem.get("type") != "way":
        continue
    if "building" not in tags:
        continue
    center = elem.get("center", {})
    lat, lon = center.get("lat"), center.get("lon")
    if lat is None or lon is None:
        continue
    x, z = lat_lon_to_xz(lat, lon)
    if not in_clip(x, z):
        continue
    bkind = BUILDING_KIND.get(tags.get("building", "yes"), "commercial")
    real_named.append({"name": clean_name(name), "kind": bkind, "x": x, "z": z,
                        "w": 20.0, "d": 14.0, "h": 10.0})

print(f"Real named building footprints from OSM: {len(real_named)}")

# Merge into buildings list — deduplicate by proximity (> 15 m apart)
existing_bld = game.get("buildings", [])

def dist2d(a, b):
    return math.sqrt((a["x"] - b["x"])**2 + (a["z"] - b["z"])**2)

added_bld = 0
for rb in real_named:
    # Check it doesn't already exist
    too_close = any(dist2d(rb, eb) < 15.0 for eb in existing_bld)
    if not too_close:
        existing_bld.append(rb)
        added_bld += 1

game["buildings"] = existing_bld
print(f"Buildings: added {added_bld} real named → {len(existing_bld)} total")

# ---------------------------------------------------------------------------
# Enrich roads: patch empty name fields using dhule_clip.osm.xml road names
# ---------------------------------------------------------------------------
# Build a road-name lookup from the fuller dhule_roads.osm.json
road_json_path = f"{BASE}/assets/maps/dhule_roads.osm.json"
road_name_by_id = {}
try:
    with open(road_json_path, encoding="utf-8") as f:
        raw_roads = json.load(f)
    for e in raw_roads.get("elements", []):
        rid = e.get("id")
        rname = e.get("tags", {}).get("name", "")
        if rid and rname:
            road_name_by_id[rid] = rname
    print(f"Road names from OSM: {len(road_name_by_id)} named ways")
except Exception as ex:
    print(f"Could not load road names: {ex}")

patched_roads = 0
for road in game.get("roads", []):
    if not road.get("name"):
        rid = road.get("id")
        if rid and rid in road_name_by_id:
            road["name"] = road_name_by_id[rid]
            patched_roads += 1
print(f"Road name patches: {patched_roads}")

# ---------------------------------------------------------------------------
# Update metadata
# ---------------------------------------------------------------------------
game["source"] = game.get("source", "") + "+overpass-enriched-v2"
game["poi_count"]      = len(merged_pois)
game["building_count"] = len(existing_bld)

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------
with open(OUT_JSON, "w", encoding="utf-8") as f:
    json.dump(game, f, ensure_ascii=False, separators=(",", ":"))
size_kb = os.path.getsize(OUT_JSON) / 1024
print(f"\n✅  Saved enriched map → {OUT_JSON}  ({size_kb:.1f} KB)")
print(f"   POIs   : {len(merged_pois)}")
print(f"   Buildings: {len(existing_bld)}")
print(f"   Roads  : {game.get('road_count', '?')}")
print(f"   Named roads patched: {patched_roads}")

