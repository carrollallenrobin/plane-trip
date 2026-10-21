"""The ruin a destroyed Ground Target leaves: a cracked slab, two broken brick wall stubs,
charred rubble and fallen beams. No Side material; a ruin belongs to nobody.

Built 12 wide (X); GroundTargetNode scales it along X to the target's width and leaves the
height alone. Origin at the centre of the base on the ground.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from modelkit import Builder, materials, run  # noqa: E402

BRICK = "Brick"
CHARRED = "Charred"
CONCRETE = "Concrete"
COLOURS = {
	BRICK: (0.42, 0.23, 0.18),
	CHARRED: (0.14, 0.13, 0.12),
	CONCRETE: (0.42, 0.41, 0.39),
}


def build():
	materials(COLOURS)
	b = Builder()
	b.box((0, 0, 0.1), (12.0, 8.0, 0.2), CONCRETE)
	# Wall stubs with jagged tops, front left and back right.
	b.prism([(-6.0, 0.1), (-3.4, 0.1), (-3.4, 0.9), (-4.4, 1.7), (-5.2, 1.1), (-6.0, 2.2)], -3.9, -3.3, BRICK)
	b.prism([(2.4, 0.1), (6.0, 0.1), (6.0, 1.5), (4.9, 0.9), (3.7, 1.9), (2.4, 0.7)], 3.3, 3.9, BRICK)
	# Rubble: turned blocks, brick and charred, and two fallen beams.
	rubble = [
		((-2.6, -1.8, 0.5), (1.6, 1.2, 0.8), BRICK, 20, 0),
		((-0.4, 0.8, 0.45), (1.8, 1.4, 0.7), CHARRED, -35, 0),
		((1.6, -2.2, 0.4), (1.3, 1.0, 0.6), CHARRED, 50, 0),
		((3.4, 1.4, 0.55), (1.5, 1.3, 0.9), BRICK, -10, 0),
		((-4.2, 1.9, 0.35), (1.1, 0.9, 0.5), CHARRED, 65, 0),
		((0.9, 2.4, 0.3), (1.0, 0.8, 0.4), BRICK, 40, 0),
		((-1.5, -0.6, 0.9), (4.5, 0.3, 0.3), CHARRED, 15, -20),
		((2.6, -0.4, 0.8), (3.8, 0.3, 0.3), CHARRED, -60, 25),
	]
	for centre, size, material, yaw, pitch in rubble:
		b.block(centre, size, material, yaw=yaw, pitch=pitch)
	return [b.to_object("Ruin")]


if __name__ == "__main__":
	run(build)
