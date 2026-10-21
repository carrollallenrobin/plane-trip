"""The menus' sounds (ADR 0009): a tick as focus moves, a typewriter key striking paper on a
choice and a lower one going back, a rubber Stamp landing on a desk, and the typewriter's
bell for an objective turning complete, with a dull clank for one failed.
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


def tick() -> np.ndarray:
	d = 0.04
	return mix(click(d, 0.0, 0.0015, 51, 0.6), modes(d, [(2400.0, 0.5, 0.008), (3900.0, 0.3, 0.005)]))


def key(tone: float, seed: int) -> np.ndarray:
	"""A typewriter key: the type bar striking the platen through the paper."""
	d = 0.09
	strike = click(d, 0.0, 0.002, seed, 1.0)
	bar = modes(d, [(tone, 0.8, 0.02), (tone * 2.7, 0.4, 0.012), (tone * 5.1, 0.2, 0.006)])
	platen = lowpass(noise(d, seed + 1), 900.0) * decay(d, 0.015)
	return soft_clip(mix(strike * 0.8, bar, platen * 0.9), 1.3)


def clack() -> np.ndarray:
	return key(520.0, 52)


def back() -> np.ndarray:
	return key(300.0, 54)


def stamp() -> np.ndarray:
	d = 0.35
	slap = click(d, 0.0, 0.006, 56, 0.9)
	desk = sine(d, sweep(d, 95.0, 45.0, 0.06)) * decay(d, 0.09)
	wood = modes(d, [(180.0, 0.6, 0.08), (410.0, 0.35, 0.05)])
	rubber = lowpass(noise(d, 57), 600.0) * decay(d, 0.03)
	return soft_clip(mix(slap, desk * 1.1, wood, rubber * 0.8), 1.6)


def bell() -> np.ndarray:
	"""The carriage bell: bright, ringing out over half a second."""
	d = 0.9
	strike = click(d, 0.0, 0.0015, 58, 0.5)
	ring = modes(d, [(2960.0, 0.8, 0.28), (4420.0, 0.4, 0.2), (7300.0, 0.2, 0.12), (1480.0, 0.15, 0.3)])
	return mix(strike, ring)


def bell_low() -> np.ndarray:
	"""The same bell with a hand on it: a dull clank for something gone wrong."""
	d = 0.4
	strike = click(d, 0.0, 0.003, 59, 0.7)
	clank = modes(d, [(640.0, 0.8, 0.07), (910.0, 0.5, 0.05), (1380.0, 0.3, 0.03)])
	body = lowpass(noise(d, 60), 500.0) * decay(d, 0.03)
	return soft_clip(mix(strike, clank, body * 0.6), 1.3)


if __name__ == "__main__":
	out = output_dir()
	write(out / "bell.wav", bell(), 0.8)
	write(out / "bell_low.wav", bell_low(), 0.8)
	write(out / "ui_tick.wav", tick(), 0.6)
	write(out / "ui_clack.wav", clack(), 0.8)
	write(out / "ui_back.wav", back(), 0.8)
	write(out / "stamp.wav", stamp())
