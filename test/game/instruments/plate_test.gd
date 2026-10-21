extends GdUnitTestSuite
## The plate's rivets: the corners and a row along the long edges, whatever the size.


func test_a_short_plate_has_a_rivet_in_each_corner() -> void:
	var points := Plate.rivet_points(Vector2(100.0, 50.0))
	assert_int(points.size()).is_equal(4)
	assert_bool(points.has(Vector2(9.0, 9.0))).is_true()
	assert_bool(points.has(Vector2(91.0, 41.0))).is_true()


func test_a_long_plate_gets_rivets_along_the_edges_and_at_the_far_end() -> void:
	var points := Plate.rivet_points(Vector2(520.0, 130.0))
	# Every 110 from 9: 9, 119, 229, 339, 449, then the far end at 511; top and bottom.
	assert_int(points.size()).is_equal(12)
	assert_bool(points.has(Vector2(449.0, 121.0))).is_true()
	assert_bool(points.has(Vector2(511.0, 9.0))).is_true()


func test_the_needle_sweeps_from_bottom_left_over_the_top_to_bottom_right() -> void:
	assert_float(Dial.angle_for(0.0)).is_equal(135.0)
	assert_float(Dial.angle_for(0.5)).is_equal(270.0)
	assert_float(Dial.angle_for(1.0)).is_equal(405.0)
