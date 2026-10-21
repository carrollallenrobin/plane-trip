extends GdUnitTestSuite

const DT := 1.0 / 60.0

var _rearm: Rearm


func before_test() -> void:
	_rearm = Rearm.new()


func _depleted() -> PlaneState:
	var s := TestLoadouts.plane()
	s.fuel = 0.0
	s.rounds = 0
	s.bombs = 0
	s.hit_points = 3
	return s


func _run(s: PlaneState, on_own_airfield: bool, seconds: float) -> bool:
	var completed := false
	for i in int(round(seconds / DT)):
		completed = _rearm.update(s, on_own_airfield, DT) or completed
	return completed


func test_everything_refills_over_the_duration() -> void:
	var s := _depleted()
	# One extra step so float accumulation cannot leave progress a hair under one half.
	var completed := _run(s, true, Rearm.DURATION / 2.0 + DT)
	assert_bool(completed).is_false()
	assert_float(s.fuel).is_equal_approx(s.max_fuel() / 2.0, 0.5)
	assert_int(s.rounds).is_between(44, 46)
	assert_int(s.bombs).is_equal(2)
	completed = _run(s, true, Rearm.DURATION / 2.0 + DT)
	assert_bool(completed).is_true()
	assert_bool(Rearm.is_complete(s)).is_true()
	assert_int(s.hit_points).is_equal(s.max_hit_points())


func test_only_on_own_airfield_and_only_when_stopped() -> void:
	var s := _depleted()
	_run(s, false, 2.0)
	assert_float(s.fuel).is_equal(0.0)
	s.speed = 1.0
	_run(s, true, 2.0)
	assert_float(s.fuel).is_equal(0.0)


func test_moving_off_resets_progress_but_keeps_what_was_restored() -> void:
	var s := _depleted()
	_run(s, true, 1.0)
	var fuel_after_one_second := s.fuel
	assert_float(fuel_after_one_second).is_greater(0.0)
	_run(s, false, DT)
	assert_bool(_rearm.is_active()).is_false()
	assert_float(s.fuel).is_equal(fuel_after_one_second)


func test_partial_loads_are_never_reduced() -> void:
	var s := _depleted()
	s.fuel = s.max_fuel()  # full tank, empty guns
	_run(s, true, 1.0)
	assert_float(s.fuel).is_equal(s.max_fuel())
	assert_int(s.rounds).is_greater(0)


func test_a_full_plane_does_not_start_rearming() -> void:
	var s := TestLoadouts.plane()
	assert_bool(_rearm.update(s, true, DT)).is_false()
	assert_bool(_rearm.is_active()).is_false()
