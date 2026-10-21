extends GdUnitTestSuite


func _hill() -> Terrain:
	return Terrain.from_points(
		PackedVector2Array(
			[Vector2(0.0, 10.0), Vector2(100.0, 10.0), Vector2(200.0, 60.0), Vector2(300.0, 10.0)]
		)
	)


func test_height_interpolates_between_points() -> void:
	var terrain := _hill()
	assert_float(terrain.height_at(50.0)).is_equal_approx(10.0, 0.001)
	assert_float(terrain.height_at(150.0)).is_equal_approx(35.0, 0.001)
	assert_float(terrain.height_at(200.0)).is_equal_approx(60.0, 0.001)
	assert_float(terrain.height_at(275.0)).is_equal_approx(22.5, 0.001)


func test_height_is_flat_beyond_the_ends() -> void:
	var terrain := _hill()
	assert_float(terrain.height_at(-50.0)).is_equal_approx(10.0, 0.001)
	assert_float(terrain.height_at(999.0)).is_equal_approx(10.0, 0.001)


func test_points_are_sorted_on_creation() -> void:
	var terrain := Terrain.from_points(
		PackedVector2Array([Vector2(100.0, 5.0), Vector2(0.0, 0.0), Vector2(50.0, 10.0)])
	)
	assert_float(terrain.height_at(25.0)).is_equal_approx(5.0, 0.001)


func test_below_surface_and_water() -> void:
	var terrain := _hill()
	terrain.add_water(120.0, 180.0)
	assert_bool(terrain.is_below_surface(Vector2(50.0, 9.0))).is_true()
	assert_bool(terrain.is_below_surface(Vector2(50.0, 10.0))).is_true()
	assert_bool(terrain.is_below_surface(Vector2(50.0, 11.0))).is_false()
	assert_bool(terrain.is_water_at(150.0)).is_true()
	assert_bool(terrain.is_water_at(50.0)).is_false()


func test_empty_terrain_is_flat_at_zero() -> void:
	var terrain := Terrain.new()
	assert_float(terrain.height_at(12.0)).is_equal(0.0)


func test_highest_within_a_radius_sees_the_hill_top() -> void:
	var terrain := _hill()
	assert_float(terrain.highest_within(150.0, 10.0)).is_equal_approx(40.0, 0.001)
	assert_float(terrain.highest_within(190.0, 20.0)).is_equal_approx(60.0, 0.001)
	assert_float(terrain.highest_within(50.0, 10.0)).is_equal_approx(10.0, 0.001)
