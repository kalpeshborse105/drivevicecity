extends RefCounted
## Phase 2H.2 — three visual style variants for unclassified Dhule houses.
## These are facade variants only. They do not claim OSM identity.


## Canonical style keys used by the prototype and docs.
const STYLE_A := "plastered_house" ## Simple plastered Indian house, flat RCC roof.
const STYLE_B := "narrow_urban" ## Narrow frontage, estimated two-level facade.
const STYLE_C := "traditional_compact" ## Compact one-storey plaster cottage.

## Maps prototype style → building_shell.gd internal style.
const SHELL_MAP := {
	STYLE_A: "family",
	STYLE_B: "row",
	STYLE_C: "cottage",
}


static func shell_style(style_key: String) -> String:
	return str(SHELL_MAP.get(style_key, "family"))


static func choose(area_m2: float, span_min_m: float, span_max_m: float, osm_id: String) -> String:
	## Visual assignment from plan shape only — not from name or invented type.
	## Truly narrow deep plots → B. Under ~72 m² → C. Remaining A with a stable C mix.
	var aspect := span_max_m / maxf(span_min_m, 0.01)
	var narrow := span_min_m < 8.4 and aspect >= 1.45
	if area_m2 < 72.0:
		return STYLE_C
	if narrow:
		return STYLE_B
	# Stable mix among wider plots so the block shows A and C facades.
	var bucket := absi(int(osm_id)) % 4
	if bucket == 0:
		return STYLE_C
	if bucket == 1 and span_min_m < 9.0:
		return STYLE_B
	return STYLE_A


static func estimated_floors(style_key: String, area_m2: float) -> int:
	## Conservative estimates when OSM has no building:levels / height.
	## Never random. Documented in docs/55.
	match style_key:
		STYLE_C:
			return 1
		STYLE_B:
			return 2 if area_m2 >= 70.0 else 1
		_:
			return 2 if area_m2 >= 72.0 else 1


static func describe(style_key: String) -> String:
	match style_key:
		STYLE_A:
			return "Urban family: 1–2 storeys, plaster + plinth, recessed grilled windows, chajja, optional balcony/tank, RCC parapet"
		STYLE_B:
			return "Narrow urban: tight frontage, vertical openings, entrance + compact balcony when clear, parapet posts"
		STYLE_C:
			return "Compact residential: 1 storey estimate, plaster, door lintel, small grilled windows, slab roof, selective tank"
		_:
			return style_key
