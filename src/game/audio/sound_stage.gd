class_name SoundStage
extends Node3D
## Plays the Picture's sound Cues where they happened: a fixed pool of 3D voices on the World
## bus, each placed at the Cue's point on the action plane so the camera, as the listener,
## pans it. The Picture has already decided how loud and at what pitch; the voices attenuate
## nothing themselves. A Cue arriving with every voice busy takes the oldest.

const VOICES := 16
## Bombs whistling at once; more than this fall silent, nearest first served.
const WHISTLE_VOICES := 6

var _voices: Array[AudioStreamPlayer3D] = []
var _next := 0
var _whistle_voices: Array[AudioStreamPlayer3D] = []
## Which Bomb each whistle voice follows, by index; null for a free voice.
var _whistling: Array[Bomb] = []


func _ready() -> void:
	for i in VOICES:
		_voices.append(_voice("Voice%d" % i))
	for i in WHISTLE_VOICES:
		var voice := _voice("Whistle%d" % i)
		voice.stream = SoundBank.loop(SoundBank.WHISTLE)
		_whistle_voices.append(voice)
		_whistling.append(null)


## Keep a looping voice on every Bomb the Picture hears whistling, and free the rest.
func whistle(whistles: Array[Picture.Whistle]) -> void:
	var heard: Array[Bomb] = []
	for entry in whistles:
		heard.append(entry.bomb)
	for i in WHISTLE_VOICES:
		if _whistling[i] != null and not heard.has(_whistling[i]):
			_whistling[i] = null
			_whistle_voices[i].stop()
	for entry in whistles:
		var i := _whistling.find(entry.bomb)
		if i < 0:
			i = _whistling.find(null)
			if i < 0:
				continue
			_whistling[i] = entry.bomb
			_whistle_voices[i].play()
		var voice := _whistle_voices[i]
		voice.volume_db = entry.volume_db
		voice.pitch_scale = entry.pitch
		voice.global_position = Vector3(entry.position.x, entry.position.y, 0.0)


## How many Bombs are whistling right now.
func whistling() -> int:
	var count := 0
	for bomb in _whistling:
		if bomb != null:
			count += 1
	return count


func _voice(voice_name: String) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.name = voice_name
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	voice.bus = UiSounds.WORLD_BUS
	add_child(voice)
	return voice


## Play a sound Cue. Cues that are not sounds (a hit flash) are not for this node.
func play(cue: Picture.Cue) -> void:
	var stream := stream_for(cue)
	if stream == null or cue.volume_db <= Picture.SILENT_DB:
		return
	var voice := _voices[_next]
	_next = (_next + 1) % VOICES
	voice.stream = stream
	voice.volume_db = cue.volume_db
	voice.pitch_scale = cue.pitch
	voice.global_position = Vector3(cue.position.x, cue.position.y, 0.0)
	voice.play()


## How many voices are sounding right now.
func playing() -> int:
	var count := 0
	for voice in _voices:
		if voice.playing:
			count += 1
	return count


## The sound a Cue is played with, or null for a Cue that is not a sound.
static func stream_for(cue: Picture.Cue) -> AudioStream:
	match cue.kind:
		Picture.Cue.Kind.GUN:
			return SoundBank.MACHINE_GUN
		Picture.Cue.Kind.GROUND_GUN:
			return SoundBank.GROUND_GUN
		Picture.Cue.Kind.FLAK_FIRE:
			return SoundBank.FLAK_FIRE
		Picture.Cue.Kind.RELEASE:
			return SoundBank.BOMB_RELEASE
		Picture.Cue.Kind.BLAST:
			return SoundBank.BOMB_BLAST
		Picture.Cue.Kind.SHELL:
			return SoundBank.SHELL_BURST
		Picture.Cue.Kind.COLLAPSE:
			return SoundBank.COLLAPSE
		Picture.Cue.Kind.SPLASH:
			return SoundBank.SPLASH
		Picture.Cue.Kind.TOUCHDOWN:
			return SoundBank.TOUCHDOWN
		Picture.Cue.Kind.HIT:
			return SoundBank.HIT_TAKEN if cue.own else SoundBank.HIT_PLANE
		Picture.Cue.Kind.IMPACT:
			match cue.surface:
				BulletHit.Surface.TARGET:
					return SoundBank.RICOCHET
				BulletHit.Surface.WATER:
					return SoundBank.PLINK
				_:
					return SoundBank.THUD
	return null
