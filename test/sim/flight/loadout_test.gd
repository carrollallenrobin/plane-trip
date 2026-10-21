extends GdUnitTestSuite
## Loadouts, Fittings and the airframe (docs/design.md, Planes and Loadouts): capacities are
## the base plus what the Fittings add, bombs hang only on racks, and weight is the empty
## plane, the Fittings and the bombs still hanging.

var _airframe: Airframe


func before_test() -> void:
	_airframe = Airframe.new()


func test_an_empty_loadout_is_the_bare_plane() -> void:
	var s := PlaneState.create(_airframe, Loadout.new())
	assert_int(s.max_bombs()).is_equal(0)
	assert_int(s.max_rounds()).is_equal(_airframe.base_rounds)
	assert_float(s.max_fuel()).is_equal(_airframe.base_fuel_seconds)
	assert_int(s.max_hit_points()).is_equal(_airframe.base_hit_points)
	assert_float(s.mass()).is_equal(_airframe.empty_mass)


func test_each_fitting_raises_its_capacity_over_the_base() -> void:
	var loadout := Loadout.of(
		[
			TestLoadouts.bomb_rack(),
			TestLoadouts.ammunition_box(),
			TestLoadouts.fuel_tank(),
			TestLoadouts.armour_plate()
		]
	)
	assert_int(loadout.bombs()).is_equal(2)
	assert_int(loadout.rounds(_airframe)).is_equal(_airframe.base_rounds + 50)
	assert_float(loadout.fuel_seconds(_airframe)).is_equal(_airframe.base_fuel_seconds + 20.0)
	assert_int(loadout.hit_points(_airframe)).is_equal(_airframe.base_hit_points + 8)
	assert_float(loadout.fixed_mass()).is_equal(6.0 + 12.0 + 40.0)


func test_a_fresh_plane_is_full_to_its_loadout() -> void:
	var s := TestLoadouts.plane()
	assert_int(s.bombs).is_equal(4)
	assert_int(s.rounds).is_equal(90)
	assert_float(s.fuel).is_equal(70.0)
	assert_int(s.hit_points).is_equal(25)


func test_the_same_fitting_counts_once_per_slot_and_the_slots_are_limited() -> void:
	var rack := TestLoadouts.bomb_rack()
	var loadout := Loadout.of([rack, rack, TestLoadouts.fuel_tank()])
	assert_int(loadout.count_of(rack)).is_equal(2)
	assert_int(loadout.slots_used()).is_equal(3)
	assert_bool(loadout.fits(_airframe)).is_true()
	var seven: Array[Fitting] = []
	for i in _airframe.slots + 1:
		seven.append(rack)
	assert_bool(Loadout.of(seven).fits(_airframe)).is_false()


func test_only_the_hanging_bombs_lighten_the_plane() -> void:
	var s := TestLoadouts.plane()
	var full := s.mass()
	assert_float(full).is_equal(
		_airframe.empty_mass + s.loadout.fixed_mass() + 4 * _airframe.bomb_mass
	)
	s.bombs = 2
	assert_float(s.mass()).is_equal(full - 2 * _airframe.bomb_mass)
	s.fuel = 0.0
	s.rounds = 0
	s.hit_points = 1
	assert_float(s.mass()).is_equal(full - 2 * _airframe.bomb_mass)
