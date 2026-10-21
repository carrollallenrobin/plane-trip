class_name Needle
extends RefCounted
## The movement of a dial's needle: it eases toward the value it is given rather than
## jumping, so a round fired or a sip of fuel reads as a swing, not a flicker. Pure: a value
## and a time step in, where the needle points out.

## How fast the gap closes, per second.
const RATE := 7.0
## Closer than this is on the mark.
const SNAP := 0.0005

## Where the needle points, in [0, 1].
var shown := 1.0


static func at(value: float) -> Needle:
	var needle := Needle.new()
	needle.shown = clampf(value, 0.0, 1.0)
	return needle


## Move the needle toward the value for dt seconds and return where it points.
func update(value: float, dt: float) -> float:
	var target := clampf(value, 0.0, 1.0)
	shown += (target - shown) * (1.0 - exp(-RATE * dt))
	if absf(target - shown) < SNAP:
		shown = target
	return shown
