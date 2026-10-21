extends GdUnitTestSuite
## The wingtip ribbon's rule: when it shows, how it fades in, how its points age away.

const DT := 1.0 / 60.0
const TOP := 72.0


func test_it_wants_to_show_under_load_or_at_speed_and_not_in_cruise() -> void:
	assert_float(Ribbon.wanted(1.0, 40.0, TOP)).is_equal(0.0)
	assert_float(Ribbon.wanted(Ribbon.G_FULL, 40.0, TOP)).is_equal(1.0)
	assert_float(Ribbon.wanted(-Ribbon.G_FULL, 40.0, TOP)).is_equal(1.0)  # pushing over too
	assert_float(Ribbon.wanted((Ribbon.G_FROM + Ribbon.G_FULL) / 2.0, 40.0, TOP)).is_equal_approx(
		0.5, 0.001
	)
	assert_float(Ribbon.wanted(1.0, TOP * Ribbon.SPEED_FULL, TOP)).is_equal(1.0)
	assert_float(Ribbon.wanted(1.0, TOP * Ribbon.SPEED_FROM, TOP)).is_equal(0.0)


func test_it_fades_in_over_a_fifth_of_a_second_and_its_points_age_away() -> void:
	var ribbon := Ribbon.new()
	ribbon.update(Vector3.ZERO, Ribbon.G_FULL, 40.0, TOP, DT)
	assert_float(ribbon.strength).is_equal_approx(Ribbon.FADE_IN_RATE * DT, 0.001)
	assert_float(ribbon.alpha_at(0)).is_equal_approx(Ribbon.FADE_IN_RATE * DT, 0.001)
	for i in 12:
		ribbon.update(Vector3(float(i), 0.0, 0.0), Ribbon.G_FULL, 40.0, TOP, DT)
	assert_float(ribbon.strength).is_equal(1.0)
	assert_int(ribbon.points.size()).is_equal(13)
	assert_float(ribbon.alpha_at(12)).is_equal(1.0)
	assert_float(ribbon.alpha_at(0)).is_less(1.0)  # the first point has aged
	for i in int(Ribbon.LIFE / DT) + 2:
		ribbon.update(Vector3.ZERO, 1.0, 40.0, TOP, DT)
	assert_int(ribbon.points.size()).is_less_equal(int(Ribbon.LIFE / DT) + 1)
	assert_float(ribbon.strength).is_equal(0.0)
	ribbon.clear()
	assert_int(ribbon.points.size()).is_equal(0)


func test_it_fades_out_slower_than_in_so_a_reversal_does_not_blank_it() -> void:
	var ribbon := Ribbon.new()
	for i in 12:
		ribbon.update(Vector3.ZERO, Ribbon.G_FULL, 40.0, TOP, DT)
	assert_float(ribbon.strength).is_equal(1.0)
	ribbon.update(Vector3.ZERO, 0.0, 40.0, TOP, DT)
	assert_float(ribbon.strength).is_equal_approx(1.0 - Ribbon.FADE_OUT_RATE * DT, 0.001)
	for i in 5:  # a tenth of a second through zero g
		ribbon.update(Vector3.ZERO, 0.0, 40.0, TOP, DT)
	assert_float(ribbon.strength).is_greater(0.7)


func test_the_strip_does_not_twist_where_the_path_doubles_back() -> void:
	var ribbon := Ribbon.new()
	# Up, then straight back down, then up again: the same spot twice.
	for point in [
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
		Vector3(0.0, 2.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
	]:
		ribbon.update(point, Ribbon.G_FULL, 40.0, TOP, DT)
	var across := Vector3.ZERO
	for i in ribbon.points.size():
		var next := ribbon.across_at(i, across)
		assert_float(next.length()).is_equal_approx(Ribbon.WIDTH / 2.0, 0.001)
		if i > 0:
			assert_float(next.dot(across)).is_greater_equal(0.0)
		across = next
