class_name UiSounds
extends Node
## The menus' sounds on the UI bus: a tick as focus moves, a typewriter clack on a choice, a
## lower clack going back, a thunk as a Stamp lands (SoundBank, ADR 0009). Also ducks the
## World bus under a Sheet that covers the action.

const BUS := "UI"
const WORLD_BUS := "World"
## How far the World drops under the Debrief and the pause, and how fast.
const DUCK_DB := -12.0
const DUCK_SECONDS := 0.3

var _tick: AudioStreamPlayer
var _clack: AudioStreamPlayer
var _back: AudioStreamPlayer
var _thunk: AudioStreamPlayer
var _duck_tween: Tween


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tick = _player(SoundBank.UI_TICK, -10.0)
	_clack = _player(SoundBank.UI_CLACK, -6.0)
	_back = _player(SoundBank.UI_BACK, -6.0)
	_thunk = _player(SoundBank.STAMP, 0.0)


func tick() -> void:
	_tick.play()


func clack() -> void:
	_clack.play()


func back() -> void:
	_back.play()


func thunk() -> void:
	_thunk.play()


## Bring the World's sound down to a murmur, or back up.
func duck_world(down: bool) -> void:
	var bus := AudioServer.get_bus_index(WORLD_BUS)
	if bus < 0:
		return
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(bus, db),
		AudioServer.get_bus_volume_db(bus),
		DUCK_DB if down else 0.0,
		DUCK_SECONDS
	)


func _player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = BUS
	add_child(player)
	return player
