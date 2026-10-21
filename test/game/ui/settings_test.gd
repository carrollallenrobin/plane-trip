extends GdUnitTestSuite

const PATH := "user://settings_test.cfg"


func after_test() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func test_the_sound_switch_round_trips_through_the_file() -> void:
	var settings := Settings.load_from(PATH)
	assert_bool(settings.muted).is_false()
	settings.toggle_muted()
	assert_bool(Settings.load_from(PATH).muted).is_true()
	settings.toggle_muted()
	assert_bool(Settings.load_from(PATH).muted).is_false()


func test_a_missing_or_broken_file_means_sound_on() -> void:
	assert_bool(Settings.load_from(PATH).muted).is_false()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("not a config")
	file.close()
	assert_bool(Settings.load_from(PATH).muted).is_false()
