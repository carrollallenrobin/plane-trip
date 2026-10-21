---
status: accepted
---

# Sounds are synthesis scripts built to WAV

Every sound the game plays is a Python script under `art/sounds/`, one per family (loops, guns, bursts, impacts, UI), sharing `art/soundkit.py`: shaped noise, decaying sines for the modes of something struck, pulses at a rate for an engine firing, envelopes, frequency-domain filters and a soft clip. `scripts/build-sounds.sh` runs them with numpy through `uv` (pinned, cached inside the repo) into `assets/audio/*.wav`, 16-bit mono at 44.1 kHz, then runs the Godot import; the WAVs are imported as PCM with the loops marked. The files are committed, so playing and testing need no Python, and never edited by hand: change the script and rebuild in the same commit, as with the models (ADR 0005). `scripts/preview-sound.sh` draws a sound's waveform and spectrogram to a PNG for a look without speakers. `SoundBank` is the one place that loads a sound.

How the sounds are used is split the same way the picture is (ADR 0007). The pure `Picture` decides which happenings are heard, how loud from the player's Plane, at what pitch (a seeded jitter so a burst of six rounds is six sounds) and where, and returns Cues; `SoundStage` plays them on a fixed pool of 3D voices placed on the action plane, with attenuation off, so the camera as listener pans them and nothing else is decided in the scene. A Plane's own loops, the engine, the air over the airframe and the wheels on the runway, follow its state through the pure `EngineVoice`, which spools, idles, coughs on the last fuel, sputters in a Spin and stops with the Plane. Continuous sounds that belong to no node, the Bombs whistling as they fall, are read from World state by the Picture each step and kept on their own looping voices by the SoundStage, one per Bomb while it is in the air. A touchdown is heard the same way, from a Plane that was off the ground and is on an Airfield now. The menus' sounds and the wind behind the title come from the same bank, and so does the music: `art/musickit.py` is a small sequencer with a synthesised dance band and the "wireless" treatment, and `art/sounds/music.py` is the tune and the Debrief's stings, written as notes. A radio's narrow band and crackle are what let a synthesised band pass; the music is never heard clean.

## Considered options

- **Keep generating sounds in GDScript at start-up**, as the placeholders were. No assets and nothing to license, but the synthesis was limited to what a loop over samples can do at start-up, the sounds were generated on every launch and on the web target, and nobody could look at one outside the game.
- **Recorded samples under CC0** (Freesound, OpenGameArt, Kenney). Real engines and real guns, but nothing can be auditioned where this project is built, every file needs its licence checked and carried, and a sample is a binary nobody can diff or regenerate. A synthesised sound is text, reviewable like a model script, and can be redrawn as a spectrogram. If a recorded sound is ever brought in, it goes under `assets/audio/` with its licence beside it like the fonts (ADR 0008), CC0 only, and this ADR gains a note.
- **Audio in Ogg Vorbis** for size. The whole bank is about a megabyte of WAV; encoding would add a dependency for nothing yet.
- **Panning by hand**, a stereo gain per Cue, instead of 3D voices. The 3D players do it from the camera for free and will keep doing it if the camera ever moves.

## Consequences

- A new sound is a function in a family script plus a constant in `SoundBank`; a changed sound is a script change plus the rebuilt WAV in the same commit.
- `uv` becomes a build-time dependency for sounds only, as Blender is for models.
- Loops are seamless by construction: a whole number of cycles per loop for the periodic parts, a cross-fade of tail into head for the noise. A loop with a click at the join is a script bug.
- Pitch and volume are the Picture's and the EngineVoice's business and are tested there; the scene tests check wiring only, since headless Godot plays nothing.
- Hearing has a range of 300 m from the listener: the player's Plane, or where it was lost while the player is dead, so their own end and the fight over the wreck are heard under the Band and the Debrief. (Until the first playtest of this pass the dead heard nothing, which left a lost mission's Debrief silent.)
- A limiter on the Master bus keeps a close Bomb from clipping over the engine.
