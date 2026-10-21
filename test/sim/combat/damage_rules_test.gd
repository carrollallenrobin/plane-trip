extends GdUnitTestSuite

var _rules: DamageRules


func before_test() -> void:
	_rules = DamageRules.new(7)


func _plane(hit_points: int) -> PlaneState:
	var s := TestLoadouts.plane()
	s.hit_points = hit_points
	return s


func test_bullet_damage_stays_within_the_original_roll() -> void:
	for i in 200:
		var s := _plane(100)
		_rules.bullet_hit(s)
		assert_int(100 - s.hit_points).is_between(0, DamageRules.BULLET_DAMAGE_MAX)


func test_bullets_put_an_airborne_plane_into_a_spin() -> void:
	var s := _plane(1)
	var outcome := DamageRules.Outcome.NONE
	while outcome == DamageRules.Outcome.NONE:
		outcome = _rules.bullet_hit(s).outcome
	assert_int(outcome).is_equal(DamageRules.Outcome.SPIN)
	assert_bool(s.in_spin).is_true()
	assert_int(s.hit_points).is_equal(0)


func test_bullets_explode_a_plane_on_the_ground() -> void:
	var s := _plane(1)
	s.on_airfield = true
	var outcome := DamageRules.Outcome.NONE
	while outcome == DamageRules.Outcome.NONE:
		outcome = _rules.bullet_hit(s).outcome
	assert_int(outcome).is_equal(DamageRules.Outcome.EXPLODE)
	assert_bool(s.in_spin).is_false()


func test_a_blast_explodes_even_a_spinning_plane() -> void:
	var s := _plane(0)
	s.in_spin = true
	assert_int(_rules.blast(s, 40).outcome).is_equal(DamageRules.Outcome.EXPLODE)
	assert_bool(s.in_spin).is_false()
	var healthy := _plane(25)
	assert_int(_rules.blast(healthy, 10).outcome).is_equal(DamageRules.Outcome.NONE)
	assert_int(healthy.hit_points).is_equal(15)
	assert_int(_rules.blast(healthy, 80).outcome).is_equal(DamageRules.Outcome.EXPLODE)


func test_more_bullets_do_nothing_to_a_spinning_plane() -> void:
	var s := _plane(0)
	s.in_spin = true
	assert_int(_rules.bullet_hit(s).outcome).is_equal(DamageRules.Outcome.NONE)
	assert_int(_rules.debris_hit(s).outcome).is_equal(DamageRules.Outcome.NONE)


func test_a_hit_reports_what_it_took_and_whether_it_was_a_blast() -> void:
	var s := _plane(100)
	var hit := _rules.bullet_hit(s)
	assert_int(hit.amount).is_equal(100 - s.hit_points)
	assert_bool(hit.blast).is_false()
	var blasted := _rules.blast(s, 10)
	assert_int(blasted.amount).is_equal(10)
	assert_bool(blasted.blast).is_true()
	var spinning := _plane(0)
	spinning.in_spin = true
	assert_int(_rules.bullet_hit(spinning).amount).is_equal(0)


func test_a_destroyed_plane_takes_no_damage() -> void:
	var s := _plane(50)
	s.destroyed = true
	assert_int(_rules.bullet_hit(s).outcome).is_equal(DamageRules.Outcome.NONE)
	assert_int(_rules.blast(s, 80).outcome).is_equal(DamageRules.Outcome.NONE)
	assert_int(s.hit_points).is_equal(50)
