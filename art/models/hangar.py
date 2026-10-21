"""A Hangar Ground Target: an arched corrugated hangar with its sliding doors in the Side's
colour, a ridge vent and a windsock, on a concrete apron.

Built 16 wide (X) and 7 tall (Z), 12 deep, the arch running away from the camera so the
player sees the door end; GroundTargetNode scales it to the target's width and height.
Origin at the centre of the base on the ground.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from modelkit import SIDE, Builder, materials, run  # noqa: E402

SHEET = "Sheet"
CONCRETE = "Concrete"
DARK = "Dark"
SOCK = "Sock"
COLOURS = {
	SHEET: (0.40, 0.43, 0.32),  # olive-drab corrugated sheet
	CONCRETE: (0.62, 0.61, 0.58),
	DARK: (0.12, 0.12, 0.12),
	SOCK: (0.92, 0.45, 0.10),
}

HALF_W = 8.0
WALL = 2.5
HEIGHT = 7.0
DEPTH = 6.0  # half
ARC_SEGMENTS = 8


def arch_outline():
	points = [(-HALF_W, 0.0), (HALF_W, 0.0), (HALF_W, WALL)]
	for i in range(1, ARC_SEGMENTS):
		t = math.pi * i / ARC_SEGMENTS
		points.append((HALF_W * math.cos(t), WALL + (HEIGHT - WALL) * math.sin(t)))
	points.append((-HALF_W, WALL))
	return points


def build():
	materials(COLOURS)
	b = Builder()
	b.box((0, -1.0, 0.1), (HALF_W * 2 + 1.0, DEPTH * 2 + 4.0, 0.2), CONCRETE)
	b.prism(arch_outline(), -DEPTH, DEPTH, SHEET)
	b.box((0, 0, HEIGHT + 0.1), (1.4, DEPTH * 1.6, 0.5), DARK)
	# Two sliding door leaves on a rail, leaving a dark seam between them.
	for sign in (-1, 1):
		b.plate([(sign * 0.15, 0.2), (sign * 5.6, 0.2), (sign * 5.6, 5.2), (sign * 0.15, 5.2)], 0.2, SIDE, plane="xz", offset=-DEPTH - 0.12)
	b.box((0, -DEPTH - 0.2, 5.4), (12.4, 0.36, 0.3), DARK)
	# Windsock at the front corner.
	b.strut((6.8, -DEPTH + 0.8, 0.2), (6.8, -DEPTH + 0.8, 9.2), DARK, width=0.12, depth=0.12)
	b.cylinder((6.8, -DEPTH + 0.8, 9.0), (8.9, -DEPTH + 0.8, 8.7), 0.4, SOCK, sides=8, end_radius=0.15)
	return [b.to_object("Hangar")]


if __name__ == "__main__":
	run(build)
