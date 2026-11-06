extends RefCounted
## Explicit roadside placement rules. Nothing in here runs during a road rebuild.
## A caller must pass the carriageway polylines and the building footprints.

const ROAD_CLEAR_M := 1.6
const BUILDING_CLEAR_M := 1.2


static func allows(pos: Vector2, roads: Array, footprints: Array) -> bool:
	if _near_carriageway(pos, roads):
		return false
	if _inside_footprint(pos, footprints):
		return false
	return true


static func _near_carriageway(pos: Vector2, roads: Array) -> bool:
	for road_v in roads:
		var road: Dictionary = road_v
		var width := float(road.get("width", 7.0))
		var pts: Array = road.get("points", [])
		for i in pts.size() - 1:
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			if _point_segment(pos, a, b) < width * 0.5 + ROAD_CLEAR_M:
				return true
	return false


static func _inside_footprint(pos: Vector2, footprints: Array) -> bool:
	for poly_v in footprints:
		var poly: PackedVector2Array = poly_v
		if poly.size() >= 3 and Geometry2D.is_point_in_polygon(pos, poly):
			return true
	return false


static func _point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var den := ab.length_squared()
	var t := 0.0 if den == 0.0 else clampf((p - a).dot(ab) / den, 0.0, 1.0)
	return p.distance_to(a + ab * t)
