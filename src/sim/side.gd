class_name Side
## One of the two factions in a Mission. Every Plane, Airfield and Ground Target has one.

enum { RED, BLUE }


static func display_name(side: int) -> String:
	return "Red" if side == RED else "Blue"


## The Side's colour on planes, flags and markers.
static func colour(side: int) -> Color:
	return Color(0.85, 0.2, 0.2) if side == RED else Color(0.25, 0.35, 0.9)
