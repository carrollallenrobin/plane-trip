"""A Bomb: a finned drop bomb, nose along +X, 1.6 long (the box it replaces in
ProjectilesNode) and 0.5 across. Olive body, a yellow band at the nose, dark fins and fuze.
No Side material: a Bomb in flight is drawn in a MultiMesh with the model's own colours, and
the one hanging under a plane looks the same.

Origin at the body's centre, which is the simulation's Bomb position.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from mathutils import Vector  # noqa: E402

from modelkit import Builder, circle, materials, run  # noqa: E402

OLIVE = "Olive"
DARK = "Dark"
BAND = "Band"
COLOURS = {
	OLIVE: (0.30, 0.33, 0.24),
	DARK: (0.12, 0.12, 0.13),
	BAND: (0.90, 0.75, 0.20),
}

AXIS = Vector((1, 0, 0))
# Rings along X: (x, radius), a point at each end.
BODY = [(-0.80, 0.0), (-0.70, 0.10), (-0.45, 0.22), (0.30, 0.25), (0.60, 0.17), (0.80, 0.0)]
FIN = [(-0.80, 0.0), (-0.80, 0.48), (-0.48, 0.28), (-0.48, 0.0)]


def ring(x, radius):
	if radius == 0.0:
		return Vector((x, 0, 0))
	return circle(Vector((x, 0, 0)), AXIS, radius, 8)


def build():
	materials(COLOURS)
	b = Builder()
	b.loft([ring(x, r) for x, r in BODY], OLIVE)
	b.cylinder((0.18, 0, 0), (0.34, 0, 0), 0.26, BAND, sides=8)
	b.cylinder((0.78, 0, 0), (0.90, 0, 0), 0.05, DARK, sides=6)  # fuze
	# Four fins: one plate through the body for the vertical pair, one for the horizontal.
	up = FIN + [(x, -z) for x, z in reversed(FIN[1:-1])]
	b.plate(up, 0.04, DARK, plane="xz")
	b.plate(up, 0.04, DARK, plane="xy")
	return [b.to_object("Bomb")]


if __name__ == "__main__":
	run(build)
