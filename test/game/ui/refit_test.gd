extends GdUnitTestSuite
## The Refit choice: counts per Fitting against the Slots, from a Loadout and back to one.

var _airframe: Airframe
var _fittings: Array[Fitting] = []


func before_test() -> void:
	_airframe = Airframe.new()
	_fittings = [
		TestLoadouts.bomb_rack(),
		TestLoadouts.ammunition_box(),
		TestLoadouts.fuel_tank(),
		TestLoadouts.armour_plate()
	]


func test_starts_from_the_current_loadout_matching_fittings_by_name() -> void:
	# The preset's Fittings are other instances with the same names.
	var refit := Refit.create(_airframe, _fittings, TestLoadouts.fighter())
	assert_array(refit.counts).contains_exactly([2, 1, 2, 0])
	assert_int(refit.slots_free()).is_equal(1)


func test_adds_while_a_slot_is_free_and_removes_down_to_none() -> void:
	var refit := Refit.create(_airframe, _fittings, TestLoadouts.fighter())
	assert_bool(refit.add(3)).is_true()
	assert_int(refit.slots_free()).is_equal(0)
	assert_bool(refit.add(0)).is_false()
	assert_bool(refit.remove(1)).is_true()
	assert_bool(refit.remove(1)).is_false()
	assert_array(refit.counts).contains_exactly([2, 0, 2, 1])


func test_the_loadout_repeats_each_fitting_its_count_of_times() -> void:
	var refit := Refit.create(_airframe, _fittings, Loadout.new())
	refit.add(0)
	refit.add(0)
	refit.add(2)
	var loadout := refit.loadout()
	assert_int(loadout.slots_used()).is_equal(3)
	assert_int(loadout.count_of(_fittings[0])).is_equal(2)
	assert_int(loadout.bombs()).is_equal(4)
	var plane := refit.preview()
	assert_float(plane.fuel).is_equal(_airframe.base_fuel_seconds + 20.0)


func test_a_loadout_too_big_for_the_slots_is_trimmed_from_the_end() -> void:
	var seven: Array[Fitting] = []
	for i in 4:
		seven.append(TestLoadouts.bomb_rack())
	for i in 3:
		seven.append(TestLoadouts.armour_plate())
	var refit := Refit.create(_airframe, _fittings, Loadout.of(seven))
	assert_int(refit.slots_used()).is_equal(_airframe.slots)
	assert_array(refit.counts).contains_exactly([4, 0, 0, 2])
