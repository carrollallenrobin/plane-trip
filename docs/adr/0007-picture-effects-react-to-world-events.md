---
status: accepted
---

# Picture effects react to World events

Tracers, Muzzle Flashes, Casings, impact puffs, Bursts, damage smoke, wingtip ribbons, Sway and camera shake are Picture: they make the World's happenings felt, and none of them is a World object. They are driven in two ways only. One-off happenings come from `WorldEvent`s returned by `World.step`: a gun fired, a bullet landing on ground, Water or a Ground Target, a plane hit, a Bomb released, a Bomb or Shell burst, a target or plane destroyed. Continuous looks come from reading World state after the step: hit points for damage smoke, speed and g-load for the ribbons, the pitch change for Sway. Nothing flows back. The World never reads a node, and no rule, Pilot or HUD reads an effect.

Each event carries what the picture needs to draw it and nothing the rules did not already have: a shot carries its muzzle point, a hit carries its point and the bullet's direction, an impact carries the surface it met. Where the picture needs a fact the rules did not have, such as a release interval between Bombs or a hit's direction, it becomes a rule first, with the knockback it enables, and the event reports it. Effects run on the render clock in their own process step, like the Backdrop (ADR 0006), pause with the tree, and live in pooled MultiMeshes with fixed caps, so a burst of fire costs no node churn. Sway and shake have pure cores, state in and an offset out, so they are tested without a scene; the rest get wiring tests only, since the headless renderer keeps no transforms.

## Considered options

- **Effects as World objects**, Casings and puffs stepped by the simulation like Debris. Debris is there because it wounds; a Casing touches nothing. Stepping it in the World would spend the deterministic step on dressing and give the rules state nothing reads. Kept out, the same call as the Backdrop.
- **Nodes reading each other**, the plane node telling a trail node where it is. Effects would then follow the picture rather than the World, drift on frames the physics tick skipped, and need a node graph to test. Reading World state through the one `WorldNode.step` keeps one source.
- **A visual-only knockback**, nudging the node without moving the plane. The nudge would disagree with where bullets pass and where the hit box is, so it was made a rule.
- **Sprites and textured particles**, the usual way to make fire and smoke. They would be the first image assets and a second art pipeline beside the model scripts, and would sit in front of flat-shaded models. Flat-colour meshes and untextured puffs keep one language.
- **Hit-stop and lights**. Hit-stop stutters at six rounds a second; lights cost on the web target in an unlit flat-colour world. Both left out.

## Consequences

- Adding an effect means a new event or a new read of state, never a new field on a sim object for the picture's sake alone. Render-only fields that already exist on Debris (size, angle, spin) stay the exception that predates this.
- Events grow fields: the muzzle point on a shot, the point and direction on a hit, the surface on an impact. Tests on `World.step` check them like any rule.
- Ground guns firing, Bombs releasing and bullets ending now emit events where they were silent.
- `ExplosionNode` becomes `BurstNode` when the Burst lands, since "explosion" is ambiguous between the Blast and its picture; the placeholder explosion sound keeps its name as the sound of a Blast.
- Effects pools have caps; the oldest instance is reused when a pool is full, so a cap too small shows as short tails, not a crash.
- Casings move in Z toward the camera. That is the one place anything moves off the action plane, allowed because it is Picture (ADR 0001 binds the simulation, not the picture).
- Since 2026-10-18 the reaction itself lives in one pure module, `Picture`. Before, `WorldNode` and `EffectsNode` each matched on the event kind and split the job, and the rules of feel that only `WorldNode` held (only the player's shots and hits shake the view, a hit in a Spin shakes harder, sounds fade with distance from the player's Plane, nothing is heard while it is dead) ran untested, while the shake decayed on the camera's own clock. `Picture.step` now does all of it on the World's clock and returns Cues for the sounds and flashes; `WorldNode` keeps its nodes by the events and plays the Cues; `EffectsNode` only draws the plan.
