"""An Anti-Aircraft Gun Ground Target: a quad light gun on a pedestal inside a ring of
sandbags, with ammunition crates and a pennant in the Side's colour.

Built 6 wide (X) and 4 tall (Z); GroundTargetNode scales it uniformly to the target's height.
Origin at the centre of the base on the ground. The barrels point up and towards -X.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from mathutils import Vector  # noqa: E402

from modelkit import SIDE, Builder, materials, run  # noqa: E402

GUNMETAL = "Gunmetal"
DARK = "Dark"
SANDBAG = "Sandbag"
WOOD = "Wood"
COLOURS = {
	GUNMETAL: (0.30, 0.32, 0.30),
	DARK: (0.10, 0.10, 0.11),
	SANDBAG: (0.64, 0.56, 0.38),
	WOOD: (0.38, 0.25, 0.14),
}

ELEVATION = 55.0
MOUNT = Vector((0.0, 0.0, 1.5))


def build():
	materials(COLOURS)
	b = Builder()
	# Two courses of sandbags, the upper turned half a bag.
	b.ring((0, 0, 0), 3.0, 2.3, 0.0, 0.5, SANDBAG)
	b.ring((0, 0, 0), 2.9, 2.35, 0.5, 1.0, SANDBAG, turn=22.5)
	# Pedestal mount and cradle.
	b.cylinder((0, 0, 0), (0, 0, 0.2), 1.0, GUNMETAL, sides=8)
	b.cylinder((0, 0, 0.2), (0, 0, 1.0), 0.4, GUNMETAL, sides=8)
	b.box((0, 0, 1.3), (0.9, 1.0, 0.7), GUNMETAL)
	b.box((0.7, 0, 1.55), (0.45, 0.45, 0.1), DARK)  # gunner's seat
	# Four barrels in a square, each with a breech and a magazine.
	angle = math.radians(ELEVATION)
	aim = Vector((-math.cos(angle), 0.0, math.sin(angle)))
	lift = Vector((math.sin(angle), 0.0, math.cos(angle)))
	for dy in (-0.3, 0.3):
		for du in (-0.22, 0.22):
			root = MOUNT + Vector((0, dy, 0)) + lift * du
			b.cylinder(root - aim * 0.5, root + aim * 0.2, 0.13, GUNMETAL, sides=6)
			b.cylinder(root + aim * 0.2, root + aim * 2.1, 0.06, DARK, sides=6)
			b.cylinder(root + aim * 2.0, root + aim * 2.2, 0.09, DARK, sides=6)
	# Ammunition crates stacked by the wall, and the pennant.
	b.box((-1.6, -1.2, 0.25), (0.9, 0.5, 0.5), WOOD)
	b.box((-1.6, -1.2, 0.75), (0.9, 0.5, 0.5), WOOD)
	b.strut((2.5, -1.6, 0.6), (2.5, -1.6, 3.6), DARK)
	b.plate([(2.5, 3.6), (3.6, 3.25), (2.5, 2.9)], 0.06, SIDE, plane="xz", offset=-1.6)
	return [b.to_object("AntiAircraftGun")]


if __name__ == "__main__":
	run(build)
