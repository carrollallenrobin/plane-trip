class_name WorldMap
extends RefCounted
## The static layout of a World for the simulation: bounds, terrain and airfields.
## Ground targets and planes live elsewhere; this is what the flight model and the crash
## rules query every step.

var bounds := WorldBounds.new()
var terrain := Terrain.new()
var airfields: Array[Airfield] = []


## The airfield under this horizontal position, or null.
func airfield_at(x: float) -> Airfield:
	for airfield in airfields:
		if airfield.contains_x(x):
			return airfield
	return null


## What the flight model needs to know about the surroundings of a plane at x.
func environment_at(x: float) -> FlightEnvironment:
	var env := FlightEnvironment.new()
	env.ceiling_y = bounds.ceiling_y
	var airfield := airfield_at(x)
	if airfield != null:
		env.runway_y = airfield.surface_y
	return env


func home_airfield(side: int) -> Airfield:
	for airfield in airfields:
		if airfield.side == side:
			return airfield
	return null
