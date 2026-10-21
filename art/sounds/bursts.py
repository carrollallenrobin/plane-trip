"""What a Blast sounds like: a Bomb's blast, a Shell's crump in the air, a Ground Target
coming down, and a Plane going into the Water (ADR 0009). A Plane that explodes uses the
Bomb's blast.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import numpy as np  # noqa: E402

from soundkit import (  # noqa: E402
	bandpass,
	brown,
	click,
	crackle,
	decay,
	highpass,
	lowpass,
	mix,
	noise,
	output_dir,
	sine,
	soft_clip,
	sweep,
	write,
)


def bomb_blast() -> np.ndarray:
	d = 2.0
	crack = click(d, 0.0, 0.006, 11, 1.0)
	sub = sine(d, sweep(d, 70.0, 22.0, 0.25)) * decay(d, 0.5)
	blast = lowpass(noise(d, 12), 3000.0) * decay(d, 0.12)
	rumble = lowpass(brown(d, 13), 200.0) * decay(d, 0.9, 0.05) * 2.0
	debris = highpass(crackle(d, 25.0, 0.004, 14, 0.15, 0.6), 800.0) * 0.5
	return soft_clip(mix(crack * 0.7, sub * 1.2, blast * 1.0, rumble, debris), 2.0)


def shell_burst() -> np.ndarray:
	d = 0.9
	crack = click(d, 0.0, 0.003, 15, 0.8)
	crump = bandpass(noise(d, 16), 120.0, 1400.0) * decay(d, 0.16)
	thump = sine(d, sweep(d, 140.0, 60.0, 0.06)) * decay(d, 0.12)
	tail = lowpass(noise(d, 17), 400.0) * decay(d, 0.3, 0.05)
	return soft_clip(mix(crack * 0.5, crump * 1.0, thump * 0.8, tail * 0.5), 1.5)


def collapse() -> np.ndarray:
	d = 1.8
	rumble = lowpass(brown(d, 18), 160.0) * decay(d, 0.7) * 2.0
	thud = sine(d, sweep(d, 60.0, 30.0, 0.2)) * decay(d, 0.3)
	bricks = bandpass(crackle(d, 60.0, 0.006, 19, 0.0, 0.7), 300.0, 4000.0) * 0.8
	dust = lowpass(noise(d, 20), 900.0) * decay(d, 0.8, 0.2) * 0.3
	return soft_clip(mix(rumble, thud * 0.9, bricks, dust), 1.6)


def splash() -> np.ndarray:
	d = 1.2
	slap = click(d, 0.0, 0.01, 21, 1.0)
	plunge = sine(d, sweep(d, 420.0, 90.0, 0.08)) * decay(d, 0.1)
	spray = bandpass(noise(d, 22), 500.0, 6000.0) * (decay(d, 0.35, 0.02))
	rain = highpass(crackle(d, 80.0, 0.003, 23, 0.2, 0.4), 2000.0) * 0.4
	wash = lowpass(noise(d, 24), 700.0) * decay(d, 0.5, 0.1) * 0.5
	return soft_clip(mix(slap * 0.8, plunge * 0.7, spray * 1.0, rain, wash), 1.4)


if __name__ == "__main__":
	out = output_dir()
	write(out / "bomb_blast.wav", bomb_blast())
	write(out / "shell_burst.wav", shell_burst())
	write(out / "collapse.wav", collapse())
	write(out / "splash.wav", splash())
