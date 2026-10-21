"""A Backdrop windmill for the Near layer: a tapered whitewashed tower with a dark cap and a
door, and four lattice sails on a hub, as a second object so the game can turn them. The
sails face the camera (-Y) and turn about Y.

Tower stands on its origin. Built 16 wide (the sails' span) and 24 tall to the sails' top;
mirrored in BackdropPlan.FEATURES. Sails has its origin on the hub.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from mathutils import Vector  # noqa: E402

from modelkit import Builder, materials, run  # noqa: E402

WALL = "Wall"
CAP = "Cap"
DOOR = "Door"
SAIL = "Sail"
COLOURS = {
	WALL: (0.85, 0.82, 0.74),
	CAP: (0.30, 0.25, 0.20),
	DOOR: (0.35, 0.22, 0.12),
	SAIL: (0.40, 0.30, 0.18),
}
HUB = Vector((0, -2.8, 12))
SAIL_LENGTH = 8.0


def tower():
	b = Builder()
	b.mound([(0, 3.2, 3.2), (12, 2.2, 2.2)], WALL, sides=8)
	b.mound([(12, 2.7, 2.7), (12.6, 2.7, 2.7), (16, 0, 0)], CAP, sides=8)
	b.plate([(-0.8, 0.2), (0.8, 0.2), (0.8, 2.6), (-0.8, 2.6)], 0.2, DOOR, offset=-3.1)
	b.cylinder(HUB + Vector((0, 2.4, 0)), HUB, 0.5, CAP, sides=8)
	return b.to_object("Tower")


def sails():
	b = Builder()
	b.cylinder(HUB + Vector((0, 0.3, 0)), HUB + Vector((0, -0.6, 0)), 0.7, SAIL, sides=8)
	for i in range(4):
		a = math.radians(90 * i + 20)
		along = Vector((math.cos(a), 0, math.sin(a)))
		across = Vector((-math.sin(a), 0, math.cos(a)))
		b.strut(HUB, HUB + along * SAIL_LENGTH, SAIL, width=0.3, depth=0.3)
		# The lattice: a thin plate to one side of the spar, from part way out to the tip.
		corners = [HUB + along * r + across * w for r, w in ((1.6, 0.0), (SAIL_LENGTH, 0.0), (SAIL_LENGTH, 1.8), (1.6, 1.8))]
		b.plate([(c.x, c.z) for c in corners], 0.12, SAIL, offset=HUB.y - 0.3)
	return b.to_object("Sails", origin=HUB)


def build():
	materials(COLOURS)
	return [tower(), sails()]


if __name__ == "__main__":
	run(build)
