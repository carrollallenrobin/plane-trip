class_name ShellBurst
extends RefCounted
## A flak shell bursting this step at a point. The world applies the Blast to planes nearby.

var position := Vector2.ZERO
var side: int = Side.RED


## Original: 80 within 10 px, else 40 - distance in px within 40 px.
static func damage_at(distance: float) -> int:
	var pixels := distance / SimUnits.PIXEL
	if pixels <= 10.0:
		return 80
	if pixels >= 40.0:
		return 0
	return int(40.0 - pixels)
