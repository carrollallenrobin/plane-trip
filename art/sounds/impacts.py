"""Where a round ends (ADR 0009): a strike on a Plane's frame, the heavier one the player
feels on their own Plane, a ricochet off a Ground Target, a thud into the ground and a plink
into the Water. Short, so a burst of six reads as six. Also the wheels meeting the runway.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import numpy as np  # noqa: E402

from soundkit import (  # noqa: E402
	bandpass,
	click,
	decay,
	highpass,
	lowpass,
	mix,
	modes,
	noise,
	output_dir,
	sine,
	soft_clip,
	sweep,
	write,
)


def hit_plane() -> np.ndarray:
	d = 0.18
	strike = click(d, 0.0, 0.003, 31, 1.0)
	frame = modes(d, [(1900.0, 0.7, 0.05), (2750.0, 0.5, 0.04), (4100.0, 0.3, 0.025), (620.0, 0.4, 0.07)])
	tear = bandpass(noise(d, 32), 2000.0, 9000.0) * decay(d, 0.02)
	return soft_clip(mix(strike * 0.7, frame, tear * 0.6), 1.4)


def hit_taken() -> np.ndarray:
	d = 0.32
	strike = click(d, 0.0, 0.004, 33, 1.0)
	thump = sine(d, sweep(d, 160.0, 70.0, 0.04)) * decay(d, 0.07)
	frame = modes(d, [(640.0, 0.8, 0.09), (1150.0, 0.6, 0.07), (1720.0, 0.4, 0.05), (2900.0, 0.25, 0.03)])
	rattle = bandpass(noise(d, 34), 800.0, 5000.0) * decay(d, 0.06, 0.01)
	return soft_clip(mix(strike * 0.8, thump * 1.0, frame * 0.9, rattle * 0.6), 1.7)


def ricochet() -> np.ndarray:
	d = 0.35
	strike = click(d, 0.0, 0.002, 35, 0.9)
	ping = modes(d, [(3100.0, 0.6, 0.04), (5200.0, 0.3, 0.03)])
	whine = sine(d, sweep(d, 2600.0, 900.0, 0.12)) * decay(d, 0.14, 0.01) * 0.5
	return soft_clip(mix(strike, ping, whine), 1.3)


def thud() -> np.ndarray:
	d = 0.14
	strike = click(d, 0.0, 0.003, 36, 0.6)
	earth = lowpass(noise(d, 37), 350.0) * decay(d, 0.04)
	thump = sine(d, sweep(d, 110.0, 50.0, 0.03)) * decay(d, 0.05)
	return soft_clip(mix(strike, earth * 1.2, thump * 0.9), 1.4)


def plink() -> np.ndarray:
	d = 0.3
	slap = click(d, 0.0, 0.003, 38, 0.7)
	bloop = sine(d, sweep(d, 900.0, 260.0, 0.05)) * decay(d, 0.06)
	spray = bandpass(noise(d, 39), 1500.0, 8000.0) * decay(d, 0.09, 0.005)
	return soft_clip(mix(slap, bloop * 0.8, spray * 0.9), 1.3)


def touchdown() -> np.ndarray:
	"""Wheels meeting the runway: a chirp of rubber, a thump through the frame, a rattle."""
	d = 0.45
	chirp = sine(d, sweep(d, 1500.0, 650.0, 0.05)) * decay(d, 0.07) * 0.6
	thump = sine(d, sweep(d, 120.0, 55.0, 0.05)) * decay(d, 0.09)
	frame = modes(d, [(380.0, 0.5, 0.08), (760.0, 0.3, 0.05)])
	rattle = bandpass(noise(d, 40), 600.0, 4000.0) * decay(d, 0.12, 0.02) * 0.5
	return soft_clip(mix(chirp, thump * 1.1, frame, rattle), 1.4)


if __name__ == "__main__":
	out = output_dir()
	write(out / "touchdown.wav", touchdown())
	write(out / "hit_plane.wav", hit_plane())
	write(out / "hit_taken.wav", hit_taken())
	write(out / "ricochet.wav", ricochet())
	write(out / "thud.wav", thud())
	write(out / "plink.wav", plink())
