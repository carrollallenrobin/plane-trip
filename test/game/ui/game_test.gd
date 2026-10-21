extends GdUnitTestSuite
## The screen flow, driven headlessly through the Game's methods.

const DT := 1.0 / 60.0


func _game() -> Game:
	var runner := scene_runner("res://src/game/ui/game.tscn")
	var game: Game = runner.scene()
	game.progress = Progress.load_from("user://game_test_progress.json")
	game.progress.completed.clear()
	if not game.is_loaded:
		await game.loaded
	return game


func test_the_boot_page_loads_the_game_on_a_thread_and_hands_over() -> void:
	var runner := scene_runner("res://main.tscn")
	var boot: Boot = runner.scene()
	assert_object(boot.game).is_null()
	var game: Game = await boot.started
	assert_object(game).is_not_null()
	assert_float(boot.progress).is_equal(1.0)
	assert_int(game.screen).is_equal(Game.Screen.LOADING)
	await game.loaded
	assert_int(game.screen).is_equal(Game.Screen.TITLE)
	game.queue_free()


func test_the_game_readies_everything_under_a_loading_sheet_then_shows_the_title() -> void:
	var runner := scene_runner("res://src/game/ui/game.tscn")
	var game: Game = runner.scene()
	assert_int(game.screen).is_equal(Game.Screen.LOADING)
	assert_object(game.get_node("Menus/Loading")).is_not_null()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var airfield: AirfieldScene = game.get_node("Airfield")
	assert_bool(airfield.is_priming()).is_true()
	assert_object(airfield.get_node("Effects")).is_not_null()
	assert_object(airfield.get_node("Projectiles")).is_not_null()
	await game.loaded
	assert_bool(game.is_loaded).is_true()
	assert_int(game.screen).is_equal(Game.Screen.TITLE)
	assert_bool(airfield.is_priming()).is_false()
	assert_bool(airfield.get_node("Effects").visible).is_false()  # kept, hidden
	await get_tree().process_frame  # the loading Sheet was queued to go
	assert_object(game.get_node_or_null("Menus/Loading")).is_null()


func after_test() -> void:
	for file in ["user://game_test_progress.json", "user://game_test_settings.cfg"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)


func test_the_sound_switch_mutes_everything_stays_on_the_sheet_and_is_remembered() -> void:
	var game: Game = await _game()
	game.settings = Settings.load_from("user://game_test_settings.cfg")
	var master := AudioServer.get_bus_index("Master")
	assert_str(game._menu.button_text("mute")).is_equal("Sound: on")
	game._menu.chosen.emit("mute")
	assert_bool(AudioServer.is_bus_mute(master)).is_true()
	assert_int(game.screen).is_equal(Game.Screen.TITLE)
	assert_str(game._menu.button_text("mute")).is_equal("Sound: off")
	assert_bool(Settings.load_from("user://game_test_settings.cfg").muted).is_true()
	# On the pause slip too, without resuming.
	game.start_mission(_entry(game, "hold_the_line"))
	await get_tree().process_frame
	game.set_paused(true)
	assert_str(game._pause_menu.button_text("mute")).is_equal("Sound: off")
	game._pause_menu.chosen.emit("mute")
	assert_bool(AudioServer.is_bus_mute(master)).is_false()
	assert_bool(game.paused).is_true()
	assert_str(game._pause_menu.button_text("mute")).is_equal("Sound: on")
	game.set_paused(false)
	game.show_title()


func _entry(game: Game, id: String) -> MissionEntry:
	for entry in game.missions:
		if entry.id == id:
			return entry
	return null


func test_the_game_starts_at_the_title_and_lists_the_missions() -> void:
	var game: Game = await _game()
	assert_int(game.screen).is_equal(Game.Screen.TITLE)
	assert_int(game.missions.size()).is_equal(4)
	assert_str(game.missions[0].id).is_equal("clear_the_sky")
	assert_str(game.missions[3].id).is_equal("the_big_show")
	assert_object(game.get_node("Airfield")).is_not_null()
	game.show_mission_list()
	assert_int(game.screen).is_equal(Game.Screen.MISSION_LIST)
	assert_object(game.get_node("Airfield")).is_same(game._airfield)


func test_the_wireless_plays_behind_the_title_and_the_list_and_stops_for_a_mission() -> void:
	var game: Game = await _game()
	var music: Music = game.get_node("Music")
	assert_bool(music.wireless_playing()).is_true()
	assert_str(music.get_node("Wireless").bus).is_equal(Music.BUS)
	assert_int(music.get_node("Wireless").stream.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	game.show_mission_list()
	assert_bool(music.wireless_playing()).is_true()
	game.start_mission(_entry(game, "strike_the_depot"))
	await get_tree().process_frame
	await get_tree().create_timer(Music.FADE_OUT_SECONDS + 0.2).timeout
	assert_bool(music.wireless_playing()).is_false()
	game.show_title()
	assert_bool(music.wireless_playing()).is_true()


func test_escape_is_back_where_a_screen_has_a_back() -> void:
	var game: Game = await _game()
	game.show_mission_list()
	assert_str(game._menu.back_id).is_equal("back")
	game._menu.chosen.emit("back")
	assert_int(game.screen).is_equal(Game.Screen.TITLE)
	assert_str(game._menu.back_id).is_equal("")
	game.start_mission(_entry(game, "strike_the_depot"))
	await get_tree().process_frame
	assert_str(game._refit.back_id).is_equal("back")
	# The airfield scene sleeps behind the mission rather than going: its materials keep
	# the shaders alive.
	var airfield: AirfieldScene = game.get_node("Airfield")
	assert_bool(airfield.visible).is_false()
	assert_int(airfield.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
	assert_bool(airfield.get_node("Camera").current).is_false()
	assert_bool(game.world.get_node("Camera").current).is_true()
	game.show_mission_list()
	assert_bool(airfield.visible).is_true()
	assert_bool(airfield.get_node("Camera").current).is_true()
	game.start_mission(_entry(game, "strike_the_depot"))
	await get_tree().process_frame
	game._refit.confirmed.emit(game._refit.refit.loadout())
	game.world.refit_due.emit()
	assert_str(game._refit.back_id).is_equal("")


func test_a_mission_starts_under_the_refit_and_flying_confirms_the_loadout() -> void:
	var game: Game = await _game()
	assert_int(game.fittings.size()).is_equal(4)
	game.start_mission(_entry(game, "strike_the_depot"))
	await get_tree().process_frame
	assert_int(game.screen).is_equal(Game.Screen.REFIT)
	assert_object(game.world).is_not_null()
	assert_str(game.world.mission.title).is_equal("Strike the Depot")
	var sim := game.world.world
	assert_bool(sim.player.pilot.enabled).is_false()
	assert_array(game._refit.refit.counts).contains_exactly([2, 1, 2, 0])
	# The one plane picture is on the form, and parked again once it closes.
	var picture: PlaneViewport = game._plane_picture
	assert_bool(game._refit.is_ancestor_of(picture)).is_true()
	# One Armour Plate into the free Slot, then fly.
	game._refit.adjust(3, 1)
	game._refit.confirmed.emit(game._refit.refit.loadout())
	assert_int(game.screen).is_equal(Game.Screen.MISSION)
	assert_object(picture.get_parent()).is_same(game.get_node("Menus/Parked"))
	assert_bool(sim.player.pilot.enabled).is_true()
	assert_int(sim.player.state.max_hit_points()).is_equal(33)
	assert_int(sim.player.state.hit_points).is_equal(33)
	assert_int(game.last_loadout.slots_used()).is_equal(6)


func test_a_refit_due_from_the_world_opens_the_screen_without_back_and_once() -> void:
	var game: Game = await _game()
	game.start_mission(_entry(game, "strike_the_depot"))
	await get_tree().process_frame
	game._refit.confirmed.emit(game._refit.refit.loadout())
	assert_int(game.screen).is_equal(Game.Screen.MISSION)
	game.world.refit_due.emit()
	assert_int(game.screen).is_equal(Game.Screen.REFIT)
	var first := game._refit
	assert_bool(game.world.world.player.pilot.enabled).is_false()
	game._refit.adjust(0, -1)
	game.world.refit_due.emit()
	assert_object(game._refit).is_same(first)
	assert_array(game._refit.refit.counts).contains_exactly([1, 1, 2, 0])
	game._refit.confirmed.emit(game._refit.refit.loadout())
	assert_int(game.world.world.player.state.max_bombs()).is_equal(2)
	assert_int(game.screen).is_equal(Game.Screen.MISSION)


func test_the_next_refit_starts_from_the_last_loadout_and_back_leaves_the_mission() -> void:
	var game: Game = await _game()
	game.last_loadout = Loadout.of([TestLoadouts.armour_plate()])
	game.start_mission(_entry(game, "hold_the_line"))
	await get_tree().process_frame
	assert_array(game._refit.refit.counts).contains_exactly([0, 0, 0, 1])
	game._refit.cancelled.emit()
	assert_int(game.screen).is_equal(Game.Screen.MISSION_LIST)
	assert_object(game.world).is_null()


func test_the_world_stands_still_under_the_first_refit_and_runs_from_the_confirm() -> void:
	var game: Game = await _game()
	game.start_mission(_entry(game, "strike_the_depot"))
	await get_tree().process_frame
	assert_bool(game.world.is_physics_processing()).is_false()
	game._refit.confirmed.emit(game._refit.refit.loadout())
	assert_bool(game.world.is_physics_processing()).is_true()
	# A later Refit, at a stop at home, leaves the World running.
	game.world.refit_due.emit()
	assert_int(game.screen).is_equal(Game.Screen.REFIT)
	assert_bool(game.world.is_physics_processing()).is_true()


func test_winning_marks_the_mission_done_and_leads_to_the_debrief() -> void:
	var game: Game = await _game()
	game.start_mission(_entry(game, "strike_the_depot"))
	await get_tree().process_frame
	game._refit.confirmed.emit(game._refit.refit.loadout())
	game.world.world.target_named("Depot").damage(GroundTarget.BOMB_DAMAGE)
	game.world.step(DT)
	assert_bool(game.progress.is_completed("strike_the_depot")).is_true()
	game._process(Game.DEBRIEF_DELAY + 0.1)
	assert_int(game.screen).is_equal(Game.Screen.DEBRIEF)
	assert_bool(game.world.get_node("InstrumentPanel").visible).is_false()
	assert_str(game._menu.sheet.get_node("Column").get_child(2).get_child(0).text).is_equal(
		"MISSION COMPLETE"
	)
	game.show_mission_list()
	assert_object(game.world).is_null()


func test_pausing_stops_the_tree_and_stacks_on_the_refit() -> void:
	var game: Game = await _game()
	game.start_mission(_entry(game, "hold_the_line"))
	await get_tree().process_frame
	game.set_paused(true)
	assert_bool(get_tree().paused).is_true()
	# The Game itself runs on while paused, for the menus; the World must stop.
	assert_bool(game.can_process()).is_true()
	assert_bool(game.world.can_process()).is_false()
	assert_bool(game._refit.visible).is_false()
	game.set_paused(false)
	assert_bool(get_tree().paused).is_false()
	assert_bool(game._refit.visible).is_true()
	assert_int(game.screen).is_equal(Game.Screen.REFIT)
	game.show_title()
	assert_object(game._refit).is_null()
