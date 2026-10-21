"""Backdrop mountains, two variants in one model: one peak (MountainA) and a twin peak
(MountainB), grey rock with snow caps and a green foot. The Mountains layer lays them in an
overlapping range tall enough to top the Ceiling (BackdropPlan).

Each stands on its origin, the centre of its base. Built sizes, width by height: MountainA
300 by 300, MountainB 420 by 230; mirrored in BackdropPlan.PIECES.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from modelkit import Builder, materials, run  # noqa: E402

ROCK = "Rock"
SNOW = "Snow"
FOOT = "Foot"
COLOURS = {
	ROCK: (0.38, 0.36, 0.42),
	SNOW: (0.92, 0.94, 0.97),
	FOOT: (0.34, 0.44, 0.30),
}
WOBBLE = (1.0, 0.9, 1.1, 0.94, 1.05, 0.88, 1.08, 0.96, 1.03, 0.92)


def peak(b, centre, half_width, height, snow_from):
	"""One faceted peak: a green foot, rock above it, snow from snow_from up."""
	w, d = half_width, half_width * 0.3
	levels = [
		(0, w, d),
		(height * 0.27, w * 0.8, d * 0.8),
		(height * 0.54, w * 0.53, d * 0.55),
		(height * 0.77, w * 0.27, d * 0.3),
		(height * 0.9, w * 0.12, d * 0.15),
		(height, 0, 0),
	]
	b.mound(levels, ROCK, centre=centre, wobble=WOBBLE)
	# The foot and the cap are shells over the rock, 3% proud so they never fight it for depth.
	b.mound([(0, w * 1.03, d * 1.03), (height * 0.27, w * 0.83, d * 0.83)], FOOT, centre=centre, wobble=WOBBLE)
	cap = [(z, rx * 1.03, ry * 1.03) for z, rx, ry in levels if z >= snow_from and rx > 0]
	b.mound(cap + [(height + 0.5, 0, 0)], SNOW, centre=centre, wobble=WOBBLE)


def single():
	b = Builder()
	peak(b, (0, 0, 0), 150, 300, 230)
	return b.to_object("MountainA")


def twin():
	b = Builder()
	peak(b, (-100, 0, 0), 130, 230, 170)
	peak(b, (110, 0, 0), 100, 185, 140)
	return b.to_object("MountainB")


def build():
	materials(COLOURS)
	return [single(), twin()]


if __name__ == "__main__":
	run(build)
