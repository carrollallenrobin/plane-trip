"""The cover picture for the game's store page, composed from the built models.

Run headless:  blender -b --python art/cover.py -- promo/cover-640x512.png 640x512 [OUT WxH ...]
(scripts/build-cover.sh does this for every size the store wants.) Nothing in here is drawn
by hand: the planes, the airfield, the trees, hills, clouds and mountains are the game's own
.glb files under assets/models/, painted and hazed by the game's rules, and the wordmark is
set in the UI's stencil font over a Band, as on the title screen. Change the layout here and
rebuild; never edit the PNGs.

Blender axes as in the models: X is the world's horizontal, Y is depth away from the camera,
Z is up, one unit one metre. The player's Blue plane is the hero, banking toward the camera
with a Red plane on its guns.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "assets", "models")
FONTS = os.path.join(ROOT, "assets", "fonts")

SAMPLES = int(os.environ.get("COVER_SAMPLES", "160"))

# The game's colours, written as Godot writes them (sRGB), converted below.
BLUE = (0.25, 0.35, 0.9)  # Side.colour(Side.BLUE)
RED = (0.85, 0.2, 0.2)  # Side.colour(Side.RED)
SKY_TOP = (0.25, 0.45, 0.8)  # data/sky.tres
SKY_HORIZON = (0.75, 0.82, 0.9)
GRASS = (0.36, 0.52, 0.24)  # TerrainNode.SURFACE_COLOR
HAZE = (0.75, 0.82, 0.9)  # BackdropNode.HAZE_COLOR
HAZE_MAX = 0.5  # BackdropPlan
HAZE_DISTANCE = 1800.0
CREAM = (0.93, 0.89, 0.76)  # UiPalette
OLIVE_DARK = (0.14, 0.16, 0.10)
BAND_ALPHA = 0.88
TRACER = (1.0, 0.95, 0.6)
FLASH = (1.0, 0.62, 0.22)
SMOKE = (0.42, 0.42, 0.45)
BURST_SMOKE = (0.30, 0.29, 0.30)

GROUND_Z = -28.0
# The camera: behind the hero's left shoulder and above it, looking over it at the foe, so
# the three wings and the tail read as a triplane and the hero flies into the picture; then
# turned a little right and down so the horizon sits in the upper third, the airfield shows
# under the hero and the foe sits against the sky.
CAMERA_BEARING = 70.0  # degrees from +X, where the camera stands as seen from the hero
CAMERA_DISTANCE = 26.0  # horizontal, metres
CAMERA_HEIGHT = 9.0
CAMERA_PAN = 8.0  # degrees right of the hero
CAMERA_TILT = -10.0  # degrees below the horizon
HERO_HEIGHT = 2.5  # the hero sits over the Band's top edge, its lower wing just crossing it
LENS = 32.0
SUN_ROTATION = (55.0, 8.0, -35.0)
BAND_DISTANCE = 40.0  # in front of the lens: behind the hero, in front of everything else


def srgb_to_linear(value):
	if value <= 0.04045:
		return value / 12.92
	return ((value + 0.055) / 1.055) ** 2.4


def linear(colour, alpha=1.0):
	return (*(srgb_to_linear(c) for c in colour), alpha)


def mix(a, b, t):
	return tuple(x + (y - x) * t for x, y in zip(a, b))


def camera_stand():
	stand = math.radians(CAMERA_BEARING)
	return Vector((-math.cos(stand) * CAMERA_DISTANCE, -math.sin(stand) * CAMERA_DISTANCE, CAMERA_HEIGHT))


def ahead(offset, distance, z):
	"""A point at a horizontal distance from the camera, offset degrees left of its line of
	sight (right when negative), at height z: the Backdrop is laid out by where it lands in
	the frame, not by World coordinates."""
	b = math.radians(CAMERA_BEARING - CAMERA_PAN + offset)
	stand = camera_stand()
	return (stand.x + math.cos(b) * distance, stand.y + math.sin(b) * distance, z)


def aim(camera, bearing, tilt):
	"""Point a camera along a bearing (degrees from +X, anticlockwise from above) and tilt."""
	b, t = math.radians(bearing), math.radians(tilt)
	direction = Vector((math.cos(b) * math.cos(t), math.sin(b) * math.cos(t), math.sin(t)))
	camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


# --- materials -------------------------------------------------------------------------------


def flat_material(name, colour, roughness=0.8):
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	bsdf = mat.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = linear(colour)
	bsdf.inputs["Roughness"].default_value = roughness
	return mat


def unlit(obj):
	"""A glowing thing neither shadows nor lights the rest: it is drawn, not in the World."""
	obj.visible_shadow = False
	obj.visible_diffuse = False
	obj.visible_glossy = False
	return obj


def glow_material(name, colour, strength=1.0, alpha=1.0):
	"""Pure emission: the colour as written, unlit, like the UI and the Muzzle Flashes."""
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	nodes, links = mat.node_tree.nodes, mat.node_tree.links
	nodes.clear()
	out = nodes.new("ShaderNodeOutputMaterial")
	emission = nodes.new("ShaderNodeEmission")
	emission.inputs["Color"].default_value = linear(colour)
	emission.inputs["Strength"].default_value = strength
	if alpha < 1.0:
		transparent = nodes.new("ShaderNodeBsdfTransparent")
		mixer = nodes.new("ShaderNodeMixShader")
		mixer.inputs["Fac"].default_value = alpha
		links.new(transparent.outputs[0], mixer.inputs[1])
		links.new(emission.outputs[0], mixer.inputs[2])
		links.new(mixer.outputs[0], out.inputs["Surface"])
		mat.blend_method = "BLEND"
	else:
		links.new(emission.outputs[0], out.inputs["Surface"])
	return mat


def base_colour(mat):
	return tuple(mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value)


def set_base_colour(mat, rgba):
	mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = rgba


# --- the models ------------------------------------------------------------------------------


def import_model(name, only=None):
	"""Import a built model as a group under one empty, so it is placed as a whole. Every
	material is copied, so painting or hazing one instance leaves the others alone."""
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, f"{name}.glb"))
	new = [obj for obj in bpy.data.objects if obj not in before]
	meshes = [obj for obj in new if obj.type == "MESH" and (only is None or obj.name.split(".")[0] == only)]
	for obj in new:
		if obj not in meshes:
			bpy.data.objects.remove(obj)
	for obj in meshes:
		obj.data = obj.data.copy()
		for slot in obj.material_slots:
			slot.material = slot.material.copy()
	root = bpy.data.objects.new(f"{name}_{only or 'group'}", None)
	bpy.context.scene.collection.objects.link(root)
	for obj in meshes:
		if obj.parent is None:
			obj.parent = root
	return root


def paint_side(root, colour):
	"""What SideModel does: the material named Side takes the Side's colour."""
	for obj in root.children_recursive:
		for slot in getattr(obj, "material_slots", []):
			if slot.material.name.split(".")[0] == "Side":
				set_base_colour(slot.material, linear(colour))


def haze(root, depth):
	"""What BackdropNode does: every colour faded toward the sky by the depth."""
	t = HAZE_MAX * (1.0 - math.exp(-depth / HAZE_DISTANCE))
	target = linear(HAZE)
	for obj in root.children_recursive:
		for slot in getattr(obj, "material_slots", []):
			set_base_colour(slot.material, mix(base_colour(slot.material), target, t))


def place(root, at, yaw=0.0, pitch=0.0, roll=0.0, scale=1.0):
	"""Put a group somewhere, turned by yaw about Z, pitch (nose up positive) and roll (the
	-Y wing down positive, toward the camera)."""
	root.location = Vector(at)
	root.rotation_mode = "XYZ"
	root.rotation_euler = (math.radians(roll), math.radians(-pitch), math.radians(yaw))
	root.scale = (scale, scale, scale)
	return root


def plane(colour, at, yaw, pitch, roll, prop_angle):
	root = import_model("plane")
	paint_side(root, colour)
	for obj in root.children_recursive:
		if obj.name.startswith("Propeller"):
			obj.rotation_mode = "XYZ"
			obj.rotation_euler = (math.radians(prop_angle), 0.0, 0.0)
	return place(root, at, yaw, pitch, roll)


def backdrop(name, variant, at, depth, scale=1.0, turned=False):
	root = import_model(name, variant)
	haze(root, depth)
	return place(root, at, yaw=180.0 if turned else 0.0, scale=scale)


# --- things the Picture draws, not models -----------------------------------------------------


def add_mesh(name, verts, faces, material):
	mesh = bpy.data.meshes.new(name)
	mesh.from_pydata(verts, [], faces)
	mesh.materials.append(material)
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	return obj


def ground():
	mat = flat_material("Grass", GRASS)
	size = 6000.0
	return add_mesh(
		"Ground",
		[(-size, -size, GROUND_Z), (size, -size, GROUND_Z), (size, size, GROUND_Z), (-size, size, GROUND_Z)],
		[[0, 1, 2, 3]],
		mat,
	)


def sphere(name, at, radius, material, subdivisions=2):
	bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=at)
	obj = bpy.context.active_object
	obj.name = name
	obj.data.materials.append(material)
	for poly in obj.data.polygons:
		poly.use_smooth = False
	return obj


def tracer(start, end, material, radius=0.09):
	"""A Tracer: a bright streak along its flight."""
	start, end = Vector(start), Vector(end)
	axis = end - start
	bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=radius, depth=axis.length, location=(start + end) / 2)
	obj = bpy.context.active_object
	obj.rotation_euler = axis.to_track_quat("Z", "Y").to_euler()
	obj.data.materials.append(material)
	return unlit(obj)


def tracers(gun, target, count, spacing, length, material):
	"""A line of Tracers from a gun toward a target, the newest at the muzzle."""
	gun, target = Vector(gun), Vector(target)
	direction = (target - gun).normalized()
	for i in range(count):
		head = gun + direction * (2.0 + i * spacing)
		tracer(head, head + direction * length, material)


def smoke_trail(points, start_radius, end_radius, material):
	"""Smoke behind a hit plane: puffs growing and thinning away from it."""
	n = len(points)
	for i, at in enumerate(points):
		t = i / max(n - 1, 1)
		sphere(f"Smoke{i}", at, start_radius + (end_radius - start_radius) * t, material, subdivisions=1)


def burst(at, radius):
	"""A Burst: a flash sphere with puffs around it."""
	unlit(sphere("BurstFlash", at, radius, glow_material("Flash", FLASH, strength=1.0)))
	puffs = flat_material("BurstSmoke", BURST_SMOKE)
	for i, (dx, dy, dz, r) in enumerate(
		[(1.5, 0.3, 1.2, 1.2), (-1.4, 0.5, 1.0, 1.1), (0.3, -0.6, 2.0, 1.0), (-0.6, 0.8, -1.2, 0.9), (1.2, -0.2, -1.0, 0.8)]
	):
		sphere(f"BurstPuff{i}", (at[0] + dx * radius, at[1] + dy * radius, at[2] + dz * radius), r * radius, puffs, 1)


# --- the wordmark ----------------------------------------------------------------------------


def wordmark(camera):
	"""PLANE TRIP in the stencil over a Band, pinned to the camera like the title screen."""
	font = bpy.data.fonts.load(os.path.join(FONTS, "AllertaStencil-Regular.ttf"))
	distance = BAND_DISTANCE
	half_h = distance * math.tan(camera.data.angle_y / 2)
	half_w = distance * math.tan(camera.data.angle_x / 2)
	band_h = half_h * 0.56
	band_z = -half_h + band_h / 2
	# The Band: a strip across the bottom of the frame.
	band = add_mesh(
		"Band",
		[(-half_w * 1.1, band_z - band_h / 2, -distance), (half_w * 1.1, band_z - band_h / 2, -distance),
		 (half_w * 1.1, band_z + band_h / 2, -distance), (-half_w * 1.1, band_z + band_h / 2, -distance)],
		[[0, 1, 2, 3]],
		glow_material("BandInk", OLIVE_DARK, alpha=BAND_ALPHA),
	)
	band.parent = camera
	unlit(band)

	def text(name, colour, offset, depth):
		curve = bpy.data.curves.new(name, "FONT")
		curve.body = "PLANE TRIP"
		curve.font = font
		curve.align_x = "CENTER"
		curve.align_y = "CENTER"
		curve.size = band_h * 0.62
		curve.offset = offset
		curve.materials.append(glow_material(f"{name}Ink", colour))
		obj = bpy.data.objects.new(name, curve)
		bpy.context.scene.collection.objects.link(obj)
		obj.parent = camera
		obj.location = (0.0, band_z + band_h * 0.02, depth)
		return unlit(obj)

	text("WordmarkOutline", OLIVE_DARK, band_h * 0.018, -distance + 0.05)
	text("Wordmark", CREAM, 0.0, -distance + 0.1)


# --- the scene -------------------------------------------------------------------------------


def sky():
	world = bpy.data.worlds.new("Sky")
	world.use_nodes = True
	nodes, links = world.node_tree.nodes, world.node_tree.links
	background = nodes["Background"]
	background.inputs["Strength"].default_value = 0.7
	coords = nodes.new("ShaderNodeTexCoord")
	split = nodes.new("ShaderNodeSeparateXYZ")
	ramp = nodes.new("ShaderNodeValToRGB")
	ramp.color_ramp.elements[0].position = 0.0
	ramp.color_ramp.elements[0].color = linear(SKY_HORIZON)
	ramp.color_ramp.elements[1].position = 0.45
	ramp.color_ramp.elements[1].color = linear(SKY_TOP)
	links.new(coords.outputs["Generated"], split.inputs[0])
	links.new(split.outputs["Z"], ramp.inputs["Fac"])
	links.new(ramp.outputs["Color"], background.inputs["Color"])
	bpy.context.scene.world = world


def setup():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = SAMPLES
	scene.cycles.use_denoising = True
	scene.render.film_transparent = False
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	sky()
	sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
	sun.data.energy = 2.8
	sun.data.angle = math.radians(2.0)
	sun.rotation_euler = tuple(math.radians(a) for a in SUN_ROTATION)
	scene.collection.objects.link(sun)
	camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
	camera.data.lens = LENS
	camera.data.sensor_fit = "HORIZONTAL"
	camera.data.clip_end = 20000.0
	camera.location = camera_stand()
	aim(camera, CAMERA_BEARING - CAMERA_PAN, CAMERA_TILT)
	scene.collection.objects.link(camera)
	scene.camera = camera
	return scene, camera


def compose():
	ground()
	# The action: the hero at the origin, the foe up and to the right against the sky.
	hero = plane(BLUE, (0.0, 0.0, HERO_HEIGHT), yaw=30.0, pitch=8.0, roll=30.0, prop_angle=20.0)
	foe = plane(RED, ahead(-9.0, 52.0, 11.5), yaw=20.0, pitch=-8.0, roll=-40.0, prop_angle=70.0)
	bpy.context.view_layer.update()  # matrix_world is stale until the depsgraph has run
	streak = glow_material("Tracer", TRACER, strength=1.0)
	for side in (-1.0, 1.0):
		muzzle = hero.matrix_world @ Vector((3.4, side * 0.28, 0.35))
		target = foe.matrix_world @ Vector((-2.0, 0.0, 0.0))
		tracers(muzzle, target, count=4, spacing=7.5, length=4.0, material=streak)
	trail = flat_material("Smoke", SMOKE)
	smoke_trail(
		[foe.matrix_world @ Vector((-4.5 - 2.2 * i, 0.3 * i, 0.2 * i + 0.06 * i * i)) for i in range(6)],
		0.4,
		1.3,
		trail,
	)
	burst(ahead(-23.0, 40.0, 9.5), 1.0)
	# The airfield under the fight.
	place(paint_side_and(import_model("hangar"), RED), ahead(-4.0, 150.0, GROUND_Z), scale=1.4)
	place(paint_side_and(import_model("aa_gun"), RED), ahead(4.0, 130.0, GROUND_Z), scale=1.6)
	place(paint_side_and(import_model("building"), RED), ahead(-13.0, 165.0, GROUND_Z), scale=1.4)
	place(paint_side_and(import_model("flak_gun"), RED), ahead(-19.0, 140.0, GROUND_Z), scale=1.6)
	for i, (offset, variant) in enumerate([(22, "TreeA"), (18, "TreeB"), (14, "TreeC"), (-24, "TreeA"), (-27, "TreeB")]):
		backdrop("tree", variant, ahead(offset, 190.0 + 6 * (i % 3), GROUND_Z), depth=190.0, scale=2.0)
	# The Backdrop, each layer at its depth and faded for it, laid out across the frame.
	backdrop("windmill", None, ahead(23.0, 210.0, GROUND_Z), depth=210.0, scale=1.6)
	backdrop("factory", None, ahead(11.0, 330.0, GROUND_Z), depth=330.0, scale=1.5)
	backdrop("hill", "HillA", ahead(14.0, 420.0, GROUND_Z), depth=420.0, scale=2.2)
	backdrop("hill", "HillB", ahead(-8.0, 460.0, GROUND_Z), depth=460.0, scale=2.4, turned=True)
	backdrop("hill", "HillA", ahead(-26.0, 440.0, GROUND_Z), depth=440.0, scale=2.0, turned=True)
	backdrop("cloud", "CloudA", ahead(19.0, 620.0, 85.0), depth=620.0, scale=1.3)
	backdrop("cloud", "CloudB", ahead(-14.0, 560.0, 70.0), depth=560.0, scale=1.2)
	backdrop("mountain", "MountainA", ahead(8.0, 1000.0, GROUND_Z), depth=1000.0, scale=0.62)
	backdrop("mountain", "MountainB", ahead(-16.0, 1100.0, GROUND_Z), depth=1100.0, scale=0.55, turned=True)
	backdrop("mountain", "MountainA", ahead(28.0, 1150.0, GROUND_Z), depth=1150.0, scale=0.5, turned=True)
	backdrop("mountain", "MountainB", ahead(-34.0, 1200.0, GROUND_Z), depth=1200.0, scale=0.5)


def paint_side_and(root, colour):
	paint_side(root, colour)
	return root


def render(scene, path, size):
	scene.render.resolution_x, scene.render.resolution_y = size
	scene.render.resolution_percentage = 100
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	print(f"wrote {path}")


if __name__ == "__main__":
	args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	if len(args) < 2 or len(args) % 2:
		sys.exit("usage: blender -b --python art/cover.py -- OUT.png WxH [OUT.png WxH ...]")
	sizes = [tuple(int(v) for v in size.lower().split("x")) for size in args[1::2]]
	scene, camera = setup()
	# The frame's shape decides where the Band sits; the sizes asked for share one shape.
	scene.render.resolution_x, scene.render.resolution_y = sizes[0]
	compose()
	wordmark(camera)
	for out, size in zip(args[::2], sizes):
		render(scene, out, size)
