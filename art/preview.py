"""Renders a built model to PNG for a look without opening Godot or Blender's UI.

Run headless:  blender -b --python art/preview.py -- assets/models/plane.glb out.png [OBJECT]
(scripts/preview-model.sh does this.) Writes out.png, a three-quarter view, and a side view
next to it with "-side" before the extension. Cycles on the CPU, so it works without a GPU.
With OBJECT, only that named object of the model is shown: the variants of a Backdrop piece
all sit on the origin, so each is looked at alone.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

SIZE = (960, 640)
SAMPLES = 32


def look_at(camera, target):
	direction = Vector(target) - camera.location
	camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def bounds():
	"""Centre and size of everything imported, in world space."""
	low = Vector((math.inf,) * 3)
	high = -low
	for obj in bpy.context.scene.objects:
		if obj.type != "MESH":
			continue
		for corner in obj.bound_box:
			world = obj.matrix_world @ Vector(corner)
			low = Vector(map(min, low, world))
			high = Vector(map(max, high, world))
	return (low + high) / 2, high - low


def add_ground(z):
	"""A grass-green floor under the model, to judge its footing."""
	mesh = bpy.data.meshes.new("Ground")
	mesh.from_pydata([(-200, -200, z), (200, -200, z), (200, 200, z), (-200, 200, z)], [], [[0, 1, 2, 3]])
	mat = bpy.data.materials.new("Grass")
	mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.09, 0.17, 0.04, 1.0)
	mesh.materials.append(mat)
	bpy.context.scene.collection.objects.link(bpy.data.objects.new("Ground", mesh))


def setup(model_path, only=None):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=model_path)
	if only is not None:
		names = [obj.name for obj in bpy.context.scene.objects if obj.type == "MESH"]
		if only not in names:
			sys.exit(f"no object {only} in {model_path}; it has {', '.join(names)}")
		for obj in list(bpy.context.scene.objects):
			if obj.type == "MESH" and obj.name != only:
				bpy.data.objects.remove(obj)
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = SAMPLES
	scene.cycles.use_denoising = False
	scene.render.resolution_x, scene.render.resolution_y = SIZE
	scene.render.film_transparent = False
	# Plain exposure so the colours read as written, not through a filmic curve.
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	world = bpy.data.worlds.new("Sky")
	world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.26, 0.45, 0.79, 1.0)
	world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.5
	scene.world = world
	sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
	sun.data.energy = 2.5
	sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
	scene.collection.objects.link(sun)
	camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
	camera.data.lens = 50
	scene.collection.objects.link(camera)
	scene.camera = camera
	return scene, camera


def render(scene, camera, direction, target, size, path):
	# A 50 mm lens sees about 40 degrees across; back off far enough for the longest side.
	distance = size * 1.9 + 2.0
	camera.location = Vector(target) + Vector(direction).normalized() * distance
	look_at(camera, target)
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	print(f"wrote {path}")


if __name__ == "__main__":
	args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	if len(args) not in (2, 3):
		sys.exit("usage: blender -b --python art/preview.py -- MODEL.glb OUT.png [OBJECT]")
	model_path, out = args[:2]
	scene, camera = setup(model_path, args[2] if len(args) == 3 else None)
	centre, extent = bounds()
	add_ground(centre.z - extent.z / 2)
	size = max(extent)
	stem, ext = os.path.splitext(out)
	render(scene, camera, (1.0, -0.9, 0.35), centre, size, out)
	render(scene, camera, (0.0, -1.0, 0.08), centre, size, f"{stem}-side{ext}")
