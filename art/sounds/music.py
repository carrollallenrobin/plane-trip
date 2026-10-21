"""The music (ADR 0009): a dance-band tune on the wireless in the operations hut behind the
title and the mission list, and two short stings for the Debrief, a flourish for a mission
complete and a sombre phrase for one failed. All of it played by art/musickit.py's band and
put through its wireless, so the synthesis hides behind a valve radio.

"Field Orders", 16 bars of medium swing in F.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import numpy as np  # noqa: E402

from musickit import chord, loop_of, render, wireless  # noqa: E402
from soundkit import fade, output_dir, seamless, write  # noqa: E402

TEMPO = 118.0
SWING = 0.3
BARS = 16
BEATS = BARS * 4

# The changes, one chord per bar: (bass notes for beats 1 and 3, guitar voicing).
CHANGES = [
	(("F2", "C3"), ("A3", "C4", "F4")),  # 1  F
	(("D2", "A2"), ("A3", "D4", "F4")),  # 2  Dm
	(("G2", "D3"), ("Bb3", "D4", "G4")),  # 3  Gm
	(("C2", "G2"), ("Bb3", "E4", "G4")),  # 4  C7
	(("F2", "C3"), ("A3", "C4", "F4")),  # 5  F
	(("D2", "A2"), ("A3", "C4", "F#4")),  # 6  D7
	(("G2", "C3"), ("Bb3", "E4", "G4")),  # 7  Gm C7
	(("F2", "C3"), ("A3", "C4", "F4")),  # 8  F
	(("Bb2", "F3"), ("Bb3", "D4", "F4")),  # 9  Bb
	(("Bb2", "F3"), ("Bb3", "Db4", "F4")),  # 10 Bbm
	(("F2", "C3"), ("A3", "C4", "F4")),  # 11 F
	(("D2", "A2"), ("A3", "C4", "F#4")),  # 12 D7
	(("G2", "D3"), ("Bb3", "D4", "G4")),  # 13 Gm
	(("C2", "G2"), ("Bb3", "E4", "G4")),  # 14 C7
	(("F2", "C3"), ("A3", "C4", "F4")),  # 15 F
	(("C2", "Bb2"), ("Bb3", "E4", "G4")),  # 16 C7, turning around
]

# The tune: (note, start beat within the bar, length in beats), per bar. Rests are gaps.
TUNE = [
	[("A4", 0.0, 0.5), ("C5", 0.5, 0.5), ("F5", 1.0, 1.5), ("E5", 2.5, 0.5), ("D5", 3.0, 1.0)],
	[("C5", 0.0, 1.0), ("A4", 1.0, 0.5), ("D5", 1.5, 1.5), ("C5", 3.0, 0.5), ("A4", 3.5, 0.5)],
	[("Bb4", 0.0, 1.5), ("G4", 1.5, 0.5), ("D5", 2.0, 1.0), ("Bb4", 3.0, 1.0)],
	[("C5", 0.0, 0.5), ("Bb4", 0.5, 0.5), ("G4", 1.0, 1.0), ("E4", 2.0, 2.0)],
	[("A4", 0.0, 0.5), ("C5", 0.5, 0.5), ("F5", 1.0, 1.5), ("E5", 2.5, 0.5), ("D5", 3.0, 1.0)],
	[("C5", 0.0, 1.0), ("A4", 1.0, 0.5), ("F#4", 1.5, 1.5), ("A4", 3.0, 0.5), ("C5", 3.5, 0.5)],
	[("D5", 0.0, 1.0), ("Bb4", 1.0, 0.5), ("G4", 1.5, 0.5), ("E4", 2.0, 0.5), ("G4", 2.5, 0.5), ("Bb4", 3.0, 1.0)],
	[("A4", 0.0, 2.5), ("F4", 3.0, 0.5), ("A4", 3.5, 0.5)],
	[("D5", 0.0, 1.0), ("F5", 1.0, 0.5), ("D5", 1.5, 1.0), ("Bb4", 2.5, 1.5)],
	[("Db5", 0.0, 1.0), ("F5", 1.0, 0.5), ("Db5", 1.5, 1.0), ("Bb4", 2.5, 1.5)],
	[("C5", 0.0, 0.5), ("A4", 0.5, 0.5), ("F4", 1.0, 1.0), ("A4", 2.0, 1.0), ("C5", 3.0, 1.0)],
	[("D5", 0.0, 1.5), ("C5", 1.5, 0.5), ("A4", 2.0, 1.0), ("F#4", 3.0, 1.0)],
	[("G4", 0.0, 1.0), ("Bb4", 1.0, 0.5), ("D5", 1.5, 1.5), ("G5", 3.0, 1.0)],
	[("F5", 0.0, 0.5), ("E5", 0.5, 0.5), ("D5", 1.0, 0.5), ("C5", 1.5, 0.5), ("Bb4", 2.0, 1.0), ("G4", 3.0, 1.0)],
	[("A4", 0.0, 1.5), ("F4", 1.5, 0.5), ("C5", 2.0, 2.0)],
	[("A4", 0.0, 0.5), ("G4", 0.5, 0.5), ("E4", 1.0, 1.0), ("G4", 2.0, 0.5), ("Bb4", 2.5, 0.5), ("C5", 3.0, 1.0)],
]

# The horn answers in the bars where the tune rests long.
HORN = {
	3: [("D4", 2.0, 0.5), ("F4", 2.5, 0.5), ("G4", 3.0, 1.0)],
	7: [("F4", 0.0, 2.0), ("E4", 2.0, 1.5)],
	11: [("F4", 3.0, 1.0)],
	14: [("C4", 2.0, 2.0)],
}


def song_events():
	events = []
	for bar, (bass_notes, voicing) in enumerate(CHANGES):
		at = bar * 4.0
		# Bass walks on 1 and 3, with a passing note on 4 into the next bar now and then.
		events.append(("bass", bass_notes[0], at, 1.8, 0.9))
		events.append(("bass", bass_notes[1], at + 2.0, 1.8, 0.8))
		if bar % 4 == 3:
			events.append(("bass", bass_notes[1], at + 3.5, 0.4, 0.6))
		# Guitar comps on the off-beats, lighter on the and of two.
		events += chord("guitar", voicing, at + 0.5, 0.4, 0.5)
		events += chord("guitar", voicing, at + 1.5, 0.3, 0.35)
		events += chord("guitar", voicing, at + 2.5, 0.4, 0.5)
		events += chord("guitar", voicing, at + 3.5, 0.3, 0.35)
		# Brushes: kick on 1 and 3, snare on 2 and 4, hat on every eighth.
		events.append(("kick", "", at, 0.2, 0.5))
		events.append(("kick", "", at + 2.0, 0.2, 0.4))
		events.append(("snare", "", at + 1.0, 0.2, 0.55))
		events.append(("snare", "", at + 3.0, 0.2, 0.55))
		for eighth in range(8):
			events.append(("hat", "", at + eighth * 0.5, 0.1, 0.35 if eighth % 2 else 0.5))
		for note, start, length in TUNE[bar]:
			events.append(("reed", note, at + start, length * 0.9, 0.85))
		for note, start, length in HORN.get(bar, []):
			events.append(("horn", note, at + start, length * 0.9, 0.5))
	return events


def field_orders() -> np.ndarray:
	loop = loop_of(song_events(), TEMPO, BEATS, SWING)
	return seamless(wireless(loop), 0.02, BEATS * 60.0 / TEMPO - 0.02)


def sting_won() -> np.ndarray:
	"""A short flourish: the band rises to a held chord."""
	events = [
		("horn", "C4", 0.0, 0.45, 0.6),
		("horn", "F4", 0.5, 0.45, 0.65),
		("horn", "A4", 1.0, 0.45, 0.7),
		("horn", "C5", 1.5, 2.5, 0.8),
		("reed", "F5", 1.5, 2.5, 0.7),
		("bass", "F2", 1.5, 2.0, 0.9),
		("bass", "F2", 0.0, 1.0, 0.7),
		("snare", "", 1.5, 0.2, 0.6),
		("kick", "", 1.5, 0.2, 0.6),
	] + chord("guitar", ("A3", "C4", "F4"), 1.5, 2.0, 0.6)
	out = render(events, 112.0, 5.0)
	return fade(wireless(out[: int(44100 * 3.2)]), 0.0, 0.6)


def sting_lost() -> np.ndarray:
	"""A sombre fall: the horn down a minor phrase over a low drone."""
	events = [
		("horn", "F4", 0.0, 0.9, 0.55),
		("horn", "E4", 1.0, 0.9, 0.5),
		("horn", "Db4", 2.0, 0.9, 0.5),
		("horn", "C4", 3.0, 2.0, 0.55),
		("bass", "F2", 0.0, 1.5, 0.8),
		("bass", "F2", 2.0, 1.5, 0.7),
		("bass", "C2", 3.0, 2.0, 0.8),
	] + chord("guitar", ("Ab3", "C4", "F4"), 3.0, 2.0, 0.45)
	out = render(events, 72.0, 6.0)
	return fade(wireless(out[: int(44100 * 4.2)]), 0.0, 0.8)


if __name__ == "__main__":
	out = output_dir()
	# The wireless passes nothing above 3.6 kHz, so half the rate loses nothing and halves
	# what the web build downloads.
	write(out / "wireless.wav", field_orders(), 0.9, half_rate=True)
	write(out / "sting_won.wav", sting_won(), 0.85, half_rate=True)
	write(out / "sting_lost.wav", sting_lost(), 0.85, half_rate=True)
