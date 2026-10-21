class_name Airfield
extends RefCounted
## A stretch of flat ground belonging to a Side where a Plane can land. Only its own Side's
## Airfield rearms a plane.

## A Plane starts this far in from the take-off end of the runway.
const SPAWN_INSET := 10.0

var side: int = Side.RED
var start_x := 0.0
var end_x := 0.0
var surface_y := 0.0
## Planes take off and land heading toward +x when true, toward -x otherwise.
var heading_right := true


static func create(airfield_side: int, from_x: float, to_x: float, height: float) -> Airfield:
	var airfield := Airfield.new()
	airfield.side = airfield_side
	airfield.start_x = minf(from_x, to_x)
	airfield.end_x = maxf(from_x, to_x)
	airfield.surface_y = height
	return airfield


func contains_x(x: float) -> bool:
	return x >= start_x and x <= end_x


func centre_x() -> float:
	return (start_x + end_x) / 2.0


## Where a Plane is placed to start from this Airfield: near the take-off end, resting on its
## wheels.
func spawn_position() -> Vector2:
	var x := start_x + SPAWN_INSET if heading_right else end_x - SPAWN_INSET
	return Vector2(x, surface_y + FlightModel.WHEEL_OFFSET + FlightModel.TYRE_OFFSET)
