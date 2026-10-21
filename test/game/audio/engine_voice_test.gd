extends GdUnitTestSuite
## What a Plane sounds like from its state, on the pure EngineVoice: the engine spools,
## idles, sputters in a Spin and stops with the Plane; the airflow and the wheels follow
## the speed. No scene.

const DT := 1.0 / 60.0
const TOP := 72.0


func _state(speed: float, thrust: bool, on_airfield := false) -> PlaneState:
	var state := PlaneState.create(Airframe.new(), TestLoadouts.fighter())
	state.set_speed_along_nose(speed)
	state.thrust_on = thrust
	state.on_airfield = on_airfield
	return state


func _run(voice: EngineVoice, state: PlaneState, seconds: float, alive := true) -> void:
	for i in int(round(seconds * 60.0)):
		voice.update(state, alive, TOP, DT)


func test_the_engine_spools_up_with_the_throttle_and_down_without_it() -> void:
	var voice := EngineVoice.new()
	voice.update(_state(0.0, false), true, TOP, DT)
	assert_bool(voice.running).is_true()
	assert_float(voice.engine_pitch).is_equal_approx(EngineVoice.IDLE_PITCH, 0.01)
	assert_float(voice.engine_db).is_equal(EngineVoice.IDLE_DB)
	voice.update(_state(0.0, true), true, TOP, DT)
	assert_float(voice.engine_db).is_equal(EngineVoice.RUN_DB)
	assert_float(voice.engine_pitch).is_between(EngineVoice.IDLE_PITCH, EngineVoice.RUN_PITCH)
	_run(voice, _state(0.0, true), 3.0)
	assert_float(voice.engine_pitch).is_equal_approx(EngineVoice.RUN_PITCH, 0.01)
	_run(voice, _state(TOP, true), 3.0)
	assert_float(voice.engine_pitch).is_equal_approx(EngineVoice.TOP_PITCH, 0.01)
	_run(voice, _state(TOP, false), 3.0)
	assert_float(voice.engine_pitch).is_equal_approx(EngineVoice.IDLE_PITCH, 0.01)


func test_the_airflow_rises_with_speed_and_the_wheels_only_on_the_runway() -> void:
	var voice := EngineVoice.new()
	voice.update(_state(0.0, false), true, TOP, DT)
	assert_float(voice.airflow_db).is_equal(EngineVoice.AIRFLOW_QUIET_DB)
	assert_float(voice.rolling_db).is_equal(EngineVoice.SILENT_DB)
	voice.update(_state(TOP, true), true, TOP, DT)
	assert_float(voice.airflow_db).is_equal(EngineVoice.AIRFLOW_LOUD_DB)
	assert_float(voice.airflow_pitch).is_equal(EngineVoice.AIRFLOW_HIGH_PITCH)
	assert_float(voice.rolling_db).is_equal(EngineVoice.SILENT_DB)
	voice.update(_state(15.0, true, true), true, TOP, DT)
	assert_float(voice.rolling_db).is_between(
		EngineVoice.ROLLING_QUIET_DB, EngineVoice.ROLLING_LOUD_DB
	)
	voice.update(_state(40.0, true, true), true, TOP, DT)
	assert_float(voice.rolling_db).is_equal(EngineVoice.ROLLING_LOUD_DB)
	assert_float(voice.rolling_pitch).is_equal(EngineVoice.ROLLING_HIGH_PITCH)


func test_the_last_of_the_fuel_makes_the_engine_cough_and_a_stall_buffets_the_air() -> void:
	var voice := EngineVoice.new()
	var low := _state(50.0, true)
	low.fuel = EngineVoice.LOW_FUEL_SECONDS / 2.0
	var cut := 0
	for i in 120:
		voice.update(low, true, TOP, DT)
		if voice.engine_db < EngineVoice.RUN_DB:
			cut += 1
	# One cough in each of the two periods, about a seventh of the time.
	assert_int(cut).is_between(10, 24)
	var stalled := _state(15.0, false)
	stalled.stalled = true
	voice.update(stalled, true, TOP, DT)
	assert_float(voice.airflow_db).is_greater_equal(
		EngineVoice.BUFFET_FLOOR_DB + EngineVoice.BUFFET_DB
	)
	var shaken := 0
	for i in 60:
		voice.update(stalled, true, TOP, DT)
		if voice.airflow_db < EngineVoice.BUFFET_FLOOR_DB:
			shaken += 1
	assert_int(shaken).is_between(20, 40)
	stalled.on_airfield = true
	voice.update(stalled, true, TOP, DT)
	assert_float(voice.airflow_db).is_less(EngineVoice.BUFFET_FLOOR_DB + EngineVoice.BUFFET_DB)


func test_a_spin_sputters_and_a_gone_plane_is_silent() -> void:
	var voice := EngineVoice.new()
	var spinning := _state(40.0, false)
	spinning.in_spin = true
	var loud := 0
	var cut := 0
	for i in 60:
		voice.update(spinning, true, TOP, DT)
		if voice.engine_db <= EngineVoice.IDLE_DB + EngineVoice.SPUTTER_DB + 0.01:
			cut += 1
		else:
			loud += 1
	assert_int(loud).is_greater(cut)
	assert_int(cut).is_greater(10)
	voice.update(spinning, true, TOP, DT)
	var calm := _state(40.0, false)
	var calm_voice := EngineVoice.new()
	calm_voice.update(calm, true, TOP, DT)
	assert_float(voice.airflow_db).is_equal_approx(
		calm_voice.airflow_db + EngineVoice.SPIN_HOWL_DB, 0.001
	)
	voice.update(spinning, false, TOP, DT)
	assert_bool(voice.running).is_false()
	assert_float(voice.engine_db).is_equal(EngineVoice.SILENT_DB)
	assert_float(voice.airflow_db).is_equal(EngineVoice.SILENT_DB)
