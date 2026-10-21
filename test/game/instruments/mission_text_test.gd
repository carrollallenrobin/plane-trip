extends GdUnitTestSuite
## The words on the Instrument Panel and the Debrief. Static, so no scene is needed.


func _entry(
	kind: Objective.Kind, name: String, status: MissionRules.Status, required := true
) -> ObjectiveStatus:
	return ObjectiveStatus.create(Objective.create(kind, name, required), status)


func test_objective_text_ticks_completes_marks_failures_and_notes_optionals() -> void:
	var statuses: Array[ObjectiveStatus] = [
		_entry(Objective.Kind.DESTROY, "Depot", MissionRules.Status.COMPLETE),
		_entry(Objective.Kind.PROTECT, "FuelStore", MissionRules.Status.FAILED),
		_entry(Objective.Kind.RETURN, "", MissionRules.Status.OPEN, false),
	]
	assert_str(MissionText.objective_text(statuses)).is_equal(
		"[x] Destroy Depot\n[!] Protect FuelStore\n[ ] Return home (optional)"
	)


func test_a_shoot_down_still_open_says_how_many_are_down() -> void:
	var objective := Objective.shoot_down(3)
	var fresh := ObjectiveStatus.create(objective, MissionRules.Status.OPEN, 0)
	var part := ObjectiveStatus.create(objective, MissionRules.Status.OPEN, 2)
	var done := ObjectiveStatus.create(objective, MissionRules.Status.COMPLETE, 3)
	assert_str(MissionText.objective_line(fresh)).is_equal("Shoot down 3 planes")
	assert_str(MissionText.objective_line(part)).is_equal("Shoot down 3 planes (2 down)")
	assert_str(MissionText.objective_line(done)).is_equal("Shoot down 3 planes")
	assert_str(MissionText.change_text(done)).is_equal("Shoot down 3 planes complete")


func test_outcome_text() -> void:
	assert_str(MissionText.outcome_text(MissionRules.Outcome.WON)).is_equal("MISSION COMPLETE")
	assert_str(MissionText.outcome_text(MissionRules.Outcome.LOST)).is_equal("MISSION FAILED")


func test_change_text_says_what_became_of_the_objective() -> void:
	var done := _entry(Objective.Kind.DESTROY, "Depot", MissionRules.Status.COMPLETE)
	var lost := _entry(Objective.Kind.PROTECT, "FuelStore", MissionRules.Status.FAILED)
	assert_str(MissionText.change_text(done)).is_equal("Destroy Depot complete")
	assert_str(MissionText.change_text(lost)).is_equal("Protect FuelStore failed")


func test_time_text_is_minutes_and_seconds() -> void:
	assert_str(MissionText.time_text(0.0)).is_equal("0:00")
	assert_str(MissionText.time_text(59.9)).is_equal("0:59")
	assert_str(MissionText.time_text(272.4)).is_equal("4:32")
	assert_str(MissionText.time_text(3600.0)).is_equal("60:00")
