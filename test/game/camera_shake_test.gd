extends GdUnitTestSuite
## The shake's rule: trauma adds and decays, strength is its square, the view moves within
## its bounds, and a Blast counts by its distance.

const DT := 1.0 / 60.0


func test_trauma_adds_clamps_and_decays_away() -> void:
	var shake := CameraShake.new()
	assert_float(shake.trauma).is_equal(0.0)
	shake.add(0.4)
	shake.add(0.4)
	shake.add(0.4)
	assert_float(shake.trauma).is_equal(1.0)
	shake.advance(CameraShake.DECAY_SECONDS / 2.0)
	assert_float(shake.trauma).is_equal_approx(0.5, 0.001)
	shake.advance(CameraShake.DECAY_SECONDS)
	assert_float(shake.trauma).is_equal(0.0)


func test_strength_is_trauma_squared_and_the_view_stays_within_bounds() -> void:
	var shake := CameraShake.new()
	assert_vector(shake.offset()).is_equal(Vector2.ZERO)
	assert_float(shake.roll()).is_equal(0.0)
	shake.add(0.5)
	assert_float(shake.strength()).is_equal_approx(0.25, 0.001)
	var farthest := 0.0
	for i in 120:
		shake.advance(DT)
		shake.add(DT / CameraShake.DECAY_SECONDS)  # hold the trauma where it is
		var offset := shake.offset()
		assert_float(absf(offset.x)).is_less_equal(CameraShake.MAX_OFFSET * 0.25)
		assert_float(absf(offset.y)).is_less_equal(CameraShake.MAX_OFFSET * 0.25)
		assert_float(absf(shake.roll())).is_less_equal(CameraShake.MAX_ROLL * 0.25)
		farthest = maxf(farthest, offset.length())
	# Over two seconds the view really swings, not just trembles near the centre.
	assert_float(farthest).is_greater(CameraShake.MAX_OFFSET * 0.25 * 0.5)


func test_a_blast_shakes_by_how_near_it_was() -> void:
	var near := CameraShake.new()
	near.blast_at(0.0)
	assert_float(near.trauma).is_equal_approx(CameraShake.BLAST_TRAUMA, 0.001)
	var half := CameraShake.new()
	half.blast_at(CameraShake.BLAST_RANGE / 2.0)
	assert_float(half.trauma).is_equal_approx(CameraShake.BLAST_TRAUMA / 2.0, 0.001)
	var far := CameraShake.new()
	far.blast_at(CameraShake.BLAST_RANGE * 2.0)
	assert_float(far.trauma).is_equal(0.0)


func test_a_shot_kicks_the_view_back_along_the_nose_and_it_recovers() -> void:
	var shake := CameraShake.new()
	shake.recoil(Vector2.RIGHT)
	assert_vector(shake.offset()).is_equal_approx(
		Vector2(-CameraShake.GUN_KICK, 0.0), Vector2(0.001, 0.001)
	)
	shake.advance(CameraShake.KICK_RECOVERY)
	assert_float(shake.offset().x).is_equal_approx(-CameraShake.GUN_KICK * exp(-1.0), 0.001)
	shake.advance(FlightModel.GUN_INTERVAL)
	assert_float(absf(shake.offset().x)).is_less(CameraShake.GUN_KICK * 0.05)


func test_a_hit_knocks_the_view_the_way_the_round_flew_and_shakes_it() -> void:
	var shake := CameraShake.new()
	shake.hit(Vector2(0.0, -1.0))  # struck from above
	assert_float(shake.trauma).is_equal(CameraShake.HIT_TRAUMA)
	assert_float(shake.offset().y).is_less(-CameraShake.HIT_KICK * 0.9)
	var spinning := CameraShake.new()
	spinning.hit(Vector2(0.0, -1.0), true)
	assert_float(spinning.trauma).is_equal_approx(
		CameraShake.HIT_TRAUMA * CameraShake.SPIN_HIT_FACTOR, 0.001
	)
