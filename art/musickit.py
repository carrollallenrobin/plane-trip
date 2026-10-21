"""A small band for the music scripts (ADR 0009): note names to pitches, a sequencer with
swing, a few synthesised instruments of a 1940s dance band (a reedy lead, a muted horn, an
upright bass, a comping guitar and brushed drums) and the "wireless", the lo-fi treatment
that makes the whole thing sound like it comes out of a valve radio in the operations hut.

A piece is a list of events, (instrument, note, start beat, length in beats, velocity),
rendered at a tempo. Drums take a drum name for the note. Render the piece twice and keep
the second pass to get a loop whose head already carries the tails of its end.
"""

from __future__ import annotations

import math

import numpy as np

from soundkit import (
	RATE,
	bandpass,
	click,
	decay,
	highpass,
	lowpass,
	noise,
	seconds,
	sine,
	soft_clip,
	sweep,
)

NOTE_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(note: str) -> float:
	"""'A4' is 440; 'Bb3', 'F#5' as expected."""
	name = note[0].upper()
	rest = note[1:]
	semitone = NOTE_NAMES[name]
	while rest and rest[0] in "#b":
		semitone += 1 if rest[0] == "#" else -1
		rest = rest[1:]
	octave = int(rest)
	midi = 12 * (octave + 1) + semitone
	return 440.0 * 2.0 ** ((midi - 69) / 12.0)


# --- instruments: each returns a sound of `length` seconds for a pitch and a velocity ---


def _adsr(length: float, a: float, d: float, s: float, r: float) -> np.ndarray:
	t = seconds(length + r)
	env = np.ones(t.size)
	env[t < a] = t[t < a] / a
	in_decay = (t >= a) & (t < a + d)
	env[in_decay] = 1.0 - (1.0 - s) * (t[in_decay] - a) / d
	sustain = (t >= a + d) & (t < length)
	env[sustain] = s
	tail = t >= length
	env[tail] = s * np.exp(-(t[tail] - length) / (r / 3.0))
	return env


def reed(freq: float, length: float, velocity: float) -> np.ndarray:
	"""A clarinet-like lead: odd harmonics, a little vibrato that comes in late."""
	total = length + 0.25
	t = seconds(total)
	vibrato = 1.0 + 0.006 * np.sin(2.0 * math.pi * 5.5 * t) * np.clip((t - 0.15) / 0.3, 0.0, 1.0)
	f = freq * vibrato
	tone = sine(total, f, 1.0) + sine(total, f * 3.0, 0.35) + sine(total, f * 5.0, 0.12) + sine(total, f * 2.0, 0.08)
	breath = bandpass(noise(total, int(freq)), freq * 2.0, freq * 6.0) * 0.04
	return (tone + breath) * _adsr(length, 0.03, 0.08, 0.8, 0.25) * velocity * 0.5


def horn(freq: float, length: float, velocity: float) -> np.ndarray:
	"""A muted trumpet: bright and nasal, pushed through a narrow band."""
	total = length + 0.2
	t = seconds(total)
	vibrato = 1.0 + 0.004 * np.sin(2.0 * math.pi * 6.0 * t)
	f = freq * vibrato
	tone = sum(sine(total, f * k, 1.0 / k) for k in range(1, 9))
	tone = bandpass(tone, freq * 1.5, 3200.0, 1.0)
	return tone * _adsr(length, 0.05, 0.1, 0.7, 0.2) * velocity * 0.5


def bass(freq: float, length: float, velocity: float) -> np.ndarray:
	"""An upright bass plucked: a round thump that fades before the next beat."""
	total = length + 0.3
	tone = sine(total, freq, 1.0) + sine(total, freq * 2.0, 0.35) + sine(total, freq * 3.0, 0.1)
	pluck = click(total, 0.0, 0.004, int(freq * 10), 0.3)
	return (tone + lowpass(pluck, 1200.0)) * decay(total, 0.35) * velocity * 0.9


def guitar(freq: float, length: float, velocity: float) -> np.ndarray:
	"""A rhythm guitar's string, damped quickly: for comping chords."""
	total = length + 0.2
	tone = sum(sine(total, freq * k, 1.0 / (k * k)) for k in range(1, 7))
	pluck = highpass(click(total, 0.0, 0.003, int(freq * 7), 0.4), 800.0)
	return (tone + pluck) * decay(total, 0.18) * velocity * 0.6


def kick(_freq: float, length: float, velocity: float) -> np.ndarray:
	total = max(length, 0.3)
	return sine(total, sweep(total, 110.0, 48.0, 0.04)) * decay(total, 0.08) * velocity


def snare(_freq: float, length: float, velocity: float) -> np.ndarray:
	"""Brushes on a snare: a soft swish, not a crack."""
	total = max(length, 0.25)
	swish = bandpass(noise(total, 77), 900.0, 6000.0) * decay(total, 0.07, 0.005)
	skin = sine(total, 190.0) * decay(total, 0.03) * 0.5
	return (swish + skin) * velocity * 0.8


def hat(_freq: float, length: float, velocity: float) -> np.ndarray:
	total = max(length, 0.1)
	return highpass(noise(total, 78), 6000.0) * decay(total, 0.02) * velocity * 0.5


INSTRUMENTS = {
	"reed": reed,
	"horn": horn,
	"bass": bass,
	"guitar": guitar,
	"kick": kick,
	"snare": snare,
	"hat": hat,
}
DRUMS = {"kick", "snare", "hat"}


# --- the sequencer ---


def render(events, tempo: float, beats: float, swing: float = 0.0, passes: int = 1) -> np.ndarray:
	"""Play the events over `beats` beats at `tempo`, `passes` times back to back. Swing
	delays every off-beat eighth by that fraction of an eighth. Returns the whole thing."""
	beat = 60.0 / tempo
	total = beat * beats * passes + 2.0
	out = np.zeros(int(round(total * RATE)))
	for p in range(passes):
		for instrument, note, start, length, velocity in events:
			when = start + beats * p
			eighth_position = (start * 2.0) % 2.0
			if abs(eighth_position - 1.0) < 1e-6:
				when += swing * 0.5
			freq = 0.0 if instrument in DRUMS else hz(note)
			sound = INSTRUMENTS[instrument](freq, length * beat, velocity)
			offset = int(round(when * beat * RATE))
			end = min(offset + sound.size, out.size)
			out[offset:end] += sound[: end - offset]
	return out


def loop_of(events, tempo: float, beats: float, swing: float = 0.0) -> np.ndarray:
	"""A seamless loop: the piece rendered twice, keeping the second pass, whose head already
	carries the tails of the first pass's end."""
	beat = 60.0 / tempo
	both = render(events, tempo, beats, swing, passes=2)
	start = int(round(beat * beats * RATE))
	return both[start : start * 2]


def chord(instrument: str, notes, start: float, length: float, velocity: float):
	return [(instrument, note, start, length, velocity) for note in notes]


# --- the wireless ---


def wireless(x: np.ndarray, seed: int = 90) -> np.ndarray:
	"""Through a valve radio: a narrow band, a little overdrive, a slow flutter, the hum of
	the mains and some crackle under it all."""
	band = bandpass(x, 220.0, 3600.0, 1.5)
	band = soft_clip(band / (np.max(np.abs(band)) + 1e-9) * 1.4, 1.5)
	t = seconds(band.size / RATE)
	flutter = 1.0 + 0.03 * np.sin(2.0 * math.pi * 0.7 * t) + 0.015 * np.sin(2.0 * math.pi * 2.3 * t)
	hum = sine(band.size / RATE, 50.0, 0.012) + sine(band.size / RATE, 100.0, 0.006)
	crackle = highpass(noise(band.size / RATE, seed), 2500.0)
	gate = (noise(band.size / RATE, seed + 1) > 0.985).astype(float)
	crackle = crackle * gate * 0.25
	hiss = bandpass(noise(band.size / RATE, seed + 2), 1500.0, 6000.0) * 0.012
	return band * flutter + hum + crackle + hiss
