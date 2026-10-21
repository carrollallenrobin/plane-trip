extends GdUnitTestSuite
## The Sway's rule: banking into the pitch change, a little noise in level flight, nothing
## when something else owns the roll.

const DT := 1.0 / 60.0
const PITCH_RATE := 122.0


func _flying(angle := 0.0) -> PlaneState:
	var s := TestLoadouts.plane(Side.BLUE, 1)
	s.angle = angle
	s.set_speed_along_nose(40.0)
	s.on_airfield = false
	return s


## Hold the plane pitching at `rate` degrees per second for `seconds`.
func _pitch(sway: Sway, state: PlaneState, rate: float, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		state.angle = wrapf(state.angle + rate * DT, 0.0, 360.0)
		sway.update(state, PITCH_RATE, DT)


## The bank a pitch rate adds over level flight: the same seed wanders the same way, so the
## difference between the two is the pitch's share alone.
func _bank_from_pitching(rate: float, heading := 0.0) -> float:
	var pitching := Sway.new(3)
	var level := Sway.new(3)
	var turning := _flying(heading)
	var straight := _flying(heading)
	_pitch(pitching, turning, rate, 1.0)
	_pitch(level, straight, 0.0, 1.0)
	return pitching.bank - level.bank


func test_it_banks_into_a_pull_up_to_the_limit_and_the_other_way_for_a_push() -> void:
	assert_float(_bank_from_pitching(PITCH_RATE)).is_equal_approx(Sway.MAX_BANK, 0.001)
	assert_float(_bank_from_pitching(-PITCH_RATE)).is_equal_approx(-Sway.MAX_BANK, 0.001)
	assert_float(_bank_from_pitching(PITCH_RATE / 2.0)).is_equal_approx(Sway.MAX_BANK / 2.0, 0.001)


func test_a_pull_heading_left_tilts_the_top_toward_the_camera_as_well() -> void:
	# Heading left, a pull is the angle decreasing: the bank goes the other way about the
	# node's nose axis, which the half-turned node makes the same way for the camera.
	assert_float(_bank_from_pitching(-PITCH_RATE, 180.0)).is_equal_approx(-Sway.MAX_BANK, 0.001)


func test_level_flight_only_wanders_within_the_noise() -> void:
	var sway := Sway.new(5)
	var state := _flying()
	var farthest := 0.0
	for i in 600:
		sway.update(state, PITCH_RATE, DT)
		farthest = maxf(farthest, absf(sway.bank))
	assert_float(farthest).is_less_equal(Sway.NOISE_BANK)
	assert_float(farthest).is_greater(0.0)


func test_it_eases_in_and_stands_down_when_something_else_owns_the_roll() -> void:
	var sway := Sway.new()
	var state := _flying()
	_pitch(sway, state, PITCH_RATE, DT * 2.0)
	assert_float(sway.bank).is_less(Sway.MAX_BANK / 2.0)  # not there yet
	_pitch(sway, state, PITCH_RATE, 1.0)
	state.in_spin = true
	assert_bool(Sway.owns_roll(state)).is_false()
	_pitch(sway, state, PITCH_RATE, 1.0)
	assert_float(absf(sway.bank)).is_less(0.001)
	state.in_spin = false
	state.roll_remaining = 0.1
	assert_bool(Sway.owns_roll(state)).is_false()
	state.roll_remaining = 0.0
	state.ceiling_spin_remaining = 1.0
	assert_bool(Sway.owns_roll(state)).is_false()
	state.ceiling_spin_remaining = 0.0
	state.on_airfield = true
	assert_bool(Sway.owns_roll(state)).is_false()
	state.on_airfield = false
	assert_bool(Sway.owns_roll(state)).is_true()
	sway.reset()
	assert_float(sway.bank).is_equal(0.0)
