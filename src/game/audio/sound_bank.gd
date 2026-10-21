class_name SoundBank
## Every sound the game plays, built by scripts/build-sounds.sh from art/sounds/ into
## assets/audio/ (ADR 0009). Loops are seamless by construction; the one-shots are short.
## Nothing else loads a sound file.

## The plane: pitched by EngineVoice.
const ENGINE := preload("res://assets/audio/engine.wav")
const AIRFLOW := preload("res://assets/audio/airflow.wav")
const ROLLING := preload("res://assets/audio/rolling.wav")
## A falling Bomb, pitched up by the Picture as it gathers speed.
const WHISTLE := preload("res://assets/audio/whistle.wav")
## The airfield behind the title.
const WIND := preload("res://assets/audio/wind.wav")
## Guns and the Bomb leaving its rack.
const MACHINE_GUN := preload("res://assets/audio/machine_gun.wav")
const GROUND_GUN := preload("res://assets/audio/ground_gun.wav")
const FLAK_FIRE := preload("res://assets/audio/flak_fire.wav")
const BOMB_RELEASE := preload("res://assets/audio/bomb_release.wav")
## Blasts.
const BOMB_BLAST := preload("res://assets/audio/bomb_blast.wav")
const SHELL_BURST := preload("res://assets/audio/shell_burst.wav")
const COLLAPSE := preload("res://assets/audio/collapse.wav")
const SPLASH := preload("res://assets/audio/splash.wav")
## Where a round ends.
const HIT_PLANE := preload("res://assets/audio/hit_plane.wav")
const HIT_TAKEN := preload("res://assets/audio/hit_taken.wav")
const RICOCHET := preload("res://assets/audio/ricochet.wav")
const THUD := preload("res://assets/audio/thud.wav")
const PLINK := preload("res://assets/audio/plink.wav")
## Wheels meeting the runway.
const TOUCHDOWN := preload("res://assets/audio/touchdown.wav")
## The menus.
const UI_TICK := preload("res://assets/audio/ui_tick.wav")
const UI_CLACK := preload("res://assets/audio/ui_clack.wav")
const UI_BACK := preload("res://assets/audio/ui_back.wav")
const STAMP := preload("res://assets/audio/stamp.wav")
## An objective turning: the typewriter's bell for complete, a dull clank for failed.
const BELL := preload("res://assets/audio/bell.wav")
const BELL_LOW := preload("res://assets/audio/bell_low.wav")
## The music: the wireless behind the title, the Debrief's stings.
const WIRELESS := preload("res://assets/audio/wireless.wav")
const STING_WON := preload("res://assets/audio/sting_won.wav")
const STING_LOST := preload("res://assets/audio/sting_lost.wav")


## A loop plays end to start. The import settings say so for the loops (edit/loop_mode in
## their .import files); this makes sure of it for a stream that lost them.
static func loop(stream: AudioStreamWAV) -> AudioStreamWAV:
	if stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
	return stream
