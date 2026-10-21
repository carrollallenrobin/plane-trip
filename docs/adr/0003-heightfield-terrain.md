---
status: accepted
---

# Terrain is a heightfield with no overhangs

Terrain is defined as one ground height per horizontal position, with segments markable as water. There are no overhangs, caves or tunnels. The original used a palette bitmap in which any pixel could be solid, so this is a deliberate narrowing.

## Considered options

- **Arbitrary polygons**: would allow overhangs and caves, but ground collision, AI terrain lookahead, landing checks and level authoring all become harder, and the original's missions never relied on such terrain.

## Consequences

- Ground collision, landing checks and AI lookahead reduce to sampling a height at an X position.
- Levels are authored as an editable curve in the Godot editor; a tool script rebuilds the terrain mesh live.
- Overhangs would be a new game feature and a reversal of this decision, not an extension.
