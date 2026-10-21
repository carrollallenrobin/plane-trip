class_name EffectsNode
extends Node3D
## Draws an EffectsPlan: Muzzle Flashes as glowing cones at the muzzle, Casings as tumbling
## brass, impact puffs and smoke as blobs of the cloud model's Puff, sparks as hot flecks,
## Bursts as a white flash sphere inside a glowing coloured one, one pooled MultiMesh each.
## Picture only (ADR 0007): the Picture fills the plan from the World's events, this node
## advances the plan on the render clock in _process and draws it, and nothing reads it back.
## Tests call advance() themselves.

const FLASH_COLOR := Color(1.0, 0.93, 0.55)
## The cone: its length along the barrel and the radius of its open end.
const FLASH_LENGTH := 2.0
const FLASH_RADIUS := 0.7
## The cone pops from this fraction of its size to full over its life.
const FLASH_POP_FROM := 0.6
## The flash is solid until this much of its life is left, then fades out.
const FLASH_FADE_FROM := 0.4
const CASING_COLOR := Color(0.85, 0.65, 0.25)
const CASING_SIZE := Vector3(0.5, 0.15, 0.15)
## The blob the impact puffs are made of, shared with the Backdrop's smoke.
const CLOUD_MODEL := preload("res://assets/models/cloud.glb")
const PUFF_NODE := "Puff"
## Warmer than the body's white hit flash, so the two read apart.
const SPARK_COLOR := Color(1.0, 0.8, 0.45)
const SPARK_SIZE := Vector3(0.6, 0.14, 0.14)
## A spark is solid until this much of its life is left, then fades out, like the flash.
const SPARK_FADE_FROM := 0.4
const BURST_FLASH_COLOR := Color(1.0, 1.0, 0.95)

var plan: EffectsPlan

var _flashes: MultiMeshInstance3D
var _casings: MultiMeshInstance3D
var _puffs: MultiMeshInstance3D
var _sparks: MultiMeshInstance3D
var _burst_flashes: MultiMeshInstance3D
var _burst_spheres: MultiMeshInstance3D
var _warm_camera: Camera3D
var _warm_frames := 0


static func create(effects_plan: EffectsPlan) -> EffectsNode:
	var node := EffectsNode.new()
	node.name = "Effects"
	node.plan = effects_plan
	return node


func _ready() -> void:
	if plan == null:
		plan = EffectsPlan.new()
	_flashes = _make("MuzzleFlashes", _flash_mesh(), EffectsPlan.MAX_FLASHES)
	_casings = _make("Casings", _casing_mesh(), EffectsPlan.MAX_CASINGS)
	_puffs = _make("Puffs", _puff_mesh(), EffectsPlan.MAX_PUFFS)
	_sparks = _make("Sparks", _spark_mesh(), EffectsPlan.MAX_SPARKS)
	_burst_flashes = _make("BurstFlashes", _sphere_mesh(true), EffectsPlan.MAX_BURSTS)
	_burst_spheres = _make("BurstSpheres", _sphere_mesh(false), EffectsPlan.MAX_BURSTS)


## Draw a speck of every pool for a few frames, so their shaders compile now (ShaderWarmup).
func warm_up(camera: Camera3D) -> void:
	_warm_camera = camera
	_warm_frames = ShaderWarmup.FRAMES


func _process(dt: float) -> void:
	advance(dt)


## Move the plan on by dt seconds and draw it.
func advance(dt: float) -> void:
	plan.advance(dt)
	_flashes.multimesh.visible_instance_count = plan.flashes.size()
	for i in plan.flashes.size():
		var flash := plan.flashes[i]
		_flashes.multimesh.set_instance_transform(i, flash_transform(flash))
		var colour := FLASH_COLOR
		colour.a = flash_alpha(flash)
		_flashes.multimesh.set_instance_color(i, colour)
	_casings.multimesh.visible_instance_count = plan.casings.size()
	for i in plan.casings.size():
		var casing := plan.casings[i]
		_casings.multimesh.set_instance_transform(i, casing_transform(casing))
		_casings.multimesh.set_instance_color(i, CASING_COLOR)
	_puffs.multimesh.visible_instance_count = plan.puffs.size()
	for i in plan.puffs.size():
		var puff := plan.puffs[i]
		_puffs.multimesh.set_instance_transform(i, puff_transform(puff))
		var colour := puff.colour
		colour.a = puff.remaining()
		_puffs.multimesh.set_instance_color(i, colour)
	_sparks.multimesh.visible_instance_count = plan.sparks.size()
	for i in plan.sparks.size():
		var spark := plan.sparks[i]
		_sparks.multimesh.set_instance_transform(i, spark_transform(spark))
		var hot := SPARK_COLOR
		hot.a = clampf(spark.remaining() / SPARK_FADE_FROM, 0.0, 1.0)
		_sparks.multimesh.set_instance_color(i, hot)
	_burst_spheres.multimesh.visible_instance_count = plan.bursts.size()
	_burst_flashes.multimesh.visible_instance_count = plan.bursts.size()
	for i in plan.bursts.size():
		var burst := plan.bursts[i]
		_burst_spheres.multimesh.set_instance_transform(
			i, _sphere_transform(burst.origin, burst.scale())
		)
		var colour := burst.colour
		colour.a = burst.remaining()
		_burst_spheres.multimesh.set_instance_color(i, colour)
		_burst_flashes.multimesh.set_instance_transform(
			i, _sphere_transform(burst.origin, burst.flash_scale())
		)
		var white := BURST_FLASH_COLOR
		white.a = burst.flash_remaining()
		_burst_flashes.multimesh.set_instance_color(i, white)
	if _warm_frames > 0 and _warm_camera != null:
		_warm_frames -= 1
		for pool in [_flashes, _casings, _puffs, _sparks, _burst_spheres, _burst_flashes]:
			ShaderWarmup.prime(pool, _warm_camera)


## Solid for most of its life, gone at the end: a fade from the start was too faint to see.
static func flash_alpha(flash: EffectsPlan.MuzzleFlash) -> float:
	return clampf(flash.remaining() / FLASH_FADE_FROM, 0.0, 1.0)


## The cone's apex at the muzzle, opening along the barrel, rolled about it, popping to full
## size as it fades. The cone mesh points along +Y, so +Y is turned to -X and the centre
## moved half a length forward.
static func flash_transform(flash: EffectsPlan.MuzzleFlash) -> Transform3D:
	var heading := flash.heading()
	var pop := lerpf(FLASH_POP_FROM, 1.0, 1.0 - flash.remaining())
	var basis := (
		Basis(Vector3.BACK, heading.angle())
		* Basis(Vector3.BACK, PI / 2.0)
		* Basis(Vector3.UP, flash.roll)
		* Basis.from_scale(Vector3.ONE * pop)
	)
	var centre := flash.where() + heading * (FLASH_LENGTH / 2.0 * pop)
	return Transform3D(basis, Vector3(centre.x, centre.y, 0.0))


static func casing_transform(casing: EffectsPlan.Casing) -> Transform3D:
	var basis := Basis.from_euler(Vector3(casing.angle * 0.7, 0.0, casing.angle))
	return Transform3D(basis, casing.position)


## The blob grown to the puff's scale, stretched to its kind's shape, risen with its age.
static func puff_transform(puff: EffectsPlan.Puff) -> Transform3D:
	var aspect: Vector2 = puff.look()["aspect"]
	var basis := Basis.from_scale(Vector3(aspect.x, aspect.y, 1.0) * puff.scale())
	var at := puff.position()
	return Transform3D(basis, Vector3(at.x, at.y, 0.0))


## A fleck pointing the way it flies.
static func spark_transform(spark: EffectsPlan.Spark) -> Transform3D:
	var basis := Basis(Vector3.BACK, spark.velocity.angle())
	return Transform3D(basis, Vector3(spark.position.x, spark.position.y, 0.0))


static func _flash_mesh() -> Mesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = FLASH_RADIUS
	cone.height = FLASH_LENGTH
	cone.radial_segments = 6
	cone.rings = 1
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = FLASH_COLOR
	material.emission_energy_multiplier = 2.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone.material = material
	return cone


static func _sphere_transform(at: Vector2, radius: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * radius), Vector3(at.x, at.y, 0.0))


## A unit sphere, low-poly. The flash is unshaded white; the Burst glows its own colour.
static func _sphere_mesh(flash: bool) -> Mesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if flash:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED  # the Muzzle Flash's shader, shared
	else:
		material.emission_enabled = true
		material.emission = EffectsPlan.BURST_COLOR
		material.emission_energy_multiplier = 1.5
	sphere.material = material
	return sphere


static func _puff_mesh() -> Mesh:
	var model: Node3D = CLOUD_MODEL.instantiate()
	var source: MeshInstance3D = model.find_child(PUFF_NODE, true, false)
	var mesh: Mesh = source.mesh.duplicate()
	model.free()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for surface in mesh.get_surface_count():
		mesh.surface_set_material(surface, material)
	return mesh


static func _spark_mesh() -> Mesh:
	var box := BoxMesh.new()
	box.size = SPARK_SIZE
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = SPARK_COLOR
	material.emission_energy_multiplier = 2.0
	box.material = material
	return box


static func _casing_mesh() -> Mesh:
	var box := BoxMesh.new()
	box.size = CASING_SIZE
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	box.material = material
	return box


func _make(instance_name: String, mesh: Mesh, cap: int) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = instance_name
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.multimesh = MultiMesh.new()
	instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	instance.multimesh.use_colors = true
	instance.multimesh.mesh = mesh
	instance.multimesh.instance_count = cap
	instance.multimesh.visible_instance_count = 0
	add_child(instance)
	return instance
