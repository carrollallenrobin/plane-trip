---
status: superseded by ADR-0004
---

# Re-express the original flight model in floats at a fixed 60 Hz tick

Triplane Classic (the open-sourced original) runs an integer fixed-point model at 24 ticks per second: a scalar speed along the nose, gravity that only changes that scalar, stall below a speed threshold, dead controls below a lower one. We keep that model and its tuning knobs (power, agility, mass, drag, stall thresholds) but re-express it in floats, in metres and seconds, stepped at Godot's fixed 60 Hz physics tick. Vectors are used where they simplify the maths, but the behaviour is meant to match the original closely before any tuning. Findings from the original source are in `docs/research/triplane-classic-mechanics.md`.

## Considered options

- **Literal port**: same integers and 24 Hz tick, scaled to the new world. Guarantees the feel but gives unreadable constants and a visibly stepped motion.
- **New force-based vector model**: lift and drag as forces on a 2D velocity. Cleaner physics, but the most likely to feel like a different game, and it loses the knobs the original was tuned with.

## Consequences

- Constants in the flight model are derived from the original and documented against it, so a reviewer can check the conversion rather than guess.
- The flight model is a pure class with no nodes: inputs and a time step in, new state out. It is unit tested with gdUnit4, so tuning can be checked by test, not only by feel.
- Any later departure from the original behaviour is a deliberate tuning change and should be recorded as such.
