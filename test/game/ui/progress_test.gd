extends GdUnitTestSuite

const PATH := "user://progress_test.json"


func after_test() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func test_progress_round_trips_through_the_file() -> void:
	var progress := Progress.load_from(PATH)
	assert_bool(progress.is_completed("strike_the_depot")).is_false()
	progress.mark_completed("strike_the_depot")
	progress.mark_completed("strike_the_depot")
	var reloaded := Progress.load_from(PATH)
	assert_bool(reloaded.is_completed("strike_the_depot")).is_true()
	assert_int(reloaded.completed.size()).is_equal(1)


func test_a_missing_or_broken_file_means_nothing_completed() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	var progress := Progress.load_from(PATH)
	assert_int(progress.completed.size()).is_equal(0)
