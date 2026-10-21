---
status: accepted
---

# Models are Blender scripts exported to glTF

Models, the plane and the Ground Targets alike, are Python scripts in `art/models/` that build geometry with Blender's `bmesh` API from measurements (shared helpers in `art/modelkit.py`) and export it to `assets/models/<name>.glb`. `scripts/build-models.sh` runs them with a headless Blender that `scripts/fetch-blender.sh` downloads and pins (5.0.1), the way `fetch-godot.sh` pins Godot. The `.glb` files are committed, so the game builds and tests run without Blender; the scripts are their source and the `.glb` is never edited by hand. `scripts/preview-model.sh` renders a model to PNG for a look without a GUI. The process is written up in `docs/modelling.md`.

The model's contract with the game is small: the origin is the simulation's position (a plane's centre, the middle of a Ground Target's base), +X is the world's horizontal and +Y is up in Godot's frame, the face on Godot's +Z side is the one the camera sees, a material named `Side` takes the Side's colour, and named nodes mark moving parts (the plane's `Propeller` turns about X). Ground Target models are built at the sizes in `GroundTargetNode.MODEL_SIZES` and scaled to the target. `SideModel` is the one place that instantiates a model and paints it.

## Considered options

- **Hand-modelled `.blend` files**: the natural Blender workflow, but a binary file nobody can review, diff or regenerate, and this project has no artist. Measurements in a script are reviewable and tie directly to the simulation's constants.
- **Meshes built in GDScript at runtime** (the placeholder boxes, or `SurfaceTool`): no external tool, but no way to look at the model outside the game, no path to textures or a later hand-made model, and modelling code in the renderer.
- **Sourced models** (Kenney.nl, Sketchfab): nothing fits a side-view Triplane-style game, and licences and proportions become a concern.

## Consequences

- Blender is a build-time dependency only. On Linux arm64, where blender.org ships no build, `fetch-blender.sh` unpacks Ubuntu's own packages without root; elsewhere it uses official builds.
- A model change is a script change plus a rebuilt `.glb` in the same commit.
- Any later hand-made model only has to honour the contract above; the exporter settings and the Godot side stay the same.
- One model serves all four Plane Types for now. Per-type models are more scripts under `art/models/`.
- A Ground Target's picture is the kind's model stretched to the target's size, so a very wide building looks stretched; a second model for another proportion is another script.
