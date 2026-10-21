class_name InstrumentPanel
extends CanvasLayer
## The Instrument Panel: what the player reads in flight. A riveted olive plate at the bottom
## left with dials for fuel, rounds and hull and silhouettes for bombs and planes left, the
## objective slip pinned top left, and the Band mission messages are set on, with the
## typewriter's bell for an objective complete and a dull clank for one failed, on the UI
## bus. Reads the World; never writes it (docs/design.md, Presentation).

const BOMB_ICON := preload("res://art/ui/bomb.svg")
const PLANE_ICON := preload("res://art/ui/plane.svg")
const MARGIN := 14.0
const PLATE_SIZE := Vector2(520.0, 130.0)
const DIAL_STEP := 108.0
const COUNTERS_X := 352.0
## How long the outcome stays on the Band before the Debrief; the Game waits the same.
const OUTCOME_SECONDS := 2.5
const CHANGE_SECONDS := 2.2

var world: World

var _root: Control
var _fuel: Dial
var _rounds: Dial
var _hull: Dial
var _bombs: CounterRow
var _planes: CounterRow
var _slip: ObjectiveSlip
var _band: Band
var _watch := ObjectiveWatch.new()
var _bell: AudioStreamPlayer
var _bell_low: AudioStreamPlayer


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_plate()
	_slip = ObjectiveSlip.new()
	_slip.name = "ObjectiveSlip"
	_slip.position = Vector2(MARGIN + 4.0, MARGIN)
	_root.add_child(_slip)
	_band = Band.new()
	_band.name = "Band"
	_root.add_child(_band)
	_bell = _player("Bell", SoundBank.BELL)
	_bell_low = _player("BellLow", SoundBank.BELL_LOW)


## Put the outcome on the Band for its while, with the bell it earns.
func show_outcome(outcome: MissionRules.Outcome) -> void:
	_band.say(MissionText.outcome_text(outcome), OUTCOME_SECONDS, true)
	_ring(outcome == MissionRules.Outcome.WON)


func _process(_dt: float) -> void:
	if world == null:
		return
	var statuses := world.objective_statuses()
	_slip.show_statuses(statuses)
	for message in _watch.messages(statuses, world.outcome):
		_band.say(message, CHANGE_SECONDS, false)
		_ring(not message.ends_with("failed"))
	_planes.show_count(world.player_planes_left())
	if world.player == null or world.player.state == null:
		return
	var s := world.player.state
	_fuel.set_value(s.fuel / s.max_fuel())
	_rounds.set_value(float(s.rounds) / s.max_rounds())
	_hull.set_value(float(s.hit_points) / s.max_hit_points())
	_bombs.show_count(s.bombs, s.max_bombs())


func _ring(good: bool) -> void:
	if good:
		_bell.play()
	else:
		_bell_low.play()


func _player(player_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.volume_db = -6.0
	player.bus = UiSounds.BUS
	add_child(player)
	return player


func _build_plate() -> void:
	var plate := Plate.new()
	plate.name = "Plate"
	plate.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	plate.offset_left = MARGIN
	plate.offset_right = MARGIN + PLATE_SIZE.x
	plate.offset_top = -MARGIN - PLATE_SIZE.y
	plate.offset_bottom = -MARGIN
	_root.add_child(plate)
	_fuel = _dial(plate, "FUEL", 0)
	_rounds = _dial(plate, "ROUNDS", 1)
	_hull = _dial(plate, "HULL", 2)
	_rounds.warn_below = -1.0
	_bombs = CounterRow.create("BOMBS", BOMB_ICON)
	_bombs.position = Vector2(COUNTERS_X, 34.0)
	_bombs.size = Vector2(PLATE_SIZE.x - COUNTERS_X - 12.0, CounterRow.ICON_HEIGHT)
	plate.add_child(_bombs)
	_planes = CounterRow.create("PLANES", PLANE_ICON)
	_planes.position = Vector2(COUNTERS_X, 74.0)
	_planes.size = _bombs.size
	plate.add_child(_planes)


func _dial(plate: Plate, title: String, index: int) -> Dial:
	var dial := Dial.create(title)
	dial.name = title.capitalize()
	dial.position = Vector2(18.0 + index * DIAL_STEP, 14.0)
	dial.size = dial.custom_minimum_size
	plate.add_child(dial)
	return dial
