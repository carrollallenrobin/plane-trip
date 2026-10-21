class_name Game
extends Node
## The screen flow: title, mission list, mission with the Refit over it at the start, debrief,
## with a pause menu inside a mission. Owns the progress and settings files, the UI sounds,
## the music, the sound switch, the fade between screens and the airfield scene behind the
## title. Boot loads this scene and adds it to the tree.

## Everything is readied and the title is up.
signal loaded

enum Screen { LOADING, TITLE, MISSION_LIST, REFIT, MISSION, DEBRIEF }

## Seconds between the mission ending and the debrief: the outcome's time on the Band.
const DEBRIEF_DELAY := InstrumentPanel.OUTCOME_SECONDS

@export var missions: Array[MissionEntry] = []
## The Fittings the Refit screen offers, in its order.
@export var fittings: Array[Fitting] = []

var screen := Screen.LOADING
## True once the loading Sheet has gone and the title is up.
var is_loaded := false
var progress: Progress
var settings: Settings
var chosen_mission: MissionEntry
var world: WorldNode
var paused := false
## The last Loadout confirmed this session: the next Refit starts from it.
var last_loadout: Loadout

var _layer: CanvasLayer
var _menu: MenuScreen
var _pause_menu: MenuScreen
## The Refit screen while it is up, beside the menus so a pause can stack on it.
var _refit: RefitScreen
var _airfield: AirfieldScene
## The one plane picture, made at loading, lent to the loading Sheet and every Refit, and
## parked out of sight between them.
var _plane_picture: PlaneViewport
var _parked: Control
var _sounds: UiSounds
var _music: Music
var _fade: ScreenFade
var _debrief_timer := 0.0
var _last_outcome := MissionRules.Outcome.ONGOING


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	progress = Progress.load_from()
	settings = Settings.load_from()
	_apply_sound()
	_sounds = UiSounds.new()
	_sounds.name = "UiSounds"
	add_child(_sounds)
	_music = Music.new()
	_music.name = "Music"
	add_child(_music)
	_layer = CanvasLayer.new()
	_layer.name = "Menus"
	_layer.layer = 10
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_parked = Control.new()
	_parked.name = "Parked"
	_parked.visible = false
	_layer.add_child(_parked)
	_fade = ScreenFade.new()
	_fade.name = "Fade"
	add_child(_fade)
	_load()


func _process(dt: float) -> void:
	if _in_mission() and _last_outcome != MissionRules.Outcome.ONGOING and not paused:
		_debrief_timer -= dt
		if _debrief_timer <= 0.0:
			show_debrief()


func _unhandled_input(event: InputEvent) -> void:
	if _in_mission() and event.is_action_pressed(&"pause"):
		set_paused(not paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"mute"):
		toggle_sound()
		get_viewport().set_input_as_handled()


# --- Sound ---


## The sound switch: everything on the Master bus goes quiet, or comes back, and the choice
## is remembered. The switch's button on whichever Sheet is up says where it stands.
func toggle_sound() -> void:
	settings.toggle_muted()
	_apply_sound()
	for menu in [_menu, _pause_menu]:
		if menu != null:
			menu.relabel("mute", _sound_label())


func _apply_sound() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), settings.muted)


func _sound_label() -> String:
	return "Sound: off" if settings.muted else "Sound: on"


# --- Screens ---


## The loading Sheet: build the airfield behind the title and compile every shader a mission
## uses, a stage per frame so the Sheet can say where it is, then the title. The engine's
## own loader is gone the moment this Sheet draws.
func _load() -> void:
	var carried: Array[Fitting] = []
	if not fittings.is_empty():
		carried.append(fittings[0])  # a Bomb Rack, so the Bomb hangs in the picture too
	_plane_picture = PlaneViewport.create(Side.BLUE)
	_plane_picture.name = "PlanePicture"
	_plane_picture.show_loadout(Loadout.of(carried))
	var loading := LoadingScreen.create(_sounds)
	_layer.add_child(loading)
	# The wireless from here on: a browser keeps it silent until the first key or click,
	# and lets it through from then.
	_music.play_wireless()
	loading.set_stage("Paper and type", 0.1)
	await get_tree().process_frame
	loading.add_plane(_plane_picture)
	loading.set_stage("The plane", 0.2)
	await get_tree().process_frame
	_show_airfield()
	loading.set_stage("The airfield", 0.35)
	await get_tree().process_frame
	_airfield.start_priming()
	loading.set_stage("Guns, bombs and smoke", 0.6)
	for i in ShaderWarmup.FRAMES + 1:
		await get_tree().process_frame
	_airfield.end_priming()
	loading.set_stage("The wireless", 0.9)
	await get_tree().process_frame
	_plane_picture.move_to(_parked)
	loading.queue_free()
	is_loaded = true
	show_title()
	loaded.emit()


func show_title() -> void:
	_leave_mission()
	_show_airfield()
	_music.play_wireless()
	screen = Screen.TITLE
	var menu := _new_menu(22, 1.5, false).wordmark("PLANE TRIP")
	menu.button("start", "Start")
	menu.button("mute", _sound_label())
	if not OS.has_feature("web"):
		menu.button("quit", "Quit")
	menu.chosen.connect(
		func(id: String) -> void:
			if id == "start":
				show_mission_list()
			elif id == "mute":
				toggle_sound()
			elif id == "quit":
				get_tree().quit()
	)
	menu.focus()
	_fade.cover()


func show_mission_list() -> void:
	_leave_mission()
	_show_airfield()
	_music.play_wireless()
	screen = Screen.MISSION_LIST
	var menu := _new_menu(28, -1.0, false).heading("MISSIONS")
	for entry in missions:
		menu.card(
			entry.id, entry.mission.title, _mission_note(entry), progress.is_completed(entry.id)
		)
	menu.gap(4.0)
	menu.button("back", "Back", true)
	menu.chosen.connect(
		func(id: String) -> void:
			if id == "back":
				show_title()
			else:
				for entry in missions:
					if entry.id == id:
						start_mission(entry)
	)
	menu.focus()
	_fade.cover()


## Start the mission with the Refit over it. The World waits under that first Refit and runs
## from the confirm on.
func start_mission(entry: MissionEntry) -> void:
	_leave_mission()
	_hide_airfield()
	_music.stop_wireless()
	screen = Screen.MISSION
	chosen_mission = entry
	_last_outcome = MissionRules.Outcome.ONGOING
	_clear_menu()
	world = entry.scene.instantiate()
	# The Game runs while paused so the menus work; the World must not.
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.mission_ended.connect(_on_mission_ended)
	world.refit_due.connect(_on_refit_due)
	add_child(world)
	world.get_node("Camera").make_current()  # the airfield's camera has stood down
	show_refit(true)
	_fade.cover()


## The Refit screen over the World, starting from the last Loadout confirmed this session
## or, failing that, what the mission gave the player. At the start it carries the briefing
## and offers Back, and the World stands still under it; later there is only Fly, and the
## World runs on behind the sheet.
func show_refit(at_start: bool) -> void:
	_close_refit()
	screen = Screen.REFIT
	world.set_running(not at_start)
	var sim := world.world
	var current := last_loadout if last_loadout != null else sim.player_loadout
	var choice := Refit.create(sim.airframe, fittings, current)
	var mission := chosen_mission.mission
	_plane_picture.set_side(sim.player_side)
	_refit = RefitScreen.create(
		choice,
		sim.player.model,
		mission.title,
		mission.briefing if at_start else "",
		at_start,
		_plane_picture,
		_sounds
	)
	_refit.name = "Refit"
	_refit.confirmed.connect(_on_refit_confirmed)
	_refit.cancelled.connect(show_mission_list)
	_layer.add_child(_refit)
	world.set_player_input_enabled(false)
	world.set_instruments_visible(false)
	_refit.focus()


## A spawn or a stop at home after a sortie. A screen already up stays as it is, with the
## player's half-made choice; a decided mission gets no more Refits.
func _on_refit_due() -> void:
	if _refit != null or _last_outcome != MissionRules.Outcome.ONGOING:
		return
	show_refit(false)


func _on_refit_confirmed(loadout: Loadout) -> void:
	last_loadout = loadout
	world.world.refit(loadout)
	world.set_running(true)
	_close_refit()
	screen = Screen.MISSION


func show_debrief() -> void:
	_close_refit()
	screen = Screen.DEBRIEF
	world.set_instruments_visible(false)
	_sounds.duck_world(true)
	var sim := world.world
	var menu := _new_menu(30, 1.0).small("DEBRIEF").heading(chosen_mission.mission.title)
	var won := _last_outcome == MissionRules.Outcome.WON
	var mark := menu.stamp(MissionText.outcome_text(_last_outcome), true)
	mark.landed.connect(func() -> void: _music.sting(won))
	menu.gap(4.0)
	menu.line(MissionText.objective_text(sim.objective_statuses()))
	menu.line(
		(
			"Kills %d   Planes lost %d   Time %s"
			% [sim.kills, sim.player_losses, MissionText.time_text(sim.time)]
		)
	)
	menu.gap(6.0)
	menu.button("retry", "Fly again")
	menu.button("list", "Mission list", true)
	menu.chosen.connect(
		func(id: String) -> void:
			if id == "retry":
				start_mission(chosen_mission)
			else:
				show_mission_list()
	)
	menu.focus()


func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	if _refit != null:
		_refit.visible = not value
	if value:
		_sounds.duck_world(true)
		_pause_menu = _new_menu(26, -1.4).heading("PAUSED")
		_pause_menu.button("resume", "Resume", true)
		_pause_menu.button("restart", "Restart mission")
		_pause_menu.button("mute", _sound_label())
		_pause_menu.button("list", "Quit to mission list")
		_pause_menu.chosen.connect(
			func(id: String) -> void:
				if id == "mute":
					toggle_sound()
					return
				set_paused(false)
				if id == "restart":
					start_mission(chosen_mission)
				elif id == "list":
					show_mission_list()
		)
		_pause_menu.focus()
	else:
		if screen != Screen.DEBRIEF:
			_sounds.duck_world(false)
		_clear_menu()
		if _refit != null:
			_refit.focus()


func _on_mission_ended(outcome: MissionRules.Outcome) -> void:
	_last_outcome = outcome
	_debrief_timer = DEBRIEF_DELAY
	if outcome == MissionRules.Outcome.WON:
		progress.mark_completed(chosen_mission.id)


func _in_mission() -> bool:
	return screen == Screen.MISSION or screen == Screen.REFIT


## What a mission's card says under its title.
static func _mission_note(entry: MissionEntry) -> String:
	var mission := entry.mission
	var required := 0
	for objective in mission.objectives:
		if objective.required:
			required += 1
	return (
		"%d objectives, %d required   %d planes"
		% [mission.objectives.size(), required, mission.player_planes]
	)


func _leave_mission() -> void:
	if paused:
		set_paused(false)
	_close_refit()
	_sounds.duck_world(false)
	if world != null:
		world.queue_free()
		world = null


## The airfield scene is made once and kept: it sleeps behind a mission and wakes for the
## menus. Freeing it freed every shader its materials were the last to use, and the next
## mission compiled them all again (see AirfieldScene).
func _show_airfield() -> void:
	if _airfield == null:
		_airfield = AirfieldScene.new()
		_airfield.name = "Airfield"
		add_child(_airfield)
	else:
		_airfield.wake()


func _hide_airfield() -> void:
	if _airfield != null:
		_airfield.sleep()


func _new_menu(padding := 28, tilt := 1.2, dim := true) -> MenuScreen:
	_clear_menu()
	_menu = MenuScreen.new(_sounds, padding, tilt, dim)
	_menu.name = "Menu"
	_layer.add_child(_menu)
	return _menu


func _clear_menu() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null


func _close_refit() -> void:
	if _refit == null:
		return
	_plane_picture.move_to(_parked)
	_refit.queue_free()
	_refit = null
	if world != null and world.world != null:
		world.set_player_input_enabled(true)
		world.set_instruments_visible(true)
