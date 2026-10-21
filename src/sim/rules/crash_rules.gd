class_name CrashRules
## Decides whether a Plane has hit something fatal this step. A plane that the flight model
## counts as on an airfield is safe on its wheels, but its nose touching the runway is a
## nose-over; everything else that touches the ground, a runway it is not on its wheels on,
## Water or a Border is destroyed, as in the original.

enum Outcome { NONE, TERRAIN, WATER, BORDER }


static func check(s: PlaneState, map: WorldMap) -> Outcome:
	if map.bounds.is_outside(s.position.x):
		return Outcome.BORDER
	if s.on_airfield:
		var airfield := map.airfield_at(s.position.x)
		var surface := (
			airfield.surface_y if airfield != null else map.terrain.height_at(s.nose_point().x)
		)
		return Outcome.TERRAIN if s.nose_point().y <= surface else Outcome.NONE
	var runway := map.airfield_at(s.position.x)
	for point in [s.nose_point(), s.wheel_point(), s.position]:
		if map.terrain.is_below_surface(point):
			return Outcome.WATER if map.terrain.is_water_at(point.x) else Outcome.TERRAIN
		if runway != null and point.y <= runway.surface_y:
			return Outcome.TERRAIN
	return Outcome.NONE
