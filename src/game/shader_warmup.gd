class_name ShaderWarmup
## The Compatibility renderer compiles a material's shader the first time it is drawn, and
## on the web that compile stalls the frame: the first shot, the first hit, the first Burst
## each froze the game for a moment. So at mission start every pool draws one instance,
## scaled to nothing, in front of the camera for a few frames, and every permutation is
## compiled behind the Refit screen instead. A new material or shader must be primed the
## same way.

## Frames a pool keeps its primer visible: more than one, in case the first is not rendered.
const FRAMES := 3
## The primer's size: too small to see, not zero, so its bounds still meet the frustum.
const SCALE := 0.001
## How far in front of the camera the speck sits: past the near plane, inside the frustum
## whichever way the camera looks. (A speck on the action plane at the camera's x and y was
## outside the title camera's three-quarter view, so nothing was ever drawn or compiled.)
const AHEAD := 20.0


## Show one instance of the pool, if it shows none, as a speck at the point the camera looks
## at on the action plane.
static func prime(instance: MultiMeshInstance3D, camera: Camera3D) -> void:
	var multimesh := instance.multimesh
	if multimesh == null or multimesh.instance_count == 0:
		return
	if multimesh.visible_instance_count != 0:
		return  # the pool is drawing already, which compiles it
	multimesh.visible_instance_count = 1
	multimesh.set_instance_transform(0, speck(camera))
	if multimesh.use_colors:
		multimesh.set_instance_color(0, Color(1.0, 1.0, 1.0, 0.5))


## A transform of SCALE a little way in front of the camera, wherever it looks.
static func speck(camera: Camera3D) -> Transform3D:
	var at := camera.global_position - camera.global_basis.z * AHEAD
	return Transform3D(Basis.from_scale(Vector3.ONE * SCALE), at)
