extends GdUnitTestSuite
## Behavioural tests for the flight model (docs/design.md, Flight; ADR 0004). The rules kept
## from the original (docs/research/triplane-classic-mechanics.md) have their own section.

const DT := 1.0 / 60.0
const FLIGHT_HEIGHT := 100.0

var _tuning: FlightTuning
var _model: FlightModel
var _env: FlightEnvironment


func before_test() -> void:
	_tuning = FlightTuning.new()
	_model = FlightModel.new(_tuning)
	_env = FlightEnvironment.new()


func _top() -> float:
	return _model.top_speed()


## A bare plane, nothing in its Slots: the airframe's own numbers. Weight has its own section.
func _airborne(angle: float, speed: float) -> PlaneState:
	var s := PlaneState.create(Airframe.new(), Loadout.new())
	s.position = Vector2(0.0, FLIGHT_HEIGHT)
	s.angle = angle
	s.set_speed_along_nose(speed)
	return s


func _on_runway(angle: float, speed: float) -> PlaneState:
	_env.runway_y = 0.0
	var s := _airborne(angle, speed)
	s.vel = Vector2(speed if s.heading_right() else -speed, 0.0)
	s.position.y -= s.wheel_point().y - FlightModel.TYRE_OFFSET - _env.runway_y
	s.on_airfield = true
	return s


func _fly(s: PlaneState, input: FlightInput, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_model.step(s, input, _env, DT)


func _controls(thrust := false, up := false, down := false, roll := false) -> FlightInput:
	var input := FlightInput.new()
	input.thrust = thrust
	input.pitch_up = up
	input.pitch_down = down
	input.roll = roll
	return input


## Hold the velocity level by trimming the nose each step: a crude autopilot for tests.
func _fly_level(s: PlaneState, thrust: bool, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		var input := _controls(thrust)
		var climb := s.vel.y
		if climb < -0.2:
			input.pitch_up = not s.upside_down
			input.pitch_down = s.upside_down
		elif climb > 0.2:
			input.pitch_down = not s.upside_down
			input.pitch_up = s.upside_down
		_model.step(s, input, _env, DT)


func test_thrust_is_propeller_like_capped_at_a_standstill_and_falling_with_speed() -> void:
	var s := _airborne(0.0, 0.0)
	assert_float(_model.thrust(s, 0.0)).is_equal(_tuning.static_acceleration)
	assert_float(_model.thrust(s, _top() / 2.0)).is_less(_tuning.static_acceleration)
	assert_float(_model.thrust(s, _top())).is_equal_approx(
		_model.drag_coefficient() * _top() * _top(), 0.001
	)


func test_level_full_power_settles_at_top_speed_and_is_punchy_early() -> void:
	var s := _airborne(0.0, 1.0)
	s.fuel = 60.0  # the bare plane's 30 s would run dry before it settles
	_fly_level(s, true, 1.5)
	assert_float(s.speed).is_greater(0.4 * _top())
	_fly_level(s, true, 40.0)
	assert_float(s.speed).is_equal_approx(_top(), 0.03 * _top())


func test_a_full_throttle_vertical_dive_approaches_the_terminal_factor() -> void:
	var s := _airborne(270.0, _top())
	s.position.y = 100000.0
	_fly(s, _controls(true), 30.0)
	var terminal := _tuning.dive_terminal_factor * _top()
	assert_float(s.speed).is_equal_approx(terminal, 0.03 * terminal)


func test_on_the_runway_the_brakes_stop_the_plane_unless_the_throttle_is_open() -> void:
	var landed := _on_runway(FlightModel.REST_PITCH, 30.0)
	var rolled := 0.0
	var seconds := 0.0
	while landed.speed > 0.0 and seconds < 10.0:
		var before := landed.position.x
		_fly(landed, _controls(false), DT)
		rolled += landed.position.x - before
		seconds += DT
	assert_float(landed.speed).is_equal(0.0)
	assert_float(seconds).is_less(5.0)
	assert_float(rolled).is_less(70.0)  # inside an 80 m runway
	# With the throttle open the brakes are off: the plane keeps rolling.
	var rolling := _on_runway(FlightModel.REST_PITCH, 30.0)
	_fly(rolling, _controls(true), 2.0)
	assert_float(rolling.speed).is_greater(20.0)


func test_closing_the_throttle_slows_by_drag_alone() -> void:
	var s := _airborne(0.0, _top())
	_fly_level(s, false, 5.0)
	assert_float(s.speed).is_between(0.6 * _top(), 0.8 * _top())


func test_lift_at_stall_speed_and_stall_angle_holds_the_plane_level() -> void:
	var lift := _model.lift_slope() * deg_to_rad(_tuning.stall_angle)
	lift *= _tuning.stall_speed * _tuning.stall_speed
	assert_float(lift).is_equal_approx(_tuning.gravity, 0.001)


func test_turn_rate_rises_with_speed_to_the_corner_then_falls() -> void:
	var corner := _tuning.corner_speed_fraction * _top()
	var at_stall := _model.max_turn_rate(_tuning.stall_speed)
	var at_corner := _model.max_turn_rate(corner)
	var at_top := _model.max_turn_rate(_top())
	assert_float(at_stall).is_between(25.0, 35.0)
	assert_float(at_corner).is_between(75.0, 85.0)
	assert_float(at_top).is_between(50.0, 60.0)
	assert_float(at_corner).is_greater(at_stall)
	assert_float(at_corner).is_greater(at_top)


func test_pulling_turns_the_velocity_and_loads_the_wing() -> void:
	var s := _airborne(0.0, 0.7 * _top())
	_fly(s, _controls(true, true), 0.3)
	assert_float(s.g_load).is_greater(3.0)
	assert_float(rad_to_deg(s.vel.angle())).is_between(10.0, 40.0)
	assert_float(s.angle_of_attack).is_greater(0.0)
	assert_bool(s.stalled).is_false()


func test_the_stick_cannot_hold_more_than_the_stall_angle() -> void:
	var s := _airborne(0.0, 0.7 * _top())
	_fly(s, _controls(true, true), 0.5)
	assert_float(s.angle_of_attack).is_between(_tuning.stall_angle - 1.0, _tuning.stall_angle + 0.5)
	assert_bool(s.stalled).is_false()


func test_pulling_hard_below_stall_speed_stalls_the_wing() -> void:
	# Throttle closed: with it open the static thrust would push the plane past stall speed.
	var s := _airborne(0.0, 0.9 * _tuning.stall_speed)
	_fly(s, _controls(false, true), 0.4)
	assert_bool(s.stalled).is_true()
	assert_float(s.g_load).is_less(1.0)
	assert_float(s.vel.y).is_less(0.0)


func test_a_stalled_plane_drops_its_nose_when_the_stick_is_released() -> void:
	var s := _airborne(0.0, 0.9 * _tuning.stall_speed)
	_fly(s, _controls(false, true), 0.4)
	var nose_up := wrapf(s.angle, -180.0, 180.0)
	_fly(s, _controls(true), 1.0)
	assert_float(wrapf(s.angle, -180.0, 180.0)).is_less(nose_up)
	assert_bool(s.stalled).is_false()


func test_climb_costs_what_a_dive_pays() -> void:
	# Without drag, gravity alone acts, and it is symmetric.
	_tuning.dive_terminal_factor = 100.0
	_tuning.induced_drag_factor = 0.0
	var diving := _airborne(300.0, 0.7 * _top())
	var climbing := _airborne(60.0, 0.7 * _top())
	_fly(diving, _controls(), 1.0)
	_fly(climbing, _controls(), 1.0)
	var gained := diving.speed - 0.7 * _top()
	var lost := 0.7 * _top() - climbing.speed
	assert_float(gained).is_greater(0.0)
	assert_float(lost).is_greater(0.0)
	assert_float(gained).is_equal_approx(lost, 0.25 * lost)


func test_takeoff_is_push_roll_pull() -> void:
	var s := _on_runway(FlightModel.REST_PITCH, 0.0)
	_fly(s, _controls(true, false, true), FlightModel.REST_PITCH / _tuning.pitch_rate)
	assert_float(s.pitch_in_body_frame()).is_between(-2.0, 2.0)
	_fly(s, _controls(true), 1.5)
	assert_bool(s.on_airfield).is_true()
	assert_float(s.speed).is_greater(_model.rotation_speed())
	assert_float(s.wheel_point().y).is_equal_approx(FlightModel.TYRE_OFFSET, 0.001)
	_fly(s, _controls(true, true), 0.4)
	assert_bool(s.on_airfield).is_false()
	assert_float(s.position.y).is_greater(FlightModel.WHEEL_OFFSET + 1.0)
	assert_float(s.vel.y).is_greater(0.0)


func test_beyond_the_ceiling_lift_is_cut_and_the_controls_lock_until_back_under() -> void:
	_env.ceiling_y = FLIGHT_HEIGHT
	var s := _airborne(90.0, 0.5 * _top())
	s.position.y = FLIGHT_HEIGHT + 0.5
	_model.step(s, _controls(true, true), _env, DT)
	assert_float(s.ceiling_spin_remaining).is_equal(FlightModel.CEILING_SPIN_DURATION)
	assert_float(s.g_load).is_equal(0.0)
	# Momentum carries the plane above the Ceiling, the off-screen cap stops the climb, and
	# gravity brings it back.
	_fly(s, _controls(true, true), 1.0)
	assert_float(s.position.y).is_between(
		FLIGHT_HEIGHT, FLIGHT_HEIGHT + FlightModel.CEILING_OFFSCREEN_MARGIN + 2.0
	)
	assert_float(s.ceiling_spin_remaining).is_equal(FlightModel.CEILING_SPIN_DURATION)
	var back_under := 0.0
	while s.position.y > FLIGHT_HEIGHT and back_under < 12.0:
		_model.step(s, _controls(true, true), _env, DT)
		back_under += DT
	assert_float(back_under).is_less(12.0)
	_fly(s, _controls(true, true), FlightModel.CEILING_SPIN_DURATION + 0.5)
	assert_float(s.ceiling_spin_remaining).is_equal(0.0)
	assert_float(s.position.y).is_less(FLIGHT_HEIGHT)


func test_hands_off_at_cruise_the_trim_holds_level_flight() -> void:
	var s := _airborne(0.0, 0.8 * _top())
	_fly(s, _controls(true), 6.0)
	assert_float(s.position.y).is_between(FLIGHT_HEIGHT - 6.0, FLIGHT_HEIGHT + 6.0)
	assert_float(absf(s.vel.y)).is_less(2.0)
	assert_float(s.g_load).is_between(0.8, 1.2)
	assert_float(s.angle_of_attack).is_greater(0.0)


func test_hands_off_inverted_the_trim_still_points_the_nose_at_the_sky() -> void:
	var s := _airborne(180.0, 0.8 * _top())
	s.upside_down = false  # heading left without the half-roll: canopy down
	_fly(s, _controls(true), 6.0)
	assert_float(s.position.y).is_between(FLIGHT_HEIGHT - 6.0, FLIGHT_HEIGHT + 6.0)
	assert_float(s.angle_of_attack).is_less(0.0)


func test_fully_off_the_screen_the_climb_is_cancelled() -> void:
	_env.ceiling_y = FLIGHT_HEIGHT
	var s := _airborne(90.0, _top())
	s.position.y = FLIGHT_HEIGHT + 0.5
	_fly(s, _controls(true, true), 2.0)
	var margin := FlightModel.CEILING_OFFSCREEN_MARGIN
	assert_float(s.position.y).is_less(FLIGHT_HEIGHT + margin + 2.0)
	assert_float(s.vel.y).is_less_equal(0.0)


# --- Weight (docs/design.md, Planes and Loadouts) ---


func test_an_empty_plane_has_the_whole_engine_and_a_loaded_one_less() -> void:
	var bare := _airborne(0.0, 0.0)
	assert_float(_model.weight_factor(bare)).is_equal(1.0)
	assert_float(_model.top_speed_of(bare)).is_equal(_top())
	# The fighter preset: 6 + 24 + 48 over 200, at the 0.2 penalty.
	var fighter := TestLoadouts.plane()
	assert_float(_model.weight_factor(fighter)).is_equal_approx(0.922, 0.001)
	assert_float(_model.thrust(fighter, 0.0)).is_equal_approx(
		0.922 * _tuning.static_acceleration, 0.1
	)
	var plates: Array[Fitting] = []
	for i in 6:
		plates.append(TestLoadouts.armour_plate())
	var armoured := PlaneState.create(Airframe.new(), Loadout.of(plates))
	assert_float(_model.weight_factor(armoured)).is_equal_approx(0.76, 0.001)


func test_a_loaded_plane_settles_at_its_own_lower_top_speed() -> void:
	var s := TestLoadouts.plane()
	s.position = Vector2(0.0, FLIGHT_HEIGHT)
	s.set_speed_along_nose(1.0)
	_fly_level(s, true, 40.0)
	var top := _model.top_speed_of(s)
	assert_float(top).is_less(0.95 * _top())
	assert_float(s.speed).is_equal_approx(top, 0.03 * _top())


func test_dropping_the_bombs_lightens_the_plane_and_nothing_else_does() -> void:
	var s := TestLoadouts.plane()
	var loaded := _model.top_speed_of(s)
	s.fuel = 0.0
	s.rounds = 0
	s.hit_points = 1
	assert_float(_model.top_speed_of(s)).is_equal(loaded)
	s.bombs = 0
	assert_float(_model.top_speed_of(s)).is_greater(loaded)
	assert_float(_model.weight_factor(s)).is_equal_approx(1.0 - 0.2 * 30.0 / 200.0, 0.001)


func test_the_turn_rate_and_the_runway_hold_do_not_care_about_weight() -> void:
	var s := TestLoadouts.plane()
	assert_float(_model.max_turn_rate(0.7 * _top())).is_between(75.0, 85.0)
	assert_float(_model.rotation_speed()).is_equal(_tuning.rotation_speed_fraction * _top())
	assert_float(_model.lift_cap()).is_equal(_model.lift_cap())
	s.bombs = 0
	assert_float(_model.max_turn_rate(0.7 * _top())).is_between(75.0, 85.0)


# --- Rules kept from the original ---


func test_landing_cone_matches_the_original_rule() -> void:
	_env.runway_y = 0.0
	# Heading right, wheels down.
	assert_bool(_wheels_on_runway_count(0.0, false)).is_true()
	assert_bool(_wheels_on_runway_count(20.0, false)).is_true()
	assert_bool(_wheels_on_runway_count(25.0, false)).is_false()
	assert_bool(_wheels_on_runway_count(350.0, false)).is_true()
	assert_bool(_wheels_on_runway_count(340.0, false)).is_false()
	# Heading left needs the half-roll, otherwise the wheels are up.
	assert_bool(_wheels_on_runway_count(180.0, false)).is_false()
	assert_bool(_wheels_on_runway_count(180.0, true)).is_true()
	assert_bool(_wheels_on_runway_count(165.0, true)).is_true()
	assert_bool(_wheels_on_runway_count(195.0, true)).is_false()


func _wheels_on_runway_count(angle: float, upside_down: bool) -> bool:
	var s := TestLoadouts.plane()
	s.angle = angle
	s.upside_down = upside_down
	s.position.y -= s.wheel_point().y - FlightModel.TYRE_OFFSET - _env.runway_y
	return FlightModel.is_on_runway(s, _env)


func test_wheels_in_the_air_above_a_runway_are_not_a_landing() -> void:
	_env.runway_y = 0.0
	var s := _airborne(0.0, 30.0)
	assert_bool(FlightModel.is_on_runway(s, _env)).is_false()


func test_a_fast_landing_counts_without_any_speed_check() -> void:
	_env.runway_y = 0.0
	var s := _airborne(350.0, 60.0)
	s.position.y -= s.wheel_point().y - FlightModel.TYRE_OFFSET - _env.runway_y
	s.position.y += 1.0
	_fly(s, _controls(), 0.3)
	assert_bool(s.on_airfield).is_true()
	assert_float(s.wheel_point().y).is_equal_approx(FlightModel.TYRE_OFFSET, 0.001)


func test_landed_plane_rolls_out_and_stops_tail_down() -> void:
	var s := _on_runway(0.0, 6.0)
	_fly(s, _controls(), 5.0)
	assert_float(s.speed).is_equal(0.0)
	assert_bool(s.on_airfield).is_true()
	assert_float(s.angle).is_equal_approx(FlightModel.REST_PITCH, 0.5)
	assert_float(s.wheel_point().y).is_equal_approx(FlightModel.TYRE_OFFSET, 0.001)


func test_pulling_before_rotation_speed_raises_the_nose_but_not_the_plane() -> void:
	var s := _on_runway(0.0, 0.5 * _model.rotation_speed())
	_fly(s, _controls(false, true), 0.1)
	assert_float(s.angle).is_greater(5.0)
	assert_bool(s.on_airfield).is_true()
	assert_float(s.wheel_point().y).is_equal_approx(FlightModel.TYRE_OFFSET, 0.001)


func test_the_tail_settles_by_itself_only_when_slow_and_hands_off() -> void:
	var s := _on_runway(0.0, 2.0)
	_fly(s, _controls(), 1.0)
	assert_float(s.angle).is_greater(5.0)


func test_no_gravity_or_stall_while_on_the_airfield() -> void:
	var s := _on_runway(FlightModel.REST_PITCH, 0.0)
	_fly(s, _controls(), 1.0)
	assert_bool(s.stalled).is_false()
	assert_float(s.speed).is_equal(0.0)
	assert_float(s.angle).is_equal_approx(FlightModel.REST_PITCH, 0.001)


func test_running_off_the_runway_end_over_level_ground_does_not_crash() -> void:
	# The wheel point rides a tyre's height above the runway, so a plane that leaves the
	# runway without lifting off skims the ground instead of hitting it, as in the original.
	var s := _on_runway(0.0, 20.0)
	_fly(s, _controls(true), 0.5)
	assert_bool(s.on_airfield).is_true()
	_env.runway_y = NAN
	_model.step(s, _controls(true), _env, DT)
	assert_bool(s.on_airfield).is_false()
	assert_float(s.wheel_point().y).is_greater(0.0)


func test_pushing_the_nose_into_the_runway_is_a_nose_over_not_a_takeoff() -> void:
	var s := _on_runway(0.0, 10.0)
	_fly(s, _controls(true, false, true), 0.2)  # about 24 degrees nose down
	assert_bool(s.on_airfield).is_true()
	assert_float(s.pitch_in_body_frame()).is_less(-FlightModel.LANDING_PITCH_DOWN_MAX)
	assert_float(s.wheel_point().y).is_equal_approx(FlightModel.TYRE_OFFSET, 0.001)


func test_half_roll_completes_in_three_original_ticks() -> void:
	var s := _airborne(0.0, 30.0)
	_model.step(s, _controls(false, false, false, true), _env, DT)
	assert_bool(s.upside_down).is_false()
	assert_float(s.roll_remaining).is_greater(0.0)
	_fly(s, _controls(), FlightModel.ROLL_DURATION)
	assert_bool(s.upside_down).is_true()
	assert_float(s.roll_remaining).is_equal(0.0)
	_fly(s, _controls(), 1.0)
	assert_bool(s.upside_down).is_true()


func test_roll_is_not_possible_on_the_ground() -> void:
	var s := _on_runway(20.0, 0.0)
	_fly(s, _controls(false, false, false, true), 0.5)
	assert_bool(s.upside_down).is_false()
	assert_float(s.roll_remaining).is_equal(0.0)


func test_thrust_burns_fuel_and_an_empty_tank_gives_none() -> void:
	var s := _airborne(0.0, 30.0)
	var full := s.max_fuel()
	_fly(s, _controls(true), 1.0)
	assert_float(s.fuel).is_equal_approx(full - 1.0, 0.001)
	_fly(s, _controls(), 1.0)
	assert_float(s.fuel).is_equal_approx(full - 1.0, 0.001)
	s.fuel = 0.0
	var before := s.speed
	_model.step(s, _controls(true), _env, DT)
	assert_bool(s.thrust_on).is_false()
	assert_float(s.speed).is_less(before)


func test_in_a_spin_the_engine_is_dead_and_the_stick_is_weak() -> void:
	var s := _airborne(0.0, 30.0)
	s.in_spin = true
	_fly(s, _controls(true, false, false, true), 0.5)
	assert_bool(s.thrust_on).is_false()
	assert_bool(s.upside_down).is_false()
	# Hands off, the nose drops toward the ground; pulling slows it but cannot hold level.
	var dropping := _airborne(0.0, 30.0)
	dropping.in_spin = true
	_fly(dropping, _controls(), 0.5)
	var pulling := _airborne(0.0, 30.0)
	pulling.in_spin = true
	_fly(pulling, _controls(false, true), 0.5)
	var dropped := wrapf(dropping.angle, -180.0, 180.0)
	var pulled := wrapf(pulling.angle, -180.0, 180.0)
	assert_float(dropped).is_less(-10.0)
	assert_float(pulled).is_between(dropped, 10.0)


func test_in_a_spin_the_air_brake_does_nothing() -> void:
	# The brake out-pulls gravity, so a braking spin would sink at a crawl for good.
	var falling := _airborne(0.0, 30.0)
	falling.in_spin = true
	var braking := _airborne(0.0, 30.0)
	braking.in_spin = true
	_fly(falling, _controls(), 1.0)
	_fly(braking, _controls(false, true, true), 1.0)
	assert_vector(braking.vel).is_equal_approx(falling.vel, Vector2(0.001, 0.001))
	assert_float(braking.vel.y).is_less(-5.0)


func test_a_spin_cannot_be_landed() -> void:
	_env.runway_y = 0.0
	var s := _airborne(0.0, 20.0)
	s.position.y -= s.wheel_point().y - FlightModel.TYRE_OFFSET - _env.runway_y
	assert_bool(FlightModel.is_on_runway(s, _env)).is_true()
	s.in_spin = true
	assert_bool(FlightModel.is_on_runway(s, _env)).is_false()


func test_gun_cooldown_counts_down_each_step() -> void:
	var s := _airborne(0.0, 30.0)
	s.gun_cooldown = FlightModel.GUN_INTERVAL
	_fly(s, _controls(), FlightModel.GUN_INTERVAL / 2.0)
	assert_float(s.gun_cooldown).is_between(0.05, FlightModel.GUN_INTERVAL / 2.0 + 0.01)
	_fly(s, _controls(), FlightModel.GUN_INTERVAL)
	assert_float(s.gun_cooldown).is_equal(0.0)
