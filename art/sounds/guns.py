"""What fires and what drops: the Machine Gun's shot, an Anti-Aircraft Gun's lighter and
higher one, a Flak Gun's heavy report, and the clunk of a Bomb leaving its rack (ADR 0009).
The game jitters the pitch of each a little so a burst is not one sound repeated.
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


def machine_gun() -> np.ndarray:
	d = 0.14
	crack = click(d, 0.0, 0.003, 1, 1.0)
	body = sine(d, sweep(d, 260.0, 120.0, 0.02)) * decay(d, 0.03)
	blast = bandpass(noise(d, 2), 600.0, 5000.0) * decay(d, 0.022)
	tail = lowpass(noise(d, 3), 500.0) * decay(d, 0.05, 0.01)
	return soft_clip(mix(crack * 0.8, body * 0.9, blast * 0.8, tail * 0.5), 1.6)


def ground_gun() -> np.ndarray:
	d = 0.11
	crack = click(d, 0.0, 0.002, 4, 1.0)
	body = sine(d, sweep(d, 420.0, 200.0, 0.015)) * decay(d, 0.02)
	blast = bandpass(noise(d, 5), 1200.0, 7000.0) * decay(d, 0.016)
	return soft_clip(mix(crack * 0.7, body * 0.7, blast * 0.9), 1.5)


def flak_fire() -> np.ndarray:
	d = 0.8
	crack = click(d, 0.0, 0.004, 6, 1.0)
	boom = sine(d, sweep(d, 110.0, 45.0, 0.08)) * decay(d, 0.22)
	blast = lowpass(noise(d, 7), 1200.0) * decay(d, 0.09)
	rumble = lowpass(noise(d, 8), 250.0) * decay(d, 0.35, 0.05)
	return soft_clip(mix(crack * 0.6, boom * 1.1, blast * 0.9, rumble * 0.7), 1.8)


def bomb_release() -> np.ndarray:
	d = 0.22
	latch = click(d, 0.0, 0.004, 9, 0.8)
	clunk = modes(d, [(240.0, 0.9, 0.05), (610.0, 0.5, 0.035), (1480.0, 0.25, 0.02)])
	rack = highpass(modes(d, [(3200.0, 0.3, 0.03)], 0.03), 1000.0)
	return mix(latch, clunk, rack)


if __name__ == "__main__":
	out = output_dir()
	write(out / "machine_gun.wav", machine_gun())
	write(out / "ground_gun.wav", ground_gun())
	write(out / "flak_fire.wav", flak_fire())
	write(out / "bomb_release.wav", bomb_release(), 0.7)
