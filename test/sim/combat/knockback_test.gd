extends GdUnitTestSuite
## The knockback rule on its own: how far a hit shoves, in which direction, and when not.


func _flying(speed := 40.0) -> PlaneState:
	var s := TestLoadouts.plane()
	s.angle = 0.0
	s.set_speed_along_nose(speed)
	return s


func test_small_arms_shove_along_their_flight_by_the_damage() -> void:
	var s := _flying()
	Knockback.apply(s, Vector2(0.0, 1.0), DamageRules.Hit.of(DamageRules.Outcome.NONE, 8))
	assert_vector(s.vel).is_equal_approx(
		Vector2(40.0, 8.0 * Knockback.PER_POINT), Vector2(0.001, 0.001)
	)
	assert_float(s.speed).is_equal_approx(s.vel.length(), 0.001)


func test_a_blast_shoves_away_by_its_damage_up_to_the_full_shove() -> void:
	var s := _flying()
	Knockback.apply(s, Vector2(-1.0, 0.0), DamageRules.Hit.of(DamageRules.Outcome.NONE, 40, true))
	assert_float(s.vel.x).is_equal_approx(40.0 - Knockback.BLAST_MAX / 2.0, 0.001)
	var bombed := _flying()
	Knockback.apply(
		bombed, Vector2(0.0, 1.0), DamageRules.Hit.of(DamageRules.Outcome.EXPLODE, 1000, true)
	)
	assert_float(bombed.vel.y).is_equal_approx(Knockback.BLAST_MAX, 0.001)


func test_no_shove_when_parked_when_nothing_was_taken_or_without_a_direction() -> void:
	var parked := _flying(0.0)
	parked.on_airfield = true
	Knockback.apply(parked, Vector2(0.0, 1.0), DamageRules.Hit.of(DamageRules.Outcome.NONE, 8))
	assert_vector(parked.vel).is_equal(Vector2.ZERO)
	var grazed := _flying()
	Knockback.apply(grazed, Vector2(0.0, 1.0), DamageRules.Hit.of(DamageRules.Outcome.NONE, 0))
	assert_vector(grazed.vel).is_equal(Vector2(40.0, 0.0))
	Knockback.apply(grazed, Vector2.ZERO, DamageRules.Hit.of(DamageRules.Outcome.NONE, 8))
	assert_vector(grazed.vel).is_equal(Vector2(40.0, 0.0))
