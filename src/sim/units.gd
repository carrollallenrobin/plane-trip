class_name SimUnits
## Conversions between the original Triplane Classic integer units and this project's metres,
## seconds and degrees. The original ran at 24 ticks per second with positions in pixels and
## speed in units of 1/1024 pixel per tick. See docs/research/triplane-classic-mechanics.md
## and ADR 0002.

## Metres per original pixel. A 20 px plane is 8 m long.
const PIXEL := 0.4
## Seconds per original simulation tick.
const TICK := 1.0 / 24.0
## Metres per second for one original speed unit (speed / 1024 px per tick).
const SPEED_UNIT := PIXEL / 1024.0 / TICK


static func speed_from_original(units: float) -> float:
	return units * SPEED_UNIT


static func speed_to_original(metres_per_second: float) -> float:
	return metres_per_second / SPEED_UNIT


static func length_from_original(pixels: float) -> float:
	return pixels * PIXEL
