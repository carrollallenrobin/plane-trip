"""Draws a built sound for a look at it: the waveform over its length and a spectrogram
under it, to one PNG. Run through scripts/preview-sound.sh, which supplies numpy and
matplotlib.

Usage: python art/preview_sound.py assets/audio/engine.wav .tools/preview/engine.png
"""

import sys
import wave

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402


def read(path: str) -> tuple[np.ndarray, int]:
	with wave.open(path, "rb") as source:
		rate = source.getframerate()
		frames = source.readframes(source.getnframes())
	return np.frombuffer(frames, dtype="<i2").astype(np.float64) / 32768.0, rate


def main() -> None:
	source, target = sys.argv[1], sys.argv[2]
	x, rate = read(source)
	t = np.arange(x.size) / rate
	figure, (top, bottom) = plt.subplots(2, 1, figsize=(10, 6), sharex=True)
	top.plot(t, x, linewidth=0.5, color="#3a3a2a")
	top.set_ylim(-1.05, 1.05)
	top.set_ylabel("amplitude")
	top.set_title(f"{source}  ({x.size / rate:.2f} s, peak {np.max(np.abs(x)):.2f}, rms {np.sqrt(np.mean(x * x)):.3f})")
	window = min(1024, x.size)
	bottom.specgram(x, NFFT=window, Fs=rate, noverlap=window // 2, cmap="magma", vmin=-120, vmax=-20)
	bottom.set_yscale("symlog", linthresh=200)
	bottom.set_ylim(20, rate / 2)
	bottom.set_ylabel("Hz")
	bottom.set_xlabel("s")
	figure.tight_layout()
	figure.savefig(target, dpi=100)
	print(f"wrote {target}")


if __name__ == "__main__":
	main()
