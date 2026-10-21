@tool
class_name BackdropNode
extends Node3D
## The Backdrop: everything drawn behind the action that is not part of the World. Renders a
## BackdropPlan as a ground sheet and one MultiMesh per piece variant per layer, each layer
## at its depth behind the action so the perspective camera gives parallax for free
## (ADR 0001), its colours faded toward the sky by its depth (ADR 0006). The World knows
## nothing of it; WorldNode fits it to the World Map and the camera once at start, and in
## the editor it fits itself from the scene around it.

## The built pieces (ADR 0005), by the keys BackdropPlan.PIECES uses.
const MODELS := {
	"tree": preload("res://assets/models/tree.glb"),
	"hill": preload("res://assets/models/hill.glb"),
	"mountain": preload("res://assets/models/mountain.glb"),
	"cloud": preload("res://assets/models/cloud.glb"),
	"windmill": preload("res://assets/models/windmill.glb"),
	"factory": preload("res://assets/models/factory.glb"),
}
## The trees' material: it sways them.
const SWAY_SHADER := preload("res://src/game/backdrop/tree_sway.gdshader")
## The smoke puff and the flash are the Puff object of the cloud model, tinted.
const PUFF_NODE := "Puff"
const SMOKE_COLOR := Color(0.42, 0.42, 0.45)
const SMOKE_ALPHA := 0.7
const FLASH_COLOR := Color(1.0, 0.93, 0.55)
## A flash grows from this scale to this many times it before it is gone.
const FLASH_SCALE := 4.0
const FLASH_GROWTH := 2.0
## What far things fade toward: the sky's horizon colour in the mission scenes.
const HAZE_COLOR := Color(0.75, 0.82, 0.9)
## The ground sheet's colour before haze, the terrain's so the slab runs into it.
const GROUND_COLOR := TerrainNode.SURFACE_COLOR
## Depths the ground sheet's colour is graded at.
const GROUND_BANDS := [0.0, 120.0, 300.0, 600.0, 1000.0, 1700.0, BackdropPlan.GROUND_DEPTH]
## The camera the editor preview assumes when the scene has none.
const EDITOR_CAMERA_DISTANCE := 205.0
const EDITOR_CAMERA_FOV := 25.0

## Seed of the scatter: the same seed lays the same Backdrop out.
@export var seed_value := 1:
	set(value):
		seed_value = value
		if Engine.is_editor_hint() and is_inside_tree():
			_fit_from_scene()
## Whether distant artillery flashes in the hills: on for a mission on the front line.
@export var front_line := true

## The layout being shown, null until fitted.
var plan: BackdropPlan
## Seconds the trees have been swaying; what the sway shader is told each frame.
var sway_time := 0.0

## Every piece that moves: [placement, its MultiMesh, its index], so a frame only touches those.
var _drifting: Array = []
var _smoke: MultiMesh
var _flashes: MultiMesh
## The windmills' sails, turned every frame.
var _sails: Array[Node3D] = []
var _sway_materials: Array[ShaderMaterial] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		_fit_from_scene()


func _process(dt: float) -> void:
	if plan != null and not Engine.is_editor_hint():
		advance(dt)


## Move the Backdrop on by dt seconds: the clouds drift, the smoke rises, the guns flash.
## Runs on the render clock and stops with the scene tree; nothing here is simulation.
func advance(dt: float) -> void:
	plan.advance(dt)
	for entry in _drifting:
		entry[1].set_instance_transform(entry[2], placement_transform(entry[0]))
	_show_smoke()
	_show_flashes()
	for sails in _sails:
		sails.rotate_z(BackdropPlan.SAIL_RATE * dt)
	sway_time += dt
	for material in _sway_materials:
		material.set_shader_parameter("sway_time", sway_time)


## Lay the Backdrop out for a World of the given bounds as seen by a camera camera_distance
## in front of the action that shows view_half (half width and height) of the action plane,
## with the slab's trees on the terrain.
func fit(
	bounds: WorldBounds, camera_distance: float, view_half: Vector2, terrain: Terrain = null
) -> void:
	plan = BackdropPlan.create(bounds, camera_distance, view_half, seed_value, terrain, front_line)
	_drifting.clear()
	_sails.clear()
	_sway_materials.clear()
	for child in get_children():
		child.queue_free()
	add_child(_ground_sheet())
	for layer in plan.layers:
		for instance in _layer_instances(layer):
			add_child(instance)
	for feature in plan.features:
		add_child(_feature_instance(feature))
	_smoke = _puff_multimesh(BackdropPlan.MAX_PUFFS, SMOKE_COLOR, false)
	_flashes = _puff_multimesh(BackdropPlan.MAX_FLASHES, FLASH_COLOR, true)
	add_child(_puff_instance("Smoke", _smoke))
	add_child(_puff_instance("Flashes", _flashes))
	_show_smoke()
	_show_flashes()


## The MultiMesh instances of one layer, by name.
func layer_instances(layer_name: String) -> Array[MultiMeshInstance3D]:
	var found: Array[MultiMeshInstance3D] = []
	for child in get_children():
		if child is MultiMeshInstance3D and child.name.begins_with(layer_name):
			found.append(child)
	return found


## The colour a piece's material shows at depth: faded toward the sky.
static func hazed(colour: Color, depth: float) -> Color:
	return colour.lerp(HAZE_COLOR, BackdropPlan.haze_at(depth))


func _fit_from_scene() -> void:
	var parent := get_parent()
	var bounds := WorldBounds.new()
	if parent != null and parent.get("width") != null:
		bounds = WorldBounds.create(parent.get("width"), parent.get("ceiling_y"))
	var distance := EDITOR_CAMERA_DISTANCE
	var fov := EDITOR_CAMERA_FOV
	var camera: Camera3D = parent.get_node_or_null("Camera") if parent != null else null
	if camera != null:
		distance = camera.position.z
		fov = camera.fov
	var half_height := distance * tan(deg_to_rad(fov) / 2.0)
	var terrain_node: TerrainNode = parent.get_node_or_null("Terrain") if parent != null else null
	var terrain := terrain_node.to_terrain() if terrain_node != null else null
	fit(bounds, distance, Vector2(half_height * 16.0 / 9.0, half_height), terrain)


func _layer_instances(layer: BackdropPlan.Layer) -> Array[MultiMeshInstance3D]:
	var instances: Array[MultiMeshInstance3D] = []
	var model: Node3D = MODELS[layer.piece].instantiate()
	var piece: Dictionary = BackdropPlan.PIECES[layer.piece]
	for variant in piece["variants"].size():
		var placements := layer.placements.filter(
			func(p: BackdropPlan.Placement) -> bool: return p.variant == variant
		)
		if placements.is_empty():
			continue
		var source: MeshInstance3D = model.find_child(piece["variants"][variant], true, false)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		if layer.piece == "tree":
			multimesh.mesh = _swaying_mesh(source.mesh, layer.depth)
		else:
			multimesh.mesh = _hazed_mesh(source.mesh, layer.depth)
		multimesh.instance_count = placements.size()
		for i in placements.size():
			multimesh.set_instance_transform(i, placement_transform(placements[i]))
			if placements[i].drift != 0.0:
				_drifting.append([placements[i], multimesh, i])
		var instance := MultiMeshInstance3D.new()
		instance.name = layer.name + piece["variants"][variant]
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instances.append(instance)
	model.free()
	return instances


## A feature's model, placed and scaled as planned, its colours faded for its depth, its
## sails remembered for turning. Named after its kind, numbered from one.
func _feature_instance(feature: BackdropPlan.Feature) -> Node3D:
	var instance: Node3D = MODELS[feature.kind].instantiate()
	instance.name = feature.kind.capitalize() + str(features_of(feature.kind) + 1)
	for child in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = child
		mesh_instance.mesh = _hazed_mesh(mesh_instance.mesh, feature.depth)
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var placement := BackdropPlan.Placement.new()
	placement.position = feature.position
	placement.depth = feature.depth
	placement.scale = Vector2.ONE * feature.scale
	placement.turned = feature.turned
	instance.transform = placement_transform(placement)
	var spec: Dictionary = BackdropPlan.FEATURES[feature.kind]
	if spec.has("sails"):
		_sails.append(instance.find_child(spec["sails"], true, false))
	return instance


## How many of a kind of feature are in the scene so far.
func features_of(kind: String) -> int:
	var count := 0
	for child in get_children():
		if child.name.begins_with(kind.capitalize()):
			count += 1
	return count


## A MultiMesh of count puffs, each instance coloured and faded on its own; glowing ones
## emit colour. Nothing is shown until a puff is put in a slot; the rest are scaled away.
static func _puff_multimesh(count: int, colour: Color, glowing: bool) -> MultiMesh:
	var model: Node3D = MODELS["cloud"].instantiate()
	var source: MeshInstance3D = model.find_child(PUFF_NODE, true, false)
	var mesh: Mesh = source.mesh.duplicate()
	model.free()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true  # each instance brings its own colour
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glowing:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = 2.0
	for surface in mesh.get_surface_count():
		mesh.surface_set_material(surface, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	for i in count:
		multimesh.set_instance_transform(
			i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		)
	return multimesh


static func _puff_instance(instance_name: String, multimesh: MultiMesh) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = instance_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _show_smoke() -> void:
	for i in BackdropPlan.MAX_PUFFS:
		if i >= plan.puffs.size():
			_smoke.set_instance_transform(
				i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
			)
			continue
		var puff := plan.puffs[i]
		_smoke.set_instance_transform(i, _blob_transform(puff.position, puff.depth, puff.scale()))
		var colour := hazed(SMOKE_COLOR, puff.depth)
		colour.a = SMOKE_ALPHA * puff.remaining()
		_smoke.set_instance_color(i, colour)


func _show_flashes() -> void:
	for i in BackdropPlan.MAX_FLASHES:
		if i >= plan.flashes.size():
			_flashes.set_instance_transform(
				i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
			)
			continue
		var flash := plan.flashes[i]
		var scale := FLASH_SCALE * (1.0 + (FLASH_GROWTH - 1.0) * (1.0 - flash.remaining()))
		_flashes.set_instance_transform(i, _blob_transform(flash.position, flash.depth, scale))
		var colour := FLASH_COLOR
		colour.a = flash.remaining()
		_flashes.set_instance_color(i, colour)


static func _blob_transform(position: Vector2, depth: float, scale: float) -> Transform3D:
	return Transform3D(
		Basis.from_scale(Vector3.ONE * scale), Vector3(position.x, position.y, -depth)
	)


## Where a placed piece goes in the scene: at its position and depth behind the action,
## scaled as planned and turned about the vertical when the plan says so.
static func placement_transform(placement: BackdropPlan.Placement) -> Transform3D:
	var basis := Basis.from_euler(Vector3(0.0, PI if placement.turned else 0.0, 0.0))
	basis = basis.scaled(Vector3(placement.scale.x, placement.scale.y, placement.scale.x))
	var origin := Vector3(placement.position.x, placement.position.y, -placement.depth)
	return Transform3D(basis, origin)


## A copy of the mesh with every material's colour faded for the depth.
static func _hazed_mesh(mesh: Mesh, depth: float) -> Mesh:
	var copy: Mesh = mesh.duplicate()
	for surface in copy.get_surface_count():
		var material: StandardMaterial3D = copy.surface_get_material(surface).duplicate()
		material.albedo_color = hazed(material.albedo_color, depth)
		copy.surface_set_material(surface, material)
	return copy


## A copy of a tree mesh wearing the sway shader, one material per colour, faded for the
## depth. The materials are kept so every frame can tell them the time.
func _swaying_mesh(mesh: Mesh, depth: float) -> Mesh:
	var copy: Mesh = mesh.duplicate()
	for surface in copy.get_surface_count():
		var standard: StandardMaterial3D = copy.surface_get_material(surface)
		var material := ShaderMaterial.new()
		material.shader = SWAY_SHADER
		material.set_shader_parameter("albedo", hazed(standard.albedo_color, depth))
		copy.surface_set_material(surface, material)
		_sway_materials.append(material)
	return copy


## The ground the layers stand on: a flat sheet from under the slab to the far distance,
## graded toward the sky as it goes.
func _ground_sheet() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left := plan.ground_span.x
	var right := plan.ground_span.y
	var y := BackdropPlan.GROUND_Y
	for i in GROUND_BANDS.size() - 1:
		var near: float = GROUND_BANDS[i]
		var far: float = GROUND_BANDS[i + 1]
		var near_colour := hazed(GROUND_COLOR, near)
		var far_colour := hazed(GROUND_COLOR, far)
		var corners := [
			[Vector3(left, y, -near), near_colour],
			[Vector3(right, y, -near), near_colour],
			[Vector3(right, y, -far), far_colour],
			[Vector3(left, y, -far), far_colour],
		]
		for index in [0, 2, 1, 0, 3, 2]:  # clockwise from above: Godot's front face
			st.set_color(corners[index][1])
			st.set_normal(Vector3.UP)
			st.add_vertex(corners[index][0])
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	st.set_material(material)
	var instance := MeshInstance3D.new()
	instance.name = "Ground"
	instance.mesh = st.commit()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
