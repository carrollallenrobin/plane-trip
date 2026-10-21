"""A Flak Gun Ground Target: a heavy anti-aircraft gun on a cruciform carriage, long barrel
raised, with a shield, a low sandbag wall, shell crates and a pennant in the Side's colour.

Built 6 wide (X) and 4 tall (Z); GroundTargetNode scales it uniformly to the target's height.
Origin at the centre of the base on the ground. The barrel points up and towards -X.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from mathutils import Vector  # noqa: E402

from modelkit import SIDE, Builder, materials, run  # noqa: E402

GREY = "FieldGrey"
DARK = "Dark"
SANDBAG = "Sandbag"
WOOD = "Wood"
COLOURS = {
	GREY: (0.42, 0.46, 0.40),
	DARK: (0.10, 0.10, 0.11),
	SANDBAG: (0.64, 0.56, 0.38),
	WOOD: (0.38, 0.25, 0.14),
}

ELEVATION = 65.0
PIVOT = Vector((0.0, 0.0, 1.7))


def build():
	materials(COLOURS)
	b = Builder()
	b.ring((0, 0, 0), 3.2, 2.7, 0.0, 0.6, SANDBAG)
	# Cruciform carriage with outrigger pads, pedestal and turntable.
	b.box((0, 0, 0.2), (5.0, 0.5, 0.4), GREY)
	b.box((0, 0, 0.2), (0.5, 5.0, 0.4), GREY)
	for x, y in ((-2.4, 0), (2.4, 0), (0, -2.4), (0, 2.4)):
		b.box((x, y, 0.1), (0.7, 0.7, 0.2), DARK)
	b.cylinder((0, 0, 0.4), (0, 0, 1.2), 0.7, GREY, sides=8)
	b.cylinder((0, 0, 1.1), (0, 0, 1.3), 1.0, GREY, sides=8)
	b.box((0, 0, 1.55), (1.2, 1.5, 0.5), GREY)
	# Breech, barrel, muzzle brake and the recuperator riding above the barrel.
	angle = math.radians(ELEVATION)
	aim = Vector((-math.cos(angle), 0.0, math.sin(angle)))
	lift = Vector((math.sin(angle), 0.0, math.cos(angle)))
	b.cylinder(PIVOT - aim * 0.8, PIVOT + aim * 0.4, 0.24, DARK, sides=8)
	b.cylinder(PIVOT + aim * 0.4, PIVOT + aim * 3.5, 0.13, GREY, sides=8, end_radius=0.1)
	b.cylinder(PIVOT + aim * 3.4, PIVOT + aim * 3.75, 0.17, DARK, sides=8)
	b.cylinder(PIVOT + lift * 0.32, PIVOT + lift * 0.32 + aim * 1.7, 0.1, GREY, sides=6)
	# Shield facing the line of fire, crew seats either side.
	b.box((-0.95, 0, 2.1), (0.1, 2.6, 1.5), GREY)
	for y in (-0.95, 0.95):
		b.box((0.4, y, 1.45), (0.5, 0.5, 0.1), DARK)
	# Shell crates and the pennant.
	b.box((2.0, -1.6, 0.3), (1.0, 0.5, 0.6), WOOD)
	b.box((2.0, -1.6, 0.9), (1.0, 0.5, 0.6), WOOD)
	b.strut((-2.5, -1.8, 0.6), (-2.5, -1.8, 3.8), DARK)
	b.plate([(-2.5, 3.8), (-1.4, 3.45), (-2.5, 3.1)], 0.06, SIDE, plane="xz", offset=-1.8)
	return [b.to_object("FlakGun")]


if __name__ == "__main__":
	run(build)
