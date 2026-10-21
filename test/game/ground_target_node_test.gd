extends GdUnitTestSuite
## Headless checks that a GroundTargetNode shows the built model for its kind, scaled to the
## target's size and painted for its Side, and swaps to the ruin when destroyed. The rules
## of damage and destruction are tested through the World.

const SCENE := "res://missions/strike_the_depot.tscn"


func _scene() -> WorldNode:
	var runner := scene_runner(SCENE)
	return runner.scene()


func _target(node: WorldNode, target_name: String) -> GroundTargetNode:
	return node.get_node(target_name)


func _side_colours(model: SideModel) -> Array[Color]:
	var colours: Array[Color] = []
	for material in model.materials:
		if material.resource_name == SideModel.SIDE_MATERIAL:
			colours.append(material.albedo_color)
	return colours


func test_every_kind_shows_a_model_with_meshes() -> void:
	var node := _scene()
	for target_name in ["Depot", "AAGun", "Flak", "EnemyHangar"]:
		var target := _target(node, target_name)
		assert_object(target.model).is_not_null()
		assert_int(target.model.find_children("*", "MeshInstance3D", true, false).size()).is_equal(
			1
		)
		assert_array(target.model.materials).is_not_empty()


func test_the_model_wears_the_sides_colour() -> void:
	var node := _scene()
	assert_array(_side_colours(_target(node, "EnemyHangar").model)).contains_exactly(
		[Side.colour(Side.RED)]
	)
	assert_array(_side_colours(_target(node, "HomeHangar").model)).contains_exactly(
		[Side.colour(Side.BLUE)]
	)


func test_buildings_stretch_to_their_size_and_guns_scale_uniformly() -> void:
	var node := _scene()
	var depot := _target(node, "Depot")  # 14 by 8, built 12 by 6
	assert_vector(depot.model.scale).is_equal_approx(
		Vector3(14.0 / 12.0, 8.0 / 6.0, 1.0), Vector3.ONE * 0.001
	)
	var flak := _target(node, "Flak")  # 6 by 4, built 6 by 4
	assert_vector(flak.model.scale).is_equal_approx(Vector3.ONE, Vector3.ONE * 0.001)
	flak.height = 6.0
	assert_vector(flak.model.scale).is_equal_approx(Vector3.ONE * 1.5, Vector3.ONE * 0.001)


func test_a_destroyed_target_shows_the_ruin_stretched_to_its_width() -> void:
	var node := _scene()
	var depot := _target(node, "Depot")
	var before := depot.model
	depot.show_destroyed()  # what WorldNode calls on the TARGET_DESTROYED event
	assert_object(depot.model).is_not_same(before)
	assert_bool(before.is_queued_for_deletion()).is_true()
	assert_array(_side_colours(depot.model)).is_empty()
	assert_vector(depot.model.scale).is_equal_approx(
		Vector3(14.0 / GroundTargetNode.RUIN_WIDTH, 1.0, 1.0), Vector3.ONE * 0.001
	)
