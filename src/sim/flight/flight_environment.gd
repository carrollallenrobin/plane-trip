class_name FlightEnvironment
extends RefCounted
## What the world tells the flight model about the plane's surroundings for one step.

## Surface height of the runway directly under the plane, or NAN when there is none.
var runway_y := NAN
## Height of the World's Ceiling. INF when the world has none.
var ceiling_y := INF


func has_runway() -> bool:
	return not is_nan(runway_y)
