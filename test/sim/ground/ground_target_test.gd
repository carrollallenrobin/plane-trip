extends GdUnitTestSuite


func test_footprint_contains_points_in_the_box_with_a_little_slack_below() -> void:
	var t := GroundTarget.create(
		"house", Side.RED, GroundTarget.Kind.BUILDING, Vector2(100.0, 10.0), 10.0, 6.0
	)
	assert_bool(t.contains(Vector2(100.0, 13.0))).is_true()
	assert_bool(t.contains(Vector2(104.9, 15.9))).is_true()
	assert_bool(t.contains(Vector2(105.1, 13.0))).is_false()
	assert_bool(t.contains(Vector2(100.0, 9.0))).is_true()  # 1 m below the base: slack
	assert_bool(t.contains(Vector2(100.0, 5.0))).is_false()
	assert_bool(t.contains(Vector2(100.0, 19.0))).is_false()


func test_guns_take_damage_and_buildings_die_to_one_bomb() -> void:
	var gun := GroundTarget.create(
		"aa", Side.RED, GroundTarget.Kind.ANTI_AIRCRAFT_GUN, Vector2.ZERO, 6.0, 4.0
	)
	assert_bool(gun.damage(5)).is_false()
	assert_bool(gun.is_alive()).is_true()
	assert_bool(gun.damage(GroundTarget.BOMB_DAMAGE)).is_true()
	assert_bool(gun.is_alive()).is_false()
	assert_bool(gun.damage(5)).is_false()
	var house := GroundTarget.create(
		"h", Side.RED, GroundTarget.Kind.BUILDING, Vector2.ZERO, 10.0, 6.0
	)
	assert_int(house.hit_points).is_equal(GroundTarget.BUILDING_HIT_POINTS)
	assert_bool(house.damage(GroundTarget.BOMB_DAMAGE)).is_true()
