"""Backdrop clouds, two variants in one model: a long bank (CloudA) and a small puff
(CloudB), clusters of chunky eight-sided blobs. The Clouds layer scatters them across the
sky (BackdropPlan). A third object, Puff, is one blob 4 wide for the smoke columns and
artillery bursts; the game tints and scales it.

Each is centred on its origin. Built sizes, width by height: CloudA 66 by 30, CloudB 44 by
22; mirrored in BackdropPlan.PIECES.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from mathutils import Vector  # noqa: E402

from modelkit import Builder, circle, materials, run  # noqa: E402

CLOUD = "Cloud"
COLOURS = {CLOUD: (0.96, 0.96, 0.98)}
UP = Vector((0, 0, 1))


def puff(b, centre, r):
	"""A blob: a squat eight-sided ball, flatter underneath."""
	c = Vector(centre)
	rings = [circle(c + Vector((0, 0, dz * r)), UP, k * r, 8) for dz, k in ((-0.5, 0.6), (-0.2, 0.9), (0.15, 1.0), (0.5, 0.8), (0.8, 0.45))]
	b.loft([c + Vector((0, 0, -0.6 * r))] + rings + [c + Vector((0, 0, 0.95 * r))], CLOUD)


def bank():
	b = Builder()
	for centre, r in (((-18, 0, 0), 11), ((0, 2, 2), 14), ((16, -1, 0), 12), ((28, 0, -2), 8), ((-8, 3, 6), 9), ((8, -3, 7), 9)):
		puff(b, centre, r)
	return b.to_object("CloudA")


def small():
	b = Builder()
	for centre, r in (((-12, 0, 0), 9), ((2, 1, 1), 11), ((14, 0, -1), 8), ((-2, 2, 5), 7)):
		puff(b, centre, r)
	return b.to_object("CloudB")


def single():
	b = Builder()
	puff(b, (0, 0, 0), 2)
	return b.to_object("Puff")


def build():
	materials(COLOURS)
	return [bank(), small(), single()]


if __name__ == "__main__":
	run(build)
