extends GdUnitTestSuite
## Headless check that the runway is drawn where it can be seen: its top just above the
## terrain's surface, never flush with it. What an Airfield means is tested through the World.


func test_the_runway_top_stands_proud_of_the_surface() -> void:
	var node: AirfieldNode = auto_free(AirfieldNode.new())
	node.length = 80.0
	add_child(node)
	var runway: MeshInstance3D = node.get_child(0)
	var box: BoxMesh = runway.mesh
	var top := runway.position.y + box.size.y / 2.0
	assert_float(top).is_equal_approx(AirfieldNode.RUNWAY_PROUD, 0.001)
	assert_float(top).is_greater(0.0)
	assert_float(runway.position.x).is_equal_approx(40.0, 0.001)
