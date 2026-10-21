@tool
class_name TerrainNode
extends Node3D
## Renders a heightfield Terrain as a slab and reads it into the simulation. Edit the
## surface points in the inspector; the mesh rebuilds live in the editor (ADR 0003). The top
## is painted in field strips from a seed, with a shore along every stretch of Water: dressing
## that is part of the Backdrop's look (ADR 0006) and means nothing to the simulation.

## The plain grass the Backdrop's ground sheet continues from.
const SURFACE_COLOR := Color(0.36, 0.52, 0.24)
const WATER_COLOR := Color(0.2, 0.4, 0.7)
const SIDE_COLOR := Color(0.35, 0.28, 0.2)
## Sand and mud at the edge of Water.
const SHORE_COLOR := Color(0.60, 0.55, 0.38)
## The fields the top is striped with: grass, meadow, dark pasture, stubble and plough.
const FIELD_COLORS := [
	SURFACE_COLOR,
	Color(0.44, 0.58, 0.27),
	Color(0.30, 0.47, 0.22),
	Color(0.62, 0.56, 0.30),
	Color(0.42, 0.32, 0.20),
]
## How wide a shore is, on the land side of a Water edge.
const SHORE_WIDTH := 5.0
## How wide a field strip can be.
const STRIP_MIN := 25.0
const STRIP_MAX := 70.0

## Surface points in world metres, sorted by x.
@export var points := PackedVector2Array([Vector2(0.0, 10.0), Vector2(960.0, 10.0)]):
	set(value):
		points = value
		_rebuild()
## Horizontal spans [start_x, end_x] that are Water.
@export var water_spans: Array[Vector2] = []:
	set(value):
		water_spans = value
		_rebuild()
## How far the slab extends toward and away from the camera.
@export var depth := 40.0:
	set(value):
		depth = value
		_rebuild()
## The bottom of the slab.
@export var bottom_y := -20.0:
	set(value):
		bottom_y = value
		_rebuild()
## Seed of the field strips: the same seed paints the same fields.
@export var seed_value := 1:
	set(value):
		seed_value = value
		_rebuild()

var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_rebuild()


func to_terrain() -> Terrain:
	var terrain := Terrain.from_points(points)
	for span in water_spans:
		terrain.add_water(span.x, span.y)
	return terrain


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance)
	_mesh_instance.mesh = _build_mesh(to_terrain())


func _build_mesh(terrain: Terrain) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var strips := _strips(terrain)
	var xs := _breakpoints(terrain, strips)
	for i in xs.size() - 1:
		var a := Vector2(xs[i], terrain.height_at(xs[i]))
		var b := Vector2(xs[i + 1], terrain.height_at(xs[i + 1]))
		var along := (b - a).normalized()
		var up := Vector3(-along.y, along.x, 0.0)
		st.set_color(surface_colour_at((a.x + b.x) / 2.0, terrain, strips))
		_quad(
			st,
			Vector3(a.x, a.y, depth),
			Vector3(b.x, b.y, depth),
			Vector3(b.x, b.y, -depth),
			Vector3(a.x, a.y, -depth),
			up
		)
		st.set_color(SIDE_COLOR)
		_quad(
			st,
			Vector3(a.x, bottom_y, depth),
			Vector3(b.x, bottom_y, depth),
			Vector3(b.x, b.y, depth),
			Vector3(a.x, a.y, depth),
			Vector3.BACK
		)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(material)
	return st.commit()


## The colour of the top at x: Water, a shore beside it, or the field strip it falls in.
## strips are the field strips from _strips(); they are passed in so one build shares them.
static func surface_colour_at(x: float, terrain: Terrain, strips: Array) -> Color:
	if terrain.is_water_at(x):
		return WATER_COLOR
	for span in terrain.water_spans:
		if x >= span.x - SHORE_WIDTH and x <= span.y + SHORE_WIDTH:
			return SHORE_COLOR
	var colour: Color = FIELD_COLORS[0]
	for strip in strips:
		if x >= strip.x:
			colour = FIELD_COLORS[int(strip.y)]
	return colour


## The field strips across the terrain from the seed: (start x, colour index) in x order,
## no two neighbours the same colour.
func _strips(terrain: Terrain) -> Array:
	var strips := []
	if terrain.points.is_empty():
		return strips
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var x := terrain.points[0].x
	var last := -1
	while x < terrain.points[terrain.points.size() - 1].x:
		var index := rng.randi_range(0, FIELD_COLORS.size() - 2)
		if index >= last:
			index += 1
		strips.append(Vector2(x, index))
		last = index
		x += rng.randf_range(STRIP_MIN, STRIP_MAX)
	return strips


## Every x where the top changes slope or colour, sorted, within the terrain.
func _breakpoints(terrain: Terrain, strips: Array) -> PackedFloat32Array:
	var first := terrain.points[0].x
	var last := terrain.points[terrain.points.size() - 1].x
	var xs := PackedFloat32Array()
	for p in terrain.points:
		xs.append(p.x)
	for strip in strips:
		xs.append(strip.x)
	for span in terrain.water_spans:
		for x in [span.x - SHORE_WIDTH, span.x, span.y, span.y + SHORE_WIDTH]:
			xs.append(clampf(x, first, last))
	xs.sort()
	var unique := PackedFloat32Array()
	for x in xs:
		if unique.is_empty() or x > unique[unique.size() - 1] + 0.001:
			unique.append(x)
	return unique


static func _quad(
	st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3
) -> void:
	for v in [v0, v1, v2, v0, v2, v3]:
		st.set_normal(normal)
		st.add_vertex(v)
