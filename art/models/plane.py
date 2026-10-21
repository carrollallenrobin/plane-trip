"""The plane model: a Fokker Dr.I-like triplane, the nod to the original.

Run headless:  blender -b --python art/models/plane.py -- assets/models/plane.glb
(scripts/build-models.sh does this for every script in art/models/.)

Nose along +X, span along Y, up +Z; see art/modelkit.py for the frame. The origin is the
simulation's plane position; the wheels hang FlightModel.WHEEL_OFFSET below it and the
length is FlightModel.HIT_BOX_LENGTH. Two objects come out: "Airframe" and "Propeller", the
latter with its origin on the hub so PlaneNode can spin it about X. The fuselage, wings and
tail wear the Side material and take the Side's colour in the game.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from mathutils import Vector  # noqa: E402

from modelkit import SIDE, Builder, airfoil_section, circle, materials, rect, run  # noqa: E402

DARK = "Dark"
CANOPY = "Canopy"
PROP = "Prop"
COLOURS = {
	DARK: (0.10, 0.10, 0.11),  # struts, wheels, guns, cockpit
	CANOPY: (0.70, 0.86, 0.95),
	PROP: (0.46, 0.29, 0.15),
}

# Fuselage stations (x, half width, half height, centre z), nose first.
FUSELAGE = [
	(3.55, 0.42, 0.42, 0.00),
	(2.70, 0.55, 0.58, 0.00),
	(1.40, 0.50, 0.60, 0.05),
	(0.00, 0.42, 0.50, 0.05),
	(-1.50, 0.30, 0.38, 0.10),
	(-3.00, 0.14, 0.25, 0.15),
	(-3.90, 0.05, 0.18, 0.20),
]
# Three wings, top first: (leading edge x, span, height). Staggered like the Dr.I.
WINGS = [(2.6, 10.0, 2.0), (2.3, 8.6, 0.75), (2.0, 7.8, -0.5)]
CHORD = 1.5
WING_THICKNESS = 0.16
WHEEL_Z = -2.0  # FlightModel.WHEEL_OFFSET below the origin
WHEEL_RADIUS = 0.4  # FlightModel.TYRE_OFFSET
HUB = Vector((3.72, 0.0, 0.0))


def octagon(x, half_w, half_h, z, flat=0.6):
	"""A flat-sided octagon cross-section of the fuselage at station x."""
	w, h, f = half_w, half_h, flat
	ys_zs = [(w, -h * f), (w, h * f), (w * f, h), (-w * f, h), (-w, h * f), (-w, -h * f), (-w * f, -h), (w * f, -h)]
	return [Vector((x, y, z + dz)) for y, dz in ys_zs]


def build_airframe():
	b = Builder()
	# Fuselage, with the engine face dark under the cowl ring.
	b.loft([octagon(*s) for s in FUSELAGE], SIDE)
	b.cylinder((3.5, 0, 0), (3.62, 0, 0), 0.37, DARK, sides=8)
	# Cockpit: a dark opening, the pilot, a windscreen and a headrest fairing.
	b.box((0.1, 0.0, 0.62), (1.0, 0.64, 0.1), DARK)
	b.box((0.0, 0.0, 0.86), (0.32, 0.3, 0.32), DARK)
	b.loft(
		[
			[Vector(p) for p in ((0.68, -0.3, 0.6), (0.68, 0.3, 0.6), (0.56, 0.26, 0.98), (0.56, -0.26, 0.98))],
			[Vector(p) for p in ((0.64, -0.3, 0.6), (0.64, 0.3, 0.6), (0.52, 0.26, 0.98), (0.52, -0.26, 0.98))],
		],
		CANOPY,
	)
	b.loft([rect(Vector((-0.4, 0, 0.75)), 0.2, 0.22), rect(Vector((-1.9, 0, 0.5)), 0.05, 0.04)], SIDE)
	# Machine Guns on the cowl.
	for y in (-0.22, 0.22):
		b.box((1.75, y, 0.7), (1.7, 0.12, 0.12), DARK)
	# Wings: straight, with a shorter rounded section at each tip.
	for leading_x, span, z in WINGS:
		half = span / 2
		rings = []
		for y, scale in ((-half, 0.7), (-half + 0.45, 1.0), (half - 0.45, 1.0), (half, 0.7)):
			rings.append(airfoil_section(y, leading_x - (1 - scale) * CHORD * 0.4, CHORD * scale, z, WING_THICKNESS * scale))
		b.loft(rings, SIDE)
	# Interplane struts outboard, cabane struts from the fuselage to the top wing.
	top_x, _, top_z = WINGS[0]
	bottom_x, _, bottom_z = WINGS[2]
	for y in (-3.2, 3.2):
		b.strut((bottom_x - 0.75, y, bottom_z), (top_x - 0.75, y, top_z), DARK, depth=0.22)
	for y in (-0.5, 0.5):
		b.strut((2.45, y * 0.9, 0.55), (2.5, y * 1.3, top_z), DARK)
		b.strut((1.45, y * 0.9, 0.55), (1.4, y * 1.3, top_z), DARK)
	# Tail: stabiliser in the XY plane, fin and rudder in the XZ plane.
	half_stabiliser = [(-2.6, 0.25), (-2.8, 1.2), (-3.1, 1.55), (-3.6, 1.55), (-3.95, 1.1), (-4.05, 0.3)]
	stabiliser = half_stabiliser + [(x, -y) for x, y in reversed(half_stabiliser)]
	b.plate(stabiliser, 0.08, SIDE, plane="xy", offset=0.2)
	fin = [(-2.3, 0.2), (-3.4, 0.2), (-3.9, -0.4), (-4.1, -0.3), (-4.15, 0.6), (-4.05, 1.3), (-3.8, 1.65), (-3.45, 1.7), (-3.25, 1.45), (-3.15, 1.0), (-3.0, 0.5)]
	b.plate(fin, 0.08, SIDE, plane="xz")
	# Landing gear: V struts to a faired axle, wheels and the tail skid.
	for y in (-1, 1):
		b.strut((2.3, y * 0.35, -0.5), (1.75, y * 0.85, WHEEL_Z + 0.1), DARK)
		b.strut((1.0, y * 0.35, -0.45), (1.45, y * 0.85, WHEEL_Z + 0.1), DARK)
		b.cylinder((1.6, y * 0.87, WHEEL_Z), (1.6, y * 1.03, WHEEL_Z), WHEEL_RADIUS, DARK)
	b.box((1.6, 0.0, WHEEL_Z), (0.6, 1.8, 0.14), SIDE)
	b.strut((-3.5, 0.0, -0.15), (-3.2, 0.0, -1.0), DARK)
	return b.to_object("Airframe")


def build_propeller():
	b = Builder()
	b.loft([circle(HUB + Vector((-0.1, 0, 0)), Vector((1, 0, 0)), 0.24, 8), HUB + Vector((0.25, 0, 0))], SIDE)
	# Two blades along ±Z, twisted more at the root than the tip. The second blade is the first
	# turned half a revolution about the hub axis, so both pitch the same way.
	stations = [(0.2, 0.14, 0.08, 40.0), (0.7, 0.26, 0.05, 25.0), (1.15, 0.2, 0.03, 15.0), (1.3, 0.08, 0.02, 12.0)]
	blade = []
	for r, chord, thickness, twist in stations:
		angle = math.radians(twist)
		ring = []
		for a, c in ((-thickness, -chord), (thickness, -chord), (thickness, chord), (-thickness, chord)):
			x = a / 2 * math.cos(angle) - c / 2 * math.sin(angle)
			y = a / 2 * math.sin(angle) + c / 2 * math.cos(angle)
			ring.append(HUB + Vector((x, y, r)))
		blade.append(ring)
	b.loft(blade, PROP)
	mirrored = [[HUB + Vector((p.x - HUB.x, -(p.y - HUB.y), -(p.z - HUB.z))) for p in ring] for ring in blade]
	b.loft(mirrored, PROP)
	return b.to_object("Propeller", origin=HUB)


def build():
	materials(COLOURS)
	return [build_airframe(), build_propeller()]


if __name__ == "__main__":
	run(build)
