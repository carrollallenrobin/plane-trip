extends GdUnitTestSuite


func test_a_burst_throws_pieces_around_the_velocity_of_what_broke() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var pieces := Debris.burst(Vector2(300.0, 80.0), Vector2(30.0, 0.0), rng)
	assert_int(pieces.size()).is_between(1, Debris.MAX_PARTS)
	for piece in pieces:
		assert_vector(piece.position).is_equal(Vector2(300.0, 80.0))
		assert_float(piece.velocity.x).is_between(
			30.0 - Debris.SPREAD / 2.0, 30.0 + Debris.SPREAD / 2.0
		)
		assert_float(piece.velocity.y).is_between(-Debris.SPREAD / 2.0, Debris.SPREAD / 2.0)
		assert_float(piece.size).is_between(0.4, 1.2)
		assert_bool(piece.settled).is_false()


func test_flying_objects_fall_under_gravity() -> void:
	var piece := Debris.new()
	piece.velocity = Vector2(10.0, 0.0)
	piece.advance(0.5, 9.0)
	assert_vector(piece.velocity).is_equal_approx(Vector2(10.0, -4.5), Vector2(0.001, 0.001))
	assert_vector(piece.position).is_equal_approx(Vector2(5.0, -2.25), Vector2(0.001, 0.001))
	piece.settle(3.0)
	assert_bool(piece.settled).is_true()
	assert_float(piece.position.y).is_equal(3.0)
