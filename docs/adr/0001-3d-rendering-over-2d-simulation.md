---
status: accepted
---

# Render in 3D, simulate in 2D

The game is a side-view flyer like Triplane Turmoil, which would normally mean a Node2D scene with sprites. We render in a 3D scene instead, with every gameplay quantity (position, velocity, heading) kept as 2D values on the XY plane and Z fixed at zero. The roll that flips a plane is then a real model rotation rather than a mirrored sprite, and a far, narrow perspective camera gives background parallax for free.

## Considered options

- **2D scene with sprites**: faithful and simple, but the roll needs mirrored or hand-drawn flip frames, and parallax has to be built by hand.
- **Full 3D simulation**: would be a different game; the original's feel comes from a strictly planar fight.

## Consequences

- Camera, lighting and terrain become 3D work. Terrain is a heightfield polyline extruded into a mesh at load.
- Placeholder art is boxes, not rectangles. Kenney.nl has no 3D propeller-plane kit, so plane models are hand-built or sourced elsewhere.
- Simulation code must never read or write Z. Flight model, AI and mission rules take and return 2D values only.
- Debris was first rigid bodies locked to the XY plane. Since 2026-10-18 it is simulated like the projectiles and only drawn by the scene, so that every damage rule runs inside the deterministic step and can be tested without physics.
