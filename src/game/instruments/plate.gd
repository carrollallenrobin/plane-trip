class_name Plate
extends Control
## The riveted olive plate the Instrument Panel's dials and silhouettes sit on: painted metal
## with a lighter bevel and a rivet near every corner and along the long edges. Draws itself;
## its children are laid out by whoever builds it.

const BEVEL := 3.0
const RIVET_RADIUS := 3.0
const RIVET_INSET := 9.0
const RIVET_SPACING := 110.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, UiPalette.OLIVE_DARK)
	draw_rect(rect.grow(-BEVEL), UiPalette.OLIVE)
	draw_rect(rect.grow(-BEVEL), UiPalette.OLIVE_LIGHT, false, 1.0)
	for point in rivet_points(size):
		draw_circle(point, RIVET_RADIUS, UiPalette.RIVET)
		draw_circle(point + Vector2(-0.8, -0.8), RIVET_RADIUS * 0.5, UiPalette.KHAKI)


## Where the rivets go on a plate of this size: the corners and every RIVET_SPACING along
## the top and bottom edges.
static func rivet_points(plate_size: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var x := RIVET_INSET
	while x <= plate_size.x - RIVET_INSET + 0.01:
		points.append(Vector2(x, RIVET_INSET))
		points.append(Vector2(x, plate_size.y - RIVET_INSET))
		x += RIVET_SPACING
	var last := plate_size.x - RIVET_INSET
	if points.is_empty() or not is_equal_approx(points[points.size() - 2].x, last):
		points.append(Vector2(last, RIVET_INSET))
		points.append(Vector2(last, plate_size.y - RIVET_INSET))
	return points
