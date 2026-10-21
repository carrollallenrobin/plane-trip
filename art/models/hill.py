"""Backdrop hills, two variants in one model: a wide low mound (HillA) and a steeper one
(HillB), meadow green with a forest band around the foot. The Hills layer lays them in an
overlapping ridge (BackdropPlan).

Each stands on its origin, the centre of its base. Built sizes, width by height: HillA 100
by 25, HillB 70 by 35; mirrored in BackdropPlan.PIECES.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from modelkit import Builder, materials, run  # noqa: E402

MEADOW = "Meadow"
FOREST = "Forest"
COLOURS = {
	MEADOW: (0.38, 0.54, 0.25),
	FOREST: (0.20, 0.36, 0.17),
}
WOBBLE = (1.0, 0.92, 1.08, 0.95, 1.03, 0.9, 1.06, 0.97, 1.02, 0.94)


def wide():
	b = Builder()
	b.mound([(0, 50, 20), (9, 44, 18), (16, 33, 13), (22, 17, 7), (25, 0, 0)], MEADOW, wobble=WOBBLE)
	b.mound([(0, 51.5, 20.6), (9, 45.3, 18.5)], FOREST, wobble=WOBBLE)
	return b.to_object("HillA")


def steep():
	b = Builder()
	b.mound([(0, 35, 16), (12, 30, 14), (24, 18, 9), (31, 8, 4), (35, 0, 0)], MEADOW, wobble=WOBBLE)
	b.mound([(0, 36.0, 16.5), (12, 30.9, 14.4)], FOREST, wobble=WOBBLE)
	return b.to_object("HillB")


def build():
	materials(COLOURS)
	return [wide(), steep()]


if __name__ == "__main__":
	run(build)
