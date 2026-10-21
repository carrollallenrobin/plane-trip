"""A Building Ground Target: a brick depot with a slate gable roof, big sliding door, windows,
chimney and a flag in the Side's colour.

Built 12 wide (X) and 6 tall (Z) to the eaves, 8 deep; GroundTargetNode scales it to the
target's width and height (GroundTargetNode.MODEL_SIZES). Origin at the centre of the base
on the ground; the door faces the camera (-Y).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from modelkit import SIDE, Builder, materials, run  # noqa: E402

BRICK = "Brick"
ROOF = "Roof"
WOOD = "Wood"
GLASS = "Glass"
CONCRETE = "Concrete"
DARK = "Dark"
COLOURS = {
	BRICK: (0.58, 0.30, 0.22),
	ROOF: (0.24, 0.26, 0.30),
	WOOD: (0.38, 0.25, 0.14),
	GLASS: (0.62, 0.78, 0.84),
	CONCRETE: (0.62, 0.61, 0.58),
	DARK: (0.12, 0.12, 0.12),
}

HALF_W = 6.0
EAVE = 4.4
RIDGE = 6.0
DEPTH = 4.0  # half


def build():
	materials(COLOURS)
	b = Builder()
	b.box((0, 0, 0.15), (HALF_W * 2 + 0.6, DEPTH * 2 + 0.6, 0.3), CONCRETE)
	# Walls with gable ends, then two overhanging roof slabs.
	walls = [(-HALF_W, 0.3), (HALF_W, 0.3), (HALF_W, EAVE), (0, RIDGE), (-HALF_W, EAVE)]
	b.prism(walls, -DEPTH, DEPTH, BRICK)
	for sign in (-1, 1):
		slab = [(sign * (HALF_W + 0.5), EAVE - 0.3), (0, RIDGE - 0.1), (0, RIDGE + 0.25), (sign * (HALF_W + 0.5), EAVE + 0.05)]
		b.prism(slab, -DEPTH - 0.4, DEPTH + 0.4, ROOF)
	b.box((3.2, 1.5, RIDGE + 0.4), (0.8, 0.8, 1.8), BRICK)
	# Front: sliding door on its rail, three windows with sills.
	b.box((2.4, -DEPTH - 0.08, 1.9), (3.2, 0.16, 3.2), WOOD)
	b.box((2.4, -DEPTH - 0.14, 3.65), (4.0, 0.12, 0.2), DARK)
	for x in (-4.4, -2.6, -0.8):
		b.box((x, -DEPTH - 0.06, 2.6), (1.1, 0.12, 1.3), GLASS)
		b.box((x, -DEPTH - 0.12, 1.9), (1.3, 0.16, 0.12), CONCRETE)
	# Flag at the front corner.
	b.strut((-5.3, -DEPTH + 0.6, 0.3), (-5.3, -DEPTH + 0.6, 8.2), DARK, width=0.12, depth=0.12)
	b.plate([(-5.3, 8.1), (-3.6, 8.1), (-3.6, 7.1), (-5.3, 7.1)], 0.06, SIDE, plane="xz", offset=-DEPTH + 0.6)
	return [b.to_object("Building")]


if __name__ == "__main__":
	run(build)
