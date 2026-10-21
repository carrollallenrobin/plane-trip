class_name FlightInput
extends RefCounted
## The pilot's control state for one simulation step. Pitch is in the plane's own frame:
## "up" pulls the nose toward the wheels-up side, whatever way the plane is rolled.

var pitch_up := false
var pitch_down := false
var thrust := false
var roll := false
var fire := false
var bomb := false


## -1, 0 or 1. Up and down together cancel out (that is the air brake).
func pitch() -> int:
	return int(pitch_up) - int(pitch_down)


func any_pitch() -> bool:
	return pitch_up or pitch_down
