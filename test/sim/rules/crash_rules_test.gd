extends GdUnitTestSuite

var _map: WorldMap


func before_test() -> void:
	_map = WorldMap.new()
	_map.bounds = WorldBounds.create(960.0, 160.0)
	_map.terrain = Terrain.from_points(
		PackedVector2Array([Vector2(0.0, 10.0), Vector2(960.0, 10.0)])
	)
	_map.terrain.add_water(400.0, 500.0)
	_map.airfields.append(Airfield.create(Side.BLUE, 20.0, 100.0, 10.0))


func _plane(x: float, y: float, angle := 0.0) -> PlaneState:
	var s := TestLoadouts.plane()
	s.position = Vector2(x, y)
	s.angle = angle
	return s


func test_flying_clear_of_everything_is_fine() -> void:
	assert_int(CrashRules.check(_plane(200.0, 50.0), _map)).is_equal(CrashRules.Outcome.NONE)


func test_nose_into_the_ground_is_a_terrain_crash() -> void:
	var s := _plane(200.0, 12.0, 300.0)  # nose 10 px long pointing down-right dips below 10
	assert_int(CrashRules.check(s, _map)).is_equal(CrashRules.Outcome.TERRAIN)


func test_wheels_into_the_ground_off_the_runway_is_a_crash() -> void:
	var s := _plane(200.0, 11.0)  # wheels 2 m below the fuselage
	assert_int(CrashRules.check(s, _map)).is_equal(CrashRules.Outcome.TERRAIN)


func test_touching_water_is_a_water_crash() -> void:
	var s := _plane(450.0, 11.0)
	assert_int(CrashRules.check(s, _map)).is_equal(CrashRules.Outcome.WATER)


func test_crossing_a_border_is_fatal() -> void:
	assert_int(CrashRules.check(_plane(-1.0, 50.0), _map)).is_equal(CrashRules.Outcome.BORDER)
	assert_int(CrashRules.check(_plane(961.0, 50.0), _map)).is_equal(CrashRules.Outcome.BORDER)


func test_a_plane_on_the_airfield_never_crashes() -> void:
	var s := _plane(50.0, 11.0)
	s.on_airfield = true
	assert_int(CrashRules.check(s, _map)).is_equal(CrashRules.Outcome.NONE)
	s.on_airfield = false
	assert_int(CrashRules.check(s, _map)).is_equal(CrashRules.Outcome.TERRAIN)


func test_a_runway_is_ground_to_a_plane_not_on_its_wheels() -> void:
	_map.airfields.append(Airfield.create(Side.RED, 600.0, 680.0, 14.0))  # raised above the terrain
	var s := _plane(640.0, 15.0, 300.0)  # nose dips below the runway at 14, above the ground at 10
	assert_int(CrashRules.check(s, _map)).is_equal(CrashRules.Outcome.TERRAIN)
	assert_int(CrashRules.check(_plane(640.0, 20.0, 300.0), _map)).is_equal(CrashRules.Outcome.NONE)


func test_the_nose_touching_the_runway_is_a_nose_over() -> void:
	var s := _plane(50.0, 11.0, 330.0)  # nose 4 m ahead pointing 30 degrees down: below 10
	s.on_airfield = true
	assert_int(CrashRules.check(s, _map)).is_equal(CrashRules.Outcome.TERRAIN)
