extends GdUnitTestSuite
## A Squadron's bookkeeping: slots, pool, spacing and being grounded. Planes are bare
## records; the World's spawning is tested in world_test.gd.

const DT := 1.0 / 60.0


func _plane() -> WorldPlane:
	return WorldPlane.create(
		Airframe.new(),
		TestLoadouts.fighter(),
		Side.RED,
		ScriptedPilot.holding(false),
		FlightModel.new()
	)


func _presets() -> Array[Loadout]:
	return [TestLoadouts.fighter(), Loadout.of([TestLoadouts.bomb_rack()])]


## Step until something is due or the time runs out; returns the slots due and the seconds
## it took from this call.
func _until_due(squadron: Squadron, limit: float) -> Array:
	var elapsed := 0.0
	while elapsed < limit:
		var due := squadron.step(DT)
		elapsed += DT
		if not due.is_empty():
			return [due, elapsed]
	return [[], elapsed]


func test_fills_every_slot_from_the_pool_spaced_by_the_interval() -> void:
	var squadron := Squadron.create(Side.RED, 3, 5, _presets(), 6.0)
	squadron.fill(0.0)
	assert_int(squadron.left()).is_equal(2)
	assert_int(squadron.aloft_count()).is_equal(0)
	var first := _until_due(squadron, 1.0)
	assert_array(first[0]).contains_exactly([0])
	assert_float(first[1]).is_less(0.02)  # the first at once
	squadron.occupy(0, _plane())
	var second := _until_due(squadron, 10.0)
	assert_array(second[0]).contains_exactly([1])
	assert_float(second[1]).is_equal_approx(6.0, 0.02)
	var third := _until_due(squadron, 10.0)
	assert_array(third[0]).contains_exactly([2])
	assert_float(third[1]).is_equal_approx(6.0, 0.02)  # 12 s from the start
	assert_array(squadron.step(DT)).is_empty()  # each slot is due once
	assert_bool(squadron.grounded(true)).is_false()


func test_a_slots_loadout_is_its_own_and_the_last_preset_repeats() -> void:
	var squadron := Squadron.create(Side.RED, 3, 0, _presets(), 0.0)
	assert_object(squadron.loadout_for(0)).is_same(squadron.loadouts[0])
	assert_object(squadron.loadout_for(1)).is_same(squadron.loadouts[1])
	assert_object(squadron.loadout_for(2)).is_same(squadron.loadouts[1])
	assert_object(Squadron.create(Side.RED, 1, 0, [], 0.0).loadout_for(0)).is_null()


func test_a_released_plane_frees_its_slot_for_the_next_after_the_delay() -> void:
	var squadron := Squadron.create(Side.RED, 2, 3, [], 0.0)
	squadron.fill(0.0)
	squadron.step(DT)
	var one := _plane()
	var two := _plane()
	squadron.occupy(0, one)
	squadron.occupy(1, two)
	assert_int(squadron.aloft_count()).is_equal(2)
	assert_bool(squadron.holds(one)).is_true()
	squadron.release(two)
	assert_bool(squadron.holds(two)).is_false()
	assert_int(squadron.aloft_count()).is_equal(1)
	squadron.fill(1.8)
	assert_int(squadron.left()).is_equal(0)
	var due := _until_due(squadron, 5.0)
	assert_array(due[0]).contains_exactly([1])
	assert_float(due[1]).is_equal_approx(1.8, 0.02)
	# The pool is spent: a further release schedules nothing.
	squadron.occupy(1, _plane())
	squadron.release(one)
	squadron.fill(1.8)
	assert_array(_until_due(squadron, 5.0)[0]).is_empty()


func test_the_interval_also_spaces_a_replacement_from_the_last_launch() -> void:
	var squadron := Squadron.create(Side.RED, 2, 0, [], 6.0)
	squadron.fill(0.0)
	squadron.step(DT)  # slot 0 at 0 s; slot 1 is set for 6 s
	var plane := _plane()
	squadron.occupy(0, plane)
	squadron.release(plane)
	squadron.fill(1.8)  # would be 1.8 s, but the last launch is at 6 s: so 12 s
	var first := _until_due(squadron, 20.0)
	assert_array(first[0]).contains_exactly([1])
	assert_float(first[1]).is_equal_approx(6.0, 0.02)
	var second := _until_due(squadron, 20.0)
	assert_array(second[0]).contains_exactly([0])
	assert_float(second[1]).is_equal_approx(6.0, 0.02)  # 12 s from the start


func test_an_unlimited_pool_never_runs_dry() -> void:
	var squadron := Squadron.create(Side.RED, 1, Squadron.UNLIMITED, [], 0.0)
	assert_int(squadron.left()).is_equal(-1)
	for life in 20:
		squadron.fill(0.0)
		assert_array(squadron.step(DT)).contains_exactly([0])
		var plane := _plane()
		squadron.occupy(0, plane)
		squadron.release(plane)
	assert_int(squadron.left()).is_equal(-1)
	assert_bool(squadron.grounded(true)).is_false()


func test_grounded_once_nothing_is_aloft_and_nothing_can_come() -> void:
	var squadron := Squadron.create(Side.RED, 1, 1, [], 0.0)
	assert_bool(squadron.grounded(true)).is_false()  # the pool still has one
	squadron.fill(0.0)
	assert_bool(squadron.grounded(true)).is_false()  # scheduled
	squadron.step(DT)
	var plane := _plane()
	squadron.occupy(0, plane)
	assert_bool(squadron.grounded(true)).is_false()  # aloft
	assert_bool(squadron.grounded(false)).is_false()  # aloft, whatever the Hangar
	squadron.release(plane)
	squadron.fill(0.0)
	assert_bool(squadron.grounded(true)).is_true()  # the pool is spent
	var endless := Squadron.create(Side.RED, 1, Squadron.UNLIMITED, [], 0.0)
	assert_bool(endless.grounded(true)).is_false()
	assert_bool(endless.grounded(false)).is_true()  # the Hangar is gone


func test_no_slots_means_no_planes() -> void:
	var none := Squadron.create(Side.BLUE, 0, 0, [], 0.0)
	none.fill(0.0)
	assert_array(none.step(DT)).is_empty()
	assert_int(none.aloft_count()).is_equal(0)
	assert_bool(none.grounded(true)).is_true()
