extends GdUnitTestSuite


func _map() -> WorldMap:
	var map := WorldMap.new()
	map.bounds = WorldBounds.create(960.0, 160.0)
	map.terrain = Terrain.from_points(
		PackedVector2Array([Vector2(0.0, 10.0), Vector2(960.0, 10.0)])
	)
	map.airfields.append(Airfield.create(Side.BLUE, 20.0, 100.0, 10.0))
	map.airfields.append(Airfield.create(Side.RED, 800.0, 900.0, 10.0))
	return map


func test_environment_has_runway_only_over_an_airfield() -> void:
	var map := _map()
	var over := map.environment_at(50.0)
	var off := map.environment_at(500.0)
	assert_bool(over.has_runway()).is_true()
	assert_float(over.runway_y).is_equal(10.0)
	assert_bool(off.has_runway()).is_false()
	assert_float(off.ceiling_y).is_equal(160.0)


func test_home_airfield_is_the_sides_first_airfield() -> void:
	var map := _map()
	assert_object(map.home_airfield(Side.RED)).is_same(map.airfields[1])
	assert_object(map.home_airfield(Side.BLUE)).is_same(map.airfields[0])


func test_borders() -> void:
	var bounds := WorldBounds.create(960.0, 160.0)
	assert_bool(bounds.is_outside(-0.1)).is_true()
	assert_bool(bounds.is_outside(0.0)).is_false()
	assert_bool(bounds.is_outside(960.0)).is_false()
	assert_bool(bounds.is_outside(960.1)).is_true()


func test_a_plane_starts_near_the_take_off_end_resting_on_its_wheels() -> void:
	var right := Airfield.create(Side.BLUE, 20.0, 100.0, 10.0)
	var left := Airfield.create(Side.RED, 800.0, 900.0, 10.0)
	left.heading_right = false
	var rest_height := 10.0 + FlightModel.WHEEL_OFFSET + FlightModel.TYRE_OFFSET
	assert_vector(right.spawn_position()).is_equal(Vector2(30.0, rest_height))
	assert_vector(left.spawn_position()).is_equal(Vector2(890.0, rest_height))
