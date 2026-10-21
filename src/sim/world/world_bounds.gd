class_name WorldBounds
extends RefCounted
## The extent of a World: Borders at x = 0 and x = width, the Ceiling at ceiling_y.

var width := 960.0
var ceiling_y := 160.0


static func create(world_width: float, ceiling: float) -> WorldBounds:
	var bounds := WorldBounds.new()
	bounds.width = world_width
	bounds.ceiling_y = ceiling
	return bounds


func is_outside(x: float) -> bool:
	return x < 0.0 or x > width
