class_name Music
extends Node
## The music, on its own bus: the wireless in the operations hut playing behind the title
## and the mission list, faded in and out as the screens change, and a sting on the
## Debrief, a flourish for a mission complete and a sombre phrase for one failed. Nothing
## plays in flight. All of it is synthesised and built like the other sounds (ADR 0009).

const BUS := "Music"
const WIRELESS_DB := -14.0
const STING_DB := -8.0
const FADE_IN_SECONDS := 1.2
const FADE_OUT_SECONDS := 0.6

var _wireless: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _fade: Tween


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wireless = AudioStreamPlayer.new()
	_wireless.name = "Wireless"
	_wireless.stream = SoundBank.loop(SoundBank.WIRELESS)
	_wireless.volume_db = EngineVoice.SILENT_DB
	_wireless.bus = BUS
	add_child(_wireless)
	_sting = AudioStreamPlayer.new()
	_sting.name = "Sting"
	_sting.volume_db = STING_DB
	_sting.bus = BUS
	add_child(_sting)


## Turn the wireless on, fading up; it keeps playing from where it was.
func play_wireless() -> void:
	if not _wireless.playing:
		_wireless.play()
	_fade_to(WIRELESS_DB, FADE_IN_SECONDS)


## Turn the wireless off, fading down.
func stop_wireless() -> void:
	if not _wireless.playing:
		return
	_fade_to(EngineVoice.SILENT_DB, FADE_OUT_SECONDS)
	_fade.tween_callback(_wireless.stop)


## The Debrief's sting for the outcome.
func sting(won: bool) -> void:
	_sting.stream = SoundBank.STING_WON if won else SoundBank.STING_LOST
	_sting.play()


## Whether the wireless is on, or fading out.
func wireless_playing() -> bool:
	return _wireless.playing


func _fade_to(volume_db: float, over: float) -> void:
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_wireless, "volume_db", volume_db, over)
