"""Backdrop trees, three variants in one model: a fir (TreeA), a round broadleaf (TreeB) and
a tall poplar (TreeC). The Near layer and the terrain slab scatter them (BackdropPlan).

Each stands on its origin. Built sizes, width by height: TreeA 5.2 by 8.5, TreeB 7.6 by 7.2,
TreeC 3.2 by 12; mirrored in BackdropPlan.PIECES.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from mathutils import Vector  # noqa: E402

from modelkit import Builder, circle, materials, run  # noqa: E402

BARK = "Bark"
FIR = "Fir"
LEAF = "Leaf"
COLOURS = {
	BARK: (0.30, 0.20, 0.12),
	FIR: (0.16, 0.34, 0.18),
	LEAF: (0.30, 0.50, 0.22),
}
UP = Vector((0, 0, 1))


def ring(z, radius, sides=8):
	return circle(Vector((0, 0, z)), UP, radius, sides)


def fir():
	b = Builder()
	b.cylinder((0, 0, 0), (0, 0, 2.5), 0.3, BARK, sides=6)
	for bottom, top, radius in ((1.5, 4.5, 2.6), (3.5, 6.5, 2.0), (5.5, 8.5, 1.3)):
		b.loft([ring(bottom, radius), Vector((0, 0, top))], FIR)
	return b.to_object("TreeA")


def broadleaf():
	b = Builder()
	b.cylinder((0, 0, 0), (0, 0, 3.0), 0.35, BARK, sides=6)
	b.loft([ring(2.6, 1.2), ring(3.8, 3.4), ring(5.0, 3.8), ring(6.3, 3.0), Vector((0, 0, 7.2))], LEAF)
	return b.to_object("TreeB")


def poplar():
	b = Builder()
	b.cylinder((0, 0, 0), (0, 0, 2.0), 0.25, BARK, sides=6)
	b.loft([ring(1.5, 0.6), ring(4.0, 1.6), ring(8.0, 1.6), ring(10.5, 0.9), Vector((0, 0, 12.0))], LEAF)
	return b.to_object("TreeC")


def build():
	materials(COLOURS)
	return [fir(), broadleaf(), poplar()]


if __name__ == "__main__":
	run(build)
