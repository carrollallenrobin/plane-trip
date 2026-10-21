extends GdUnitTestSuite
## Objectives turning complete or failed give one Band message each, and nothing once the
## Mission has ended.


func _statuses(first: MissionRules.Status, second: MissionRules.Status) -> Array[ObjectiveStatus]:
	return [
		ObjectiveStatus.create(Objective.create(Objective.Kind.DESTROY, "Depot"), first),
		ObjectiveStatus.create(Objective.create(Objective.Kind.PROTECT, "FuelStore"), second),
	]


func test_the_first_look_sets_the_baseline_and_says_nothing() -> void:
	var watch := ObjectiveWatch.new()
	var open := MissionRules.Status.OPEN
	assert_array(watch.messages(_statuses(open, open), MissionRules.Outcome.ONGOING)).is_empty()


func test_a_turn_is_reported_once() -> void:
	var watch := ObjectiveWatch.new()
	var open := MissionRules.Status.OPEN
	watch.messages(_statuses(open, open), MissionRules.Outcome.ONGOING)
	var turned := _statuses(MissionRules.Status.COMPLETE, open)
	assert_array(watch.messages(turned, MissionRules.Outcome.ONGOING)).contains_exactly(
		["Destroy Depot complete"]
	)
	assert_array(watch.messages(turned, MissionRules.Outcome.ONGOING)).is_empty()


func test_a_failure_is_reported_and_the_outcome_silences_the_watch() -> void:
	var watch := ObjectiveWatch.new()
	var open := MissionRules.Status.OPEN
	watch.messages(_statuses(open, open), MissionRules.Outcome.ONGOING)
	var failed := _statuses(open, MissionRules.Status.FAILED)
	assert_array(watch.messages(failed, MissionRules.Outcome.LOST)).is_empty()
	watch.messages(_statuses(open, open), MissionRules.Outcome.ONGOING)
	assert_array(watch.messages(failed, MissionRules.Outcome.ONGOING)).contains_exactly(
		["Protect FuelStore failed"]
	)
