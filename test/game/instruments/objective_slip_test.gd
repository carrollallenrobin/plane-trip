extends GdUnitTestSuite
## The objective slip wraps words that do not fit its width and grows a line for each.


func _status(title: String) -> ObjectiveStatus:
	var objective := Objective.create(Objective.Kind.DESTROY, "Depot")
	objective.title = title
	return ObjectiveStatus.create(objective, MissionRules.Status.OPEN)


func test_a_short_objective_takes_one_line_and_a_long_one_wraps() -> void:
	var slip: ObjectiveSlip = auto_free(ObjectiveSlip.new())
	slip.show_statuses([_status("Destroy the depot")])
	assert_int(slip.line_count()).is_equal(1)
	assert_float(slip.size.y).is_equal(ObjectiveSlip.PADDING.y * 2.0 + ObjectiveSlip.LINE_HEIGHT)
	slip.show_statuses([_status("Shoot down three of their planes before the bombers come")])
	assert_int(slip.line_count()).is_greater_equal(2)
	assert_float(slip.size.y).is_equal(
		ObjectiveSlip.PADDING.y * 2.0 + ObjectiveSlip.LINE_HEIGHT * slip.line_count()
	)


func test_the_same_words_again_are_not_reshaped() -> void:
	var slip: ObjectiveSlip = auto_free(ObjectiveSlip.new())
	slip.show_statuses([_status("Destroy the depot")])
	var shaped: TextParagraph = slip._paragraphs[0]
	slip.show_statuses([_status("Destroy the depot")])
	assert_object(slip._paragraphs[0]).is_same(shaped)
	slip.show_statuses([_status("Destroy the hangar")])
	assert_object(slip._paragraphs[0]).is_not_same(shaped)
