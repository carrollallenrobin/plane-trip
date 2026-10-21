"""The loops: the engine, the airflow over the plane, the wheels rolling on the runway, a
falling Bomb's whistle, and the wind over the airfield behind the title (ADR 0009). Each is seamless: periodic parts
run a whole number of cycles per loop and the noise is cross-faded tail into head. The game
pitches the engine and the airflow by the plane's state (EngineVoice), so each is built at
its resting pitch.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import numpy as np  # noqa: E402

from soundkit import (  # noqa: E402
	RATE,
	bandpass,
	brown,
	click,
	crackle,
	decay,
	gain_db,
	highpass,
	lowpass,
	mix,
	noise,
	output_dir,
	pink,
	pulses,
	resonance,
	seamless,
	seconds,
	sine,
	soft_clip,
	write,
)

# A radial engine fires this many times a second at the resting pitch: slow enough to hear
# as a chug, fast enough to read as one motor. A whole number per second keeps the loop.
FIRING_RATE = 36.0


def engine() -> np.ndarray:
	duration = 1.0
	# One firing: a short thump with a bark of exhaust noise on it.
	pulse_len = 1.0 / FIRING_RATE * 0.9
	thump = sine(pulse_len, 90.0) * decay(pulse_len, 0.006)
	bark = bandpass(noise(pulse_len, 11), 250.0, 2400.0) * decay(pulse_len, 0.004)
	pulse = thump * 1.4 + bark * 0.9
	firing = pulses(duration, FIRING_RATE, pulse)
	# The crankshaft drone under it, whole cycles per second.
	drone = (
		sine(duration, FIRING_RATE, 0.25)
		+ sine(duration, FIRING_RATE * 2.0, 0.2)
		+ sine(duration, FIRING_RATE * 3.0, 0.1)
	)
	# The exhaust's steady hiss, and the airframe rattling with it.
	hiss = seamless(lowpass(noise(duration + 0.05, 12), 1800.0), 0.05, duration) * 0.12
	rattle = seamless(resonance(noise(duration + 0.05, 13), 700.0, 6.0), 0.05, duration) * 0.08
	out = mix(firing, drone, hiss, rattle)
	return soft_clip(out / np.max(np.abs(out)) * 1.6, 1.3)


def airflow() -> np.ndarray:
	duration = 2.0
	extra = duration + 0.1
	rush = bandpass(pink(extra, 21), 250.0, 3500.0)
	# Some turbulence: a slow wobble, two whole cycles per loop.
	wobble = 1.0 + 0.25 * sine(extra, 1.0)
	return seamless(rush * wobble, 0.1, duration)


def rolling() -> np.ndarray:
	duration = 1.0
	extra = duration + 0.08
	rumble = lowpass(brown(extra, 31), 180.0)
	# The wheels knocking over the joints in the runway.
	knock = lowpass(noise(0.03, 32), 900.0) * decay(0.03, 0.006)
	knocks = pulses(extra, 9.0, knock, jitter=0.3, seed=33) * 0.5
	chatter = crackle(extra, 40.0, 0.002, 34) * 0.15
	out = mix(rumble * 0.8, knocks, highpass(chatter, 1500.0))
	return seamless(out, 0.08, duration)


def wind() -> np.ndarray:
	duration = 4.0
	extra = duration + 0.2
	gusts = lowpass(pink(extra, 41), 900.0)
	# One slow swell per loop, so the join is seamless; the extra tail is the next cycle's
	# head, so the cross-fade blends like with like.
	swell = 0.7 + 0.3 * np.sin(2.0 * np.pi * seconds(extra) / duration - np.pi / 2.0)
	whistle = resonance(noise(extra, 42), 1400.0, 12.0) * (0.3 + 0.7 * swell) * 0.08
	# A distant engine idling somewhere on the field: whole cycles per loop.
	far = lowpass(pulses(duration, 20.0, sine(0.04, 80.0) * decay(0.04, 0.008)), 300.0) * 0.08
	return mix(seamless(gusts * swell, 0.2, duration), seamless(whistle, 0.2, duration), far)


def whistle() -> np.ndarray:
	"""A Bomb falling: the air over its fins, a breathy tone the game pitches up as it
	gathers speed. Built at its resting pitch, whole cycles per loop."""
	duration = 1.0
	extra = duration + 0.05
	tone = sine(duration, 1320.0, 0.5) + sine(duration, 2640.0, 0.15)
	# A flutter of eight cycles a second, whole per loop.
	flutter = 1.0 + 0.2 * sine(duration, 8.0)
	breath = seamless(resonance(noise(extra, 51), 1320.0, 9.0), 0.05, duration) * 0.9
	return mix(tone * flutter, breath)


if __name__ == "__main__":
	out = output_dir()
	write(out / "engine.wav", engine())
	write(out / "airflow.wav", airflow())
	write(out / "rolling.wav", rolling())
	write(out / "whistle.wav", whistle())
	write(out / "wind.wav", wind())
