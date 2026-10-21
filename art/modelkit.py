"""Shared helpers for the model scripts in art/models/: a Builder that collects closed solids
into one mesh, shape functions, flat-coloured materials and the glTF export.

Blender axes in every model: X is the world's horizontal (a plane's nose points +X), Y is
depth (towards the camera is -Y), Z is up, one unit one metre. The glTF exporter turns that
into Godot's frame: X stays, Z becomes +Y (up) and Y becomes -Z. The camera looks along
Godot's -Z, so a model's Blender -Y face is the one the player sees.

The material named SIDE is painted in the Side's colour by the game (SideModel); every
other material keeps the colour given here.
"""

import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

SIDE = "Side"
SIDE_PLACEHOLDER = (0.78, 0.78, 0.76, 1.0)

# One module-level material table per script run, filled by Builder.to_object.
_materials = {}


class Builder:
	"""Collects closed solids into one bmesh. Faces get a material by name."""

	def __init__(self):
		self.bm = bmesh.new()
		self.slots = []  # material names in slot order

	def slot(self, name):
		if name not in self.slots:
			self.slots.append(name)
		return self.slots.index(name)

	def face(self, verts, material):
		face = self.bm.faces.new(verts)
		face.material_index = self.slot(material)
		face.smooth = False

	def loft(self, rings, material, closed=False):
		"""Skin consecutive rings (equal point counts) with quads and cap the ends. A ring
		given as a single Vector is a point the neighbouring ring fans to. With closed, the
		last ring joins the first instead of capping: a hollow ring of sandbags, say."""
		vert_rings = []
		for ring in rings:
			points = [ring] if isinstance(ring, Vector) else ring
			vert_rings.append([self.bm.verts.new(p) for p in points])
		pairs = list(zip(vert_rings, vert_rings[1:]))
		if closed:
			pairs.append((vert_rings[-1], vert_rings[0]))
		for a, b in pairs:
			if len(a) == 1:
				for i in range(len(b)):
					self.face([a[0], b[i], b[(i + 1) % len(b)]], material)
			elif len(b) == 1:
				for i in range(len(a)):
					self.face([a[i], a[(i + 1) % len(a)], b[0]], material)
			else:
				for i in range(len(a)):
					j = (i + 1) % len(a)
					self.face([a[i], a[j], b[j], b[i]], material)
		if closed:
			return
		if len(vert_rings[0]) > 1:
			self.face(list(reversed(vert_rings[0])), material)
		if len(vert_rings[-1]) > 1:
			self.face(vert_rings[-1], material)

	def box(self, centre, size, material):
		"""An axis-aligned box."""
		c, s = Vector(centre), Vector(size) / 2
		self.loft([rect(c + Vector((-s.x, 0, 0)), s.y, s.z), rect(c + Vector((s.x, 0, 0)), s.y, s.z)], material)

	def block(self, centre, size, material, yaw=0.0, pitch=0.0):
		"""A box turned yaw degrees about Z and pitch degrees about Y: rubble, a fallen beam."""
		c, s = Vector(centre), Vector(size) / 2
		turn = Matrix.Rotation(math.radians(yaw), 3, "Z") @ Matrix.Rotation(math.radians(pitch), 3, "Y")
		rings = [[c + turn @ (p - c) for p in rect(c + Vector((dx, 0, 0)), s.y, s.z)] for dx in (-s.x, s.x)]
		self.loft(rings, material)

	def ring(self, centre, outer, inner, bottom, top, material, sides=8, turn=0.0):
		"""A hollow polygonal wall, inner to outer radius, from bottom to top height, turned
		turn degrees about Z so stacked layers can be offset like courses of sandbags."""
		c = Vector(centre)
		spin = Matrix.Rotation(math.radians(turn), 3, "Z")

		def course(radius, z):
			return [c + spin @ (p - c) + Vector((0, 0, z)) for p in circle(c, Vector((0, 0, 1)), radius, sides)]

		self.loft([course(outer, bottom), course(outer, top), course(inner, top), course(inner, bottom)], material, closed=True)

	def strut(self, start, end, material, width=0.08, depth=0.08):
		"""A slender box from start to end, its cross-section aligned to the axes."""
		self.loft([rect(Vector(start), width / 2, depth / 2, along="z"), rect(Vector(end), width / 2, depth / 2, along="z")], material)

	def cylinder(self, start, end, radius, material, sides=12, end_radius=None):
		"""A cylinder, or a cone frustum when end_radius differs, from start to end."""
		axis = (Vector(end) - Vector(start)).normalized()
		r2 = radius if end_radius is None else end_radius
		self.loft([circle(Vector(start), axis, radius, sides), circle(Vector(end), axis, r2, sides)], material)

	def plate(self, outline, thickness, material, plane="xz", offset=0.0):
		"""A flat polygon (list of 2D points) extruded symmetrically about its plane: "xz"
		(a wall seen from the camera, offset along Y) or "xy" (a floor, offset along Z)."""
		h = thickness / 2
		if plane == "xz":
			rings = [[Vector((x, offset + d, z)) for x, z in outline] for d in (-h, h)]
		else:
			rings = [[Vector((x, y, offset + d)) for x, y in outline] for d in (-h, h)]
		self.loft(rings, material)

	def prism(self, outline, start, end, material):
		"""A polygon in the XZ plane extruded from y=start to y=end: walls with a gable."""
		self.loft([[Vector((x, y, z)) for x, z in outline] for y in (start, end)], material)

	def mound(self, levels, material, centre=(0, 0, 0), sides=10, wobble=None):
		"""A faceted hill or peak: elliptical rings (z, rx, ry) lofted upwards, the last one a
		point when its rx is 0. wobble scales each vertex's radius in turn, so the outline is
		uneven rather than a clean ellipse; the same wobble on every ring keeps the facets
		running straight up the slope."""
		c = Vector(centre)
		rings = []
		for z, rx, ry in levels:
			if rx == 0:
				rings.append(c + Vector((0, 0, z)))
				continue
			ring = []
			for i in range(sides):
				a = 2 * math.pi * i / sides
				w = wobble[i % len(wobble)] if wobble else 1.0
				ring.append(c + Vector((rx * w * math.cos(a), ry * w * math.sin(a), z)))
			rings.append(ring)
		self.loft(rings, material)

	def to_object(self, name, origin=Vector((0, 0, 0))):
		"""Finish the mesh as a Blender object named name, with its origin at origin."""
		bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
		bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
		for v in self.bm.verts:
			v.co -= origin
		mesh = bpy.data.meshes.new(name)
		self.bm.to_mesh(mesh)
		self.bm.free()
		for slot_name in self.slots:
			mesh.materials.append(_materials[slot_name])
		obj = bpy.data.objects.new(name, mesh)
		obj.location = origin
		bpy.context.collection.objects.link(obj)
		return obj


def rect(centre, half_a, half_b, along="x"):
	"""Four corners of a rectangle perpendicular to the given axis."""
	if along == "x":
		offsets = [(0, -half_a, -half_b), (0, half_a, -half_b), (0, half_a, half_b), (0, -half_a, half_b)]
	elif along == "y":
		offsets = [(-half_a, 0, -half_b), (half_a, 0, -half_b), (half_a, 0, half_b), (-half_a, 0, half_b)]
	else:
		offsets = [(-half_a, -half_b, 0), (half_a, -half_b, 0), (half_a, half_b, 0), (-half_a, half_b, 0)]
	return [centre + Vector(o) for o in offsets]


def circle(centre, axis, radius, sides):
	"""Points of a circle around axis; sides=8 gives the chunky look the models share."""
	up = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
	u = axis.cross(up).normalized()
	v = axis.cross(u)
	return [centre + (u * math.cos(t) + v * math.sin(t)) * radius for t in (i / sides * math.tau for i in range(sides))]


def airfoil_section(y, leading_x, chord, z, thickness):
	"""Six-point wing section at span position y, leading edge forward (+X)."""
	t = thickness
	xs_zs = [
		(0.0, 0.0),
		(-0.25 * chord, 0.5 * t),
		(-0.65 * chord, 0.3 * t),
		(-chord, -0.02 * t),
		(-0.65 * chord, -0.25 * t),
		(-0.25 * chord, -0.45 * t),
	]
	return [Vector((leading_x + dx, y, z + dz)) for dx, dz in xs_zs]


def srgb_to_linear(value):
	"""One sRGB channel to Blender's linear scene-referred value."""
	if value <= 0.04045:
		return value / 12.92
	return ((value + 0.055) / 1.055) ** 2.4


def materials(table):
	"""Declare the materials a script uses: {name: (r, g, b)}, each colour as it should look,
	the way Godot's Color is written. Blender's Base Color is linear, so the kit converts;
	without that every model came out gamma-brightened in the game, brick as pink and dark
	fir as mint. SIDE is added automatically."""
	_materials.clear()
	table = dict(table)
	table.setdefault(SIDE, SIDE_PLACEHOLDER[:3])
	for name, colour in table.items():
		mat = bpy.data.materials.new(name)
		bsdf = mat.node_tree.nodes["Principled BSDF"]
		bsdf.inputs["Base Color"].default_value = (*(srgb_to_linear(c) for c in colour), 1.0)
		bsdf.inputs["Roughness"].default_value = 0.8
		bsdf.inputs["Metallic"].default_value = 0.0
		_materials[name] = mat


def export(objects, path):
	"""Write the objects to a .glb and report the triangle count."""
	for obj in objects:
		obj.select_set(True)
	bpy.ops.export_scene.gltf(
		filepath=path,
		export_format="GLB",
		use_selection=True,
		export_apply=True,
		export_yup=True,
		export_texcoords=False,
		export_normals=True,
		export_materials="EXPORT",
		export_animations=False,
		export_skins=False,
		export_morph=False,
		export_cameras=False,
		export_lights=False,
	)
	triangles = sum(len(p.vertices) - 2 for obj in objects for p in obj.data.polygons)
	print(f"wrote {path}: {triangles} triangles")


def run(build):
	"""Script entry point: start from an empty file, build, export to the path after '--'."""
	args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	if len(args) != 1:
		sys.exit("usage: blender -b --python art/models/NAME.py -- OUTPUT.glb")
	bpy.ops.wm.read_factory_settings(use_empty=True)
	objects = build()
	export(objects, args[0])
