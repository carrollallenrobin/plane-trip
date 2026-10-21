extends GdUnitTestSuite
## A dial's needle eases to its value and never overshoots.

const DT := 1.0 / 60.0


func test_starts_where_it_is_put_and_clamps() -> void:
	assert_float(Needle.at(0.4).shown).is_equal(0.4)
	assert_float(Needle.at(1.7).shown).is_equal(1.0)
	assert_float(Needle.at(-0.2).shown).is_equal(0.0)


func test_moves_toward_the_value_without_passing_it() -> void:
	var needle := Needle.at(1.0)
	var last := 1.0
	for i in 30:
		var now := needle.update(0.25, DT)
		assert_float(now).is_less(last)
		assert_float(now).is_greater_equal(0.25)
		last = now
	# Half a second in, most of the way there; a second and a half, on the mark.
	assert_float(last).is_less(0.3)
	for i in 60:
		needle.update(0.25, DT)
	assert_float(needle.shown).is_equal(0.25)


func test_a_rise_is_eased_too() -> void:
	var needle := Needle.at(0.0)
	needle.update(1.0, DT)
	assert_float(needle.shown).is_between(0.05, 0.2)
