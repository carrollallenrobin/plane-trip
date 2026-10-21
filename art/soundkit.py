"""Shared helpers for the sound scripts in art/sounds/ (ADR 0009).

Every sound the game plays is synthesised here from a few primitives: shaped noise, decaying
sines (the modes of something struck), pulses at a rate (an engine firing), envelopes and
filters done in the frequency domain, and a soft clip for punch. Scripts build a sound as a
numpy array in [-1, 1] at RATE and write it with `write`, so the .wav in assets/audio/ is
never edited by hand: change the script and rebuild (scripts/build-sounds.sh).

Loops are made seamless by construction: periodic parts use whole cycles per loop, and
noisy parts are cross-faded tail into head with `seamless`.
"""

from __future__ import annotations

import math
import struct
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100


# --- time and noise ---


def seconds(duration: float) -> np.ndarray:
	"""Sample times for a sound this long."""
	return np.arange(int(round(duration * RATE))) / RATE


def noise(duration: float, seed: int) -> np.ndarray:
	"""White noise in [-1, 1], the same for the same seed."""
	rng = np.random.default_rng(seed)
	return rng.uniform(-1.0, 1.0, int(round(duration * RATE)))


def pink(duration: float, seed: int) -> np.ndarray:
	"""Noise falling 3 dB per octave: rain, wind and airflow rather than hiss."""
	return normalize(shape(noise(duration, seed), lambda f: 1.0 / np.sqrt(np.maximum(f, 20.0))))


def brown(duration: float, seed: int) -> np.ndarray:
	"""Noise falling 6 dB per octave: rumble."""
	return normalize(shape(noise(duration, seed), lambda f: 1.0 / np.maximum(f, 20.0)))


# --- filters, in the frequency domain (zero phase, so transients stay where they are) ---


def shape(x: np.ndarray, gain) -> np.ndarray:
	"""Multiply the spectrum by gain(frequency_hz)."""
	spectrum = np.fft.rfft(x)
	f = np.fft.rfftfreq(x.size, 1.0 / RATE)
	return np.fft.irfft(spectrum * gain(f), n=x.size)


def lowpass(x: np.ndarray, cutoff: float, order: float = 2.0) -> np.ndarray:
	return shape(x, lambda f: 1.0 / np.sqrt(1.0 + (f / cutoff) ** (2.0 * order)))


def highpass(x: np.ndarray, cutoff: float, order: float = 2.0) -> np.ndarray:
	return shape(x, lambda f: 1.0 / np.sqrt(1.0 + (cutoff / np.maximum(f, 1e-6)) ** (2.0 * order)))


def bandpass(x: np.ndarray, low: float, high: float, order: float = 2.0) -> np.ndarray:
	return lowpass(highpass(x, low, order), high, order)


def resonance(x: np.ndarray, centre: float, q: float) -> np.ndarray:
	"""A peaking band around centre, width centre/q: the ring of a drum skin or a pipe."""
	width = centre / q
	return shape(x, lambda f: 1.0 / np.sqrt(1.0 + ((f - centre) / (width / 2.0)) ** 2))


# --- envelopes ---


def decay(duration: float, tau: float, start: float = 0.0) -> np.ndarray:
	"""An exponential fall from 1 at `start` seconds, 1/e after tau more; zero before start."""
	t = seconds(duration)
	env = np.exp(-np.maximum(t - start, 0.0) / tau)
	env[t < start] = 0.0
	return env


def attack(duration: float, rise: float) -> np.ndarray:
	"""A linear rise over `rise` seconds, then 1."""
	t = seconds(duration)
	return np.clip(t / max(rise, 1e-6), 0.0, 1.0)


def fade(x: np.ndarray, seconds_in: float = 0.0, seconds_out: float = 0.0) -> np.ndarray:
	y = x.copy()
	n_in = int(seconds_in * RATE)
	n_out = int(seconds_out * RATE)
	if n_in > 0:
		y[:n_in] *= np.linspace(0.0, 1.0, n_in)
	if n_out > 0:
		y[-n_out:] *= np.linspace(1.0, 0.0, n_out)
	return y


# --- voices ---


def sine(duration: float, freq, amplitude: float = 1.0, phase: float = 0.0) -> np.ndarray:
	"""A sine at a fixed frequency, or one that follows an array of frequencies per sample."""
	t = seconds(duration)
	if np.ndim(freq) == 0:
		return amplitude * np.sin(2.0 * math.pi * freq * t + phase)
	phases = np.cumsum(np.asarray(freq) / RATE) * 2.0 * math.pi
	return amplitude * np.sin(phases + phase)


def sweep(duration: float, start: float, end: float, tau: float) -> np.ndarray:
	"""Frequencies per sample sliding from start toward end with time constant tau."""
	t = seconds(duration)
	return end + (start - end) * np.exp(-t / tau)


def modes(duration: float, partials, start: float = 0.0) -> np.ndarray:
	"""Something struck: decaying sines at (frequency, amplitude, decay seconds)."""
	out = np.zeros(int(round(duration * RATE)))
	for freq, amp, tau in partials:
		out += sine(duration, freq, amp) * decay(duration, tau, start)
	return out


def click(duration: float, at: float, length: float, seed: int, amplitude: float = 1.0) -> np.ndarray:
	"""A very short burst of noise at `at` seconds: a transient."""
	out = np.zeros(int(round(duration * RATE)))
	start = int(at * RATE)
	n = max(int(length * RATE), 1)
	burst = noise(length, seed)[:n] * np.linspace(1.0, 0.0, n) ** 2
	end = min(start + n, out.size)
	out[start:end] += amplitude * burst[: end - start]
	return out


def pulses(duration: float, rate_hz: float, pulse, jitter: float = 0.0, seed: int = 0) -> np.ndarray:
	"""Repeat a short array every 1/rate_hz seconds. A whole number of pulses per loop
	keeps a loop seamless. `jitter` shifts each pulse by up to that fraction of a period."""
	out = np.zeros(int(round(duration * RATE)))
	period = RATE / rate_hz
	rng = np.random.default_rng(seed)
	count = int(round(duration * rate_hz))
	for i in range(count):
		offset = max(int(i * period + rng.uniform(-jitter, jitter) * period), 0)
		end = min(offset + pulse.size, out.size)
		if offset < out.size:
			out[offset:end] += pulse[: end - offset]
	return out


def crackle(duration: float, per_second: float, length: float, seed: int, start: float = 0.0, tau: float = 1.0) -> np.ndarray:
	"""Sparse random clicks, thinning out after `start` with time constant tau: debris,
	burning, brick falling."""
	rng = np.random.default_rng(seed)
	out = np.zeros(int(round(duration * RATE)))
	t = 0.0
	i = 0
	while t < duration:
		if t >= start:
			amp = math.exp(-(t - start) / tau) * rng.uniform(0.3, 1.0)
			out += click(duration, t, length * rng.uniform(0.5, 1.5), seed + i, amp)
		t += rng.exponential(1.0 / per_second)
		i += 1
	return out


# --- mixing ---


def mix(*layers: np.ndarray) -> np.ndarray:
	"""Sum layers of possibly different lengths."""
	length = max(layer.size for layer in layers)
	out = np.zeros(length)
	for layer in layers:
		out[: layer.size] += layer
	return out


def gain_db(x: np.ndarray, db: float) -> np.ndarray:
	return x * (10.0 ** (db / 20.0))


def soft_clip(x: np.ndarray, drive: float = 1.0) -> np.ndarray:
	"""Round the peaks off like tape: louder and denser without clicks."""
	return np.tanh(x * drive) / math.tanh(drive)


def normalize(x: np.ndarray, peak: float = 1.0) -> np.ndarray:
	top = float(np.max(np.abs(x)))
	return x * (peak / top) if top > 0 else x


def seamless(x: np.ndarray, crossfade: float, duration: float | None = None) -> np.ndarray:
	"""Make a loop join cleanly: the last `crossfade` seconds are blended into the first and
	dropped, so playing the result end to start has no seam. With `duration`, x is first cut
	to duration + crossfade, so the loop comes out exactly `duration` long."""
	if duration is not None:
		x = x[: int(round((duration + crossfade) * RATE))]
	n = int(crossfade * RATE)
	if n <= 0 or n >= x.size:
		return x
	ramp = np.linspace(0.0, 1.0, n)
	head = x[:n] * ramp + x[-n:] * (1.0 - ramp)
	return np.concatenate([head, x[n:-n]])


# --- output ---


def write(path: str | Path, x: np.ndarray, peak: float = 0.95, half_rate: bool = False) -> None:
	"""Write 16-bit mono at RATE, normalised to `peak`. With half_rate, at RATE / 2 after a
	low-pass, for a long sound with nothing above a few kilohertz, such as the wireless."""
	y = normalize(np.asarray(x, dtype=np.float64), peak)
	rate = RATE
	if half_rate:
		y = lowpass(y, RATE / 4.0 * 0.9, 8.0)[::2]
		rate = RATE // 2
	data = (np.clip(y, -1.0, 1.0) * 32767.0).astype("<i2")
	path = Path(path)
	path.parent.mkdir(parents=True, exist_ok=True)
	with wave.open(str(path), "wb") as out:
		out.setnchannels(1)
		out.setsampwidth(2)
		out.setframerate(rate)
		out.writeframes(data.tobytes())
	print(f"wrote {path} ({y.size / rate:.2f} s at {rate} Hz)")


def output_dir() -> Path:
	"""Where a script writes: the first argument after `--`, or assets/audio/."""
	args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
	return Path(args[0]) if args else Path(__file__).resolve().parent.parent / "assets" / "audio"
