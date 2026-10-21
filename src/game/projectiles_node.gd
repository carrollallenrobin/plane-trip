class_name ProjectilesNode
extends Node3D
## Draws everything flying free in the World: bullets as Tracers, Bombs as the bomb model and
## Shells as small boxes pointing along their velocity, Debris as tumbling chunks, one
## multimesh per kind.
## Picture only (ADR 0007): it reads the World's lists after each step and keeps nothing.

const CAPACITY := 512
const DEBRIS_COLOR := Color(0.25, 0.22, 0.2)

const TRACER_SHADER := preload("res://src/game/tracer.gdshader")
## Built by scripts/build-models.sh from art/models/bomb.py (ADR 0005); the same model hangs
## under a plane (PlaneNode).
const BOMB_MODEL := preload("res://assets/models/bomb.glb")
const BOMB_NODE := "Bomb"
## A Flak Gun's Shell: bigger than a round and glowing hot, so it can be watched up.
const SHELL_SIZE := Vector3(1.8, 0.5, 0.5)
const SHELL_COLOR := Color(1.0, 0.45, 0.2)
## A Tracer's bright head, metres, and its width.
const TRACER_HEAD := 2.5
const TRACER_WIDTH := 0.3
## The tail reaches back to where the round was this long ago.
const TRACER_TAIL_SECONDS := 0.3
## Planes' rounds are yellow-white; ground guns' rounds are tinted red to tell whose fire
## is in the air.
const TRACER_COLOR := Color(1.0, 0.95, 0.7)
const GROUND_TRACER_COLOR := Color(1.0, 0.45, 0.3)

var _tracers: MultiMeshInstance3D
var _bombs: MultiMeshInstance3D
var _shells: MultiMeshInstance3D
var _debris: MultiMeshInstance3D
var _warm_camera: Camera3D
var _warm_frames := 0


func _ready() -> void:
	_tracers = _make_tracers()
	_bombs = _make("Bombs", Vector3.ONE, Color.WHITE)
	_bombs.multimesh.mesh = bomb_mesh()
	_shells = _make("Shells", SHELL_SIZE, SHELL_COLOR)
	var hot: StandardMaterial3D = _shells.multimesh.mesh.material
	hot.emission_enabled = true
	hot.emission = SHELL_COLOR
	hot.emission_energy_multiplier = 1.5
	_debris = _make("Debris", Vector3(1.0, 0.6, 0.6), DEBRIS_COLOR)


## Draw a speck of every pool for a few frames, so their shaders compile now (ShaderWarmup).
func warm_up(camera: Camera3D) -> void:
	_warm_camera = camera
	_warm_frames = ShaderWarmup.FRAMES


func show_in_flight(
	bullets: Array[Bullet], bombs: Array[Bomb], shells: Array[Shell], debris: Array[Debris]
) -> void:
	var tracers := mini(bullets.size(), CAPACITY)
	_tracers.multimesh.visible_instance_count = tracers
	for i in tracers:
		_tracers.multimesh.set_instance_transform(i, tracer_transform(bullets[i]))
		_tracers.multimesh.set_instance_color(i, tracer_colour(bullets[i]))
	_show(_bombs, bombs)
	_show(_shells, shells)
	var count := mini(debris.size(), CAPACITY)
	_debris.multimesh.visible_instance_count = count
	for i in count:
		var piece := debris[i]
		var basis := Basis(Vector3.BACK, piece.angle).scaled(Vector3.ONE * piece.size)
		_debris.multimesh.set_instance_transform(
			i, Transform3D(basis, Vector3(piece.position.x, piece.position.y, 0.0))
		)
	if _warm_frames > 0 and _warm_camera != null:
		_warm_frames -= 1
		for pool in [_tracers, _bombs, _shells, _debris]:
			ShaderWarmup.prime(pool, _warm_camera)


## The streak's whole length: the head plus the tail, which is as long as the round has
## flown in the last TRACER_TAIL_SECONDS, so it never reaches back past the muzzle.
static func tracer_length(bullet: Bullet) -> float:
	return TRACER_HEAD + minf(bullet.age, TRACER_TAIL_SECONDS) * bullet.velocity.length()


## The unit box stretched to the streak's length along the round's flight, its leading end
## (local +X) at the round's position.
static func tracer_transform(bullet: Bullet) -> Transform3D:
	var length := tracer_length(bullet)
	var direction := bullet.velocity.normalized()
	var basis := (
		Basis(Vector3.BACK, bullet.velocity.angle()) * Basis.from_scale(Vector3(length, 1.0, 1.0))
	)
	var centre := bullet.position - direction * (length / 2.0)
	return Transform3D(basis, Vector3(centre.x, centre.y, 0.0))


## The bomb model's mesh with its own materials, for the MultiMesh.
static func bomb_mesh() -> Mesh:
	var model: Node3D = BOMB_MODEL.instantiate()
	var source: MeshInstance3D = model.find_child(BOMB_NODE, true, false)
	var mesh: Mesh = source.mesh
	model.free()
	return mesh


static func tracer_colour(bullet: Bullet) -> Color:
	return GROUND_TRACER_COLOR if bullet.owner_id < 0 else TRACER_COLOR


static func _show(instance: MultiMeshInstance3D, objects: Array) -> void:
	var count := mini(objects.size(), CAPACITY)
	instance.multimesh.visible_instance_count = count
	for i in count:
		var object: FlyingObject = objects[i]
		instance.multimesh.set_instance_transform(i, _transform(object.position, object.velocity))


static func _transform(position: Vector2, velocity: Vector2) -> Transform3D:
	var basis := Basis(Vector3.BACK, velocity.angle())
	return Transform3D(basis, Vector3(position.x, position.y, 0.0))


func _make_tracers() -> MultiMeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = TRACER_SHADER
	material.set_shader_parameter("head_length", TRACER_HEAD)
	var instance := _make("Tracers", Vector3(1.0, TRACER_WIDTH, TRACER_WIDTH), Color.WHITE, true)
	instance.multimesh.mesh.material = material
	return instance


func _make(
	name: String, size: Vector3, colour: Color, per_instance_colour := false
) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = name
	instance.multimesh = MultiMesh.new()
	instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	instance.multimesh.use_colors = per_instance_colour  # before the count, which locks it
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	mesh.material = material
	instance.multimesh.mesh = mesh
	instance.multimesh.instance_count = CAPACITY
	instance.multimesh.visible_instance_count = 0
	add_child(instance)
	return instance
