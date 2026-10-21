"""A Backdrop factory for the Hills layer: a long brick shed with a sawtooth roof, a row
of windows and a door facing the camera (-Y), and a tall chimney whose top the game feeds
a smoke column from.

Stands on its origin, the centre of the shed's base. Built 36 wide and 24 tall to the
chimney's top, which is at x = 14; mirrored in BackdropPlan.FEATURES.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from modelkit import Builder, materials, run  # noqa: E402

BRICK = "Brick"
ROOF = "Roof"
GLASS = "Glass"
DOOR = "Door"
SOOT = "Soot"
COLOURS = {
	BRICK: (0.55, 0.32, 0.24),
	ROOF: (0.30, 0.31, 0.34),
	GLASS: (0.62, 0.78, 0.84),
	DOOR: (0.25, 0.22, 0.20),
	SOOT: (0.22, 0.20, 0.20),
}
HALF_W = 18.0
HALF_D = 7.0
EAVE = 7.0
TOOTH = 9.0
GLASS_PROUD = 0.1
CHIMNEY_X = 14.0
CHIMNEY_TOP = 24.0


def build():
	materials(COLOURS)
	b = Builder()
	b.box((0, 0, EAVE / 2), (HALF_W * 2, HALF_D * 2, EAVE), BRICK)
	x = -HALF_W
	while x < HALF_W - 0.1:
		b.prism([(x, EAVE), (x + TOOTH, EAVE), (x + TOOTH, EAVE + 3.5)], -HALF_D, HALF_D, ROOF)
		# The glass stands proud of the tooth's vertical face: on the same plane, the two
		# fought over every pixel at the depth the factory sits at.
		b.plate([(x + TOOTH - 0.2, EAVE), (x + TOOTH + GLASS_PROUD, EAVE), (x + TOOTH + GLASS_PROUD, EAVE + 3.3), (x + TOOTH - 0.2, EAVE + 3.3)], HALF_D * 2 - 0.4, GLASS, plane="xz", offset=0.0)
		x += TOOTH
	for wx in (-14, -10, -6, 2, 6, 10, 14):
		b.plate([(wx - 1.2, 3.0), (wx + 1.2, 3.0), (wx + 1.2, 5.5), (wx - 1.2, 5.5)], 0.2, GLASS, offset=-HALF_D - 0.05)
	b.plate([(-3.0, 0.1), (-1.0, 0.1), (-1.0, 4.0), (-3.0, 4.0)], 0.2, DOOR, offset=-HALF_D - 0.05)
	b.cylinder((CHIMNEY_X, 0, EAVE - 0.5), (CHIMNEY_X, 0, CHIMNEY_TOP - 1.5), 1.5, BRICK, sides=8, end_radius=1.1)
	b.cylinder((CHIMNEY_X, 0, CHIMNEY_TOP - 1.5), (CHIMNEY_X, 0, CHIMNEY_TOP), 1.3, SOOT, sides=8)
	return [b.to_object("Factory")]


if __name__ == "__main__":
	run(build)
