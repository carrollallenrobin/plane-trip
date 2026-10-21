extends GdUnitTestSuite
## Headless checks that the terrain slab is painted as planned: field strips from the seed,
## Water in its spans, a shore beside them, and the top following the terrain's heights.
## What the terrain means to the simulation is tested through the World.

const FLAT := [Vector2(0.0, 10.0), Vector2(960.0, 10.0)]


func _node(points: Array, water: Array[Vector2] = []) -> TerrainNode:
	var node: TerrainNode = auto_free(TerrainNode.new())
	node.points = PackedVector2Array(points)
	node.water_spans = water
	add_child(node)
	return node


## The vertices and colours along the top face's back edge, as [x, y, colour].
func _top(node: TerrainNode) -> Array:
	var mesh: ArrayMesh = node.get_child(0).mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var top := []
	for i in vertices.size():
		if is_equal_approx(vertices[i].z, -node.depth):
			top.append([vertices[i].x, vertices[i].y, colours[i]])
	return top


## Mesh colours are stored in 8 bits, so they are compared loosely.
func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func _has(colours: Array, colour: Color) -> bool:
	for c in colours:
		if _same(c, colour):
			return true
	return false


func _distinct(top: Array) -> Array:
	var seen := []
	for v in top:
		if not _has(seen, v[2]):
			seen.append(v[2])
	return seen


func _colours_at(top: Array, x: float) -> Array:
	var found := []
	for v in top:
		if is_equal_approx(v[0], x) and not _has(found, v[2]):
			found.append(v[2])
	return found


func test_the_top_is_striped_in_more_than_one_field_colour() -> void:
	var seen := _distinct(_top(_node(FLAT)))
	assert_int(seen.size()).is_greater(2)
	for colour in seen:
		assert_bool(_has(TerrainNode.FIELD_COLORS, colour)).is_true()


func test_neighbouring_strips_differ_and_the_seed_decides_them() -> void:
	var a := _node(FLAT)
	var b := _node(FLAT)
	assert_array(_top(a)).is_equal(_top(b))
	b.seed_value = 2
	assert_array(_top(b)).is_not_equal(_top(a))
	var strips := a._strips(a.to_terrain())
	for i in range(1, strips.size()):
		assert_int(int(strips[i].y)).is_not_equal(int(strips[i - 1].y))
		assert_float(strips[i].x - strips[i - 1].x).is_between(
			TerrainNode.STRIP_MIN, TerrainNode.STRIP_MAX
		)


func test_water_is_blue_with_a_shore_on_each_side() -> void:
	var node := _node(FLAT, [Vector2(400.0, 500.0)])
	var terrain := node.to_terrain()
	var strips := node._strips(terrain)
	var at := func(x: float) -> Color: return TerrainNode.surface_colour_at(x, terrain, strips)
	assert_bool(_same(at.call(450.0), TerrainNode.WATER_COLOR)).is_true()
	assert_bool(_same(at.call(398.0), TerrainNode.SHORE_COLOR)).is_true()
	assert_bool(_same(at.call(503.0), TerrainNode.SHORE_COLOR)).is_true()
	assert_bool(_has(TerrainNode.FIELD_COLORS, at.call(390.0))).is_true()
	var top := _top(node)
	assert_bool(_has(_colours_at(top, 400.0), TerrainNode.WATER_COLOR)).is_true()
	assert_bool(_has(_colours_at(top, 400.0), TerrainNode.SHORE_COLOR)).is_true()
	var shore_end := 500.0 + TerrainNode.SHORE_WIDTH
	assert_bool(_has(_colours_at(top, shore_end), TerrainNode.SHORE_COLOR)).is_true()
	assert_bool(_has(_distinct(top), TerrainNode.SIDE_COLOR)).is_false()


func test_the_top_follows_the_terrain_heights() -> void:
	var node := _node([Vector2(0.0, 10.0), Vector2(300.0, 60.0), Vector2(960.0, 10.0)])
	var terrain := node.to_terrain()
	var top := _top(node)
	for v in top:
		assert_float(v[1]).is_equal_approx(terrain.height_at(v[0]), 0.001)
	assert_array(_colours_at(top, 300.0)).is_not_empty()
