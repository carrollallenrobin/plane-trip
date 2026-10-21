---
status: accepted
---

# The Backdrop is dressing outside the simulation

Everything drawn behind the action, the tree line, hills, clouds, mountains, the ground sheet they stand on and the dressing on the terrain slab, is the Backdrop (`src/game/backdrop/`). It exists so the player can read the plane's movement at any altitude: at the Ceiling the ground is out of view and a plain sky gives the eye nothing to measure against. It is not part of the World. `World.step` never sees it, nothing in it is a Ground Target or a hazard, and no HUD or rule reads it.

A pure `BackdropPlan` lays it out: sparse trees on the back half of the terrain slab at the terrain's height, then five layers at fixed depths behind the action (Near 80 m, Hills 250 m, Clouds 400 m, Mountains 700 m, a Far range at 1400 m), each scattered from a seed with modular pieces, trees, hills, mountains and clouds built as Blender scripts with several variants per model (ADR 0005). Each layer is made wide and tall enough to cover whatever the camera can see at that depth, with the camera clamped to the World's edges, and the Mountains always put one peak at the top of the view at the Ceiling. The Far range is there because a ground sheet ends on screen below the horizon from any height, so the sky's flat ground colour showed between the peaks; a ridge whose lowest dip is above the camera at the Ceiling hides that everywhere, and the test checks the dips. `BackdropNode` renders a plan as one MultiMesh per piece variant per layer and a graded ground sheet, with every colour faded toward the sky's horizon colour by its depth. `TerrainNode` paints the slab itself in field strips from its own seed, with a shore beside the Water; that is the one piece of dressing outside `src/game/backdrop/`, because it is the slab's own vertex colours. The perspective camera does the parallax (ADR 0001). Any motion in the Backdrop, cloud drift, smoke, distant flashes, turning sails, swaying trees, runs in the Backdrop's own process step on the render clock, pauses with the scene tree, and draws its timing from the seeded source, so a given seed always plays the same.

## Considered options

- **Backdrop events in the simulation**: distant artillery as a World event, say. Then a flash that means nothing would sit next to a Shell burst that does, the simulation would carry state that no rule reads, and the deterministic step would pay for dressing. Kept out.
- **Fog for depth**: Environment fog fades far things automatically, but it needs a start distance tuned past the action plane, works differently between renderers, and leaves the Blender previews looking nothing like the game. The flat palette is faded per layer instead, which is the same thing for flat colours and costs nothing.
- **A painted bitmap**, as the original: one picture to draw and no geometry, but no parallax, no cover for a wider window, and a second art pipeline next to the model scripts.
- **Hand-placed scenery in each mission scene**: the most control, but every mission would have to be dressed by hand and kept wide enough for the camera, which nothing would check. A seeded scatter with a coverage test does it once.

## Consequences

- The Backdrop can be rebuilt, reseeded or swapped per mission without touching the simulation or its tests.
- The pieces' built sizes are mirrored in `BackdropPlan.PIECES` so coverage can be computed without loading a model; a change to a piece's size is a change in both places.
- The headless renderer keeps no MultiMesh transforms, so scene tests check instance counts and the transform rule, and the layout itself is tested on the plan.
- Backdrop meshes cast no shadows. A few hundred trees in one MultiMesh cost one draw call; moving each as a node would not.
- Whatever moves in the Backdrop is cosmetic and silent, and is kept visibly unlike the real thing: smaller, farther, slower. Gameplay clouds, if they come, are World objects at the action plane and not part of the Backdrop.
