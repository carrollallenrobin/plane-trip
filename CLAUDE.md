# plane-trip

Single-player side-view aerial combat game inspired by Triplane Turmoil. Godot 4.7, GDScript, web-first.

Read before changing anything:
- `CONTEXT.md`: the glossary. Use its terms in code and docs; the `_Avoid_` words are banned.
- `docs/design.md`: settled design decisions and milestones.
- `docs/adr/`: hard-to-reverse architecture decisions.
- `docs/research/triplane-classic-mechanics.md`: how the original worked, with source citations.
- `docs/modelling.md`: how a 3D model is scripted, built, previewed and wired in. Read before touching `art/`.

## Commands

```sh
scripts/test.sh                      # all gdUnit4 suites, headless
scripts/test.sh -a res://test/flight # one directory
scripts/lint.sh                      # gdformat --check + gdlint on project scripts
scripts/lint.sh --fix                # reformat in place, then lint
scripts/import.sh                    # headless resource import (after adding assets)
scripts/build-models.sh [name]       # Blender: art/models/*.py -> assets/models/*.glb, then import
scripts/preview-model.sh plane       # render a built model to .tools/preview/plane.png
scripts/fetch-fonts.sh               # refresh assets/fonts/ from the pinned Google Fonts commit
scripts/build-sounds.sh [family]     # Python: art/sounds/*.py -> assets/audio/*.wav, then import
scripts/preview-sound.sh engine      # draw a built sound's waveform and spectrogram to .tools/preview/engine.png
scripts/build-cover.sh               # Blender: art/cover.py -> promo/cover-*.png, the store-page covers
scripts/play-web.sh [--debug]        # fetch Godot and templates if missing, export and serve the Web build
scripts/export-web.sh [--debug]      # headless import + Web export to build/webgl/ (the "Web" preset)
scripts/serve-web.sh [port]          # serve build/webgl/ with the cross-origin isolation headers
scripts/fetch-export-templates.sh    # install the pinned Web export templates for export-web.sh
```

`scripts/fetch-godot.sh` downloads the pinned Godot build (4.7.2-stable) into `.tools/godot/` on first use. Set `GODOT_BIN` to use an existing install instead. gdtoolkit is installed with `uv tool install gdtoolkit==4.5.0`. `scripts/fetch-blender.sh` does the same for Blender (5.0.1); set `BLENDER_BIN` to use an existing install. The sound scripts run through `uv run` with pinned numpy (and matplotlib for previews), cached under `.tools/uv-cache/`.

## Conventions

- Tests live in `test/`, mirroring `src/`, as `*_test.gd` suites extending `GdUnitTestSuite`.
- Rules are tested through `World.step(dt)` with a map, targets and a mission built in code (`test/sim/world/world_test.gd`); no scene. Headless scene tests only check wiring: frames from `scene_runner` are not tied to the physics clock, so drive time with `WorldNode.step(dt)`. The World keeps its own timers, so nothing needs `simulate_frames`.
- Sounds are Python synthesis scripts in `art/sounds/` sharing `art/soundkit.py`, built to `assets/audio/*.wav` by `scripts/build-sounds.sh` (ADR 0009); the WAV is committed and never edited by hand, and `SoundBank` is the only place one is loaded. Loops must be seamless by construction. Which sounds play, how loud, at what pitch and where is the pure `Picture`'s decision (Cues); `SoundStage` only plays them on pooled 3D voices, and a Plane's engine, airflow and wheels follow the pure `EngineVoice`. Test those rules on the pure classes; scene tests check wiring, since headless Godot plays nothing.
- The airframe, the Fittings and the enemy Loadout presets are data under `data/` (`Airframe`, `Fitting`, `Loadout`); a Plane's capacities and weight come from `PlaneState` methods, never from a field on a type. Tests never load those files: `TestLoadouts` builds the same numbers in code.
- Models are Blender Python scripts in `art/models/` sharing `art/modelkit.py`, exported to `assets/models/*.glb` by `scripts/build-models.sh` (ADR 0005, `docs/modelling.md`). The `.glb` is committed and never edited by hand; change the script and rebuild in the same commit. Flat colours, closed solids, under about a thousand triangles, WW2 era. The material named `Side` takes the Side's colour; `SideModel` instantiates and paints every model.
- The Backdrop (`src/game/backdrop/`, ADR 0006) is everything drawn behind the action: a pure `BackdropPlan` scatters pieces per layer from a seed to cover what the camera can see, `BackdropNode` renders it, `WorldNode` fits it at start. It is outside the simulation: nothing in it is a World object, and nothing in it is read by a rule or the Instrument Panel. Piece sizes in `BackdropPlan.PIECES` mirror the model scripts.
- How the World is felt is one pure module, `Picture` (`src/game/picture.gd`, ADR 0007): `Picture.step(events, planes, shells, dt)` decays the shake, trails smoke, reacts to every `WorldEvent` (effects pools, camera shake for the player's own shots and hits, who hears what and how loud) and returns `Cue`s for what only the scene can do (a sound, a hit flash). `WorldNode` keeps its nodes by the events, calls `Picture.step` once per physics step and plays the Cues; it decides nothing about feel. Test a rule of feel in `test/game/picture_test.gd`, not through the scene.
- The Picture's effects (`src/game/effects/`) follow the Backdrop pattern: a pure `EffectsPlan` keeps capped pools (Muzzle Flashes, Casings, puffs, sparks, Bursts) that the Picture fills, and `EffectsNode` draws each pool as one MultiMesh on the render clock. `CameraShake`, `Sway` and `Ribbon` are pure cores with their own tests; `FollowCamera` and `PlaneNode` apply them. An effect that needs a fact the rules lack gets it through an event, never by reading a node.
- Headless Godot keeps no MultiMesh transforms or instance colours and compiles no shaders: test those on static rules, and check a new shader in the real game.
- The Compatibility renderer compiles each material's shader on its first draw, which freezes the web build for a moment, so the airfield scene primes every pool, the plane's flash and a ribbon for a few frames at loading (`ShaderWarmup`, `warm_up` on `EffectsNode` and `ProjectilesNode`, `AirfieldScene.start_priming`). A new material, shader or pool must be primed there the same way, or its first use will hitch on the web. Never toggle a material feature at runtime: it is another shader program, and Godot frees it again when its last user leaves, so the hit flash is an emission colour (black to white) on materials that always have emission on (`SideModel`). For the same reason the airfield scene behind the title is never freed, only put to sleep behind a mission (`AirfieldScene.sleep`), with the primed pools kept hidden on it: its materials are what keep every configuration's shader alive between missions. Never `free()` a scene whose materials may be the last users of a shader before the next scene exists. Every scene shares the one Sky in `data/sky.tres` through `data/environment.tres`, so the browser renders its radiance once.
- The UI (ADR 0008) is paper and instruments: menus are `MenuScreen`s laid on a `Sheet` (`src/game/ui/`), flight has the `InstrumentPanel` (`src/game/instruments/`). Colours come only from `UiPalette`, type and StyleBoxes only from `UiTheme`, which builds the one Theme in code; a screen never names a colour or a font size. UI shapes are hand-written SVGs under `art/ui/`, fonts under `assets/fonts/` fetched by `scripts/fetch-fonts.sh` (pinned, checksummed, committed); nothing else image-like goes in the repo, and gameplay art stays model-only. The one exception is `promo/`: the store-page covers, rendered from the built models by `art/cover.py` through `scripts/build-cover.sh` and committed like a `.glb`, never edited by hand; the pitch and how-to-play text for the store page live in `promo/README.md`. Godot ignores the folder (`.gdignore`), so nothing in it is imported or exported. Pure parts (`Needle`, `ObjectiveWatch`, `MissionText`, `Plate.rivet_points`) have tests; the rest is wiring. The `Game` node runs while paused so the menus work, so anything that must stop with the pause is made `PROCESS_MODE_PAUSABLE` explicitly, as the mission scene is.
- A mission is a scene under `missions/` whose root is a `WorldNode` with a `MissionDefinition` resource; `main.tscn` lists missions through `MissionEntry` resources. Objectives name `GroundTargetNode`s by node name.
- The debug overlay is hidden until F3.
- gdUnit4's runner stops at the first failure unless given `--continue`; `scripts/test.sh` passes it.
- Simulation logic is pure GDScript with no nodes: inputs and a time step in, new state out. `World` is the whole simulation of a mission (planes, projectiles, guns, spawns, outcome); `World.step(dt)` returns `WorldEvent`s for one-off happenings, and continuous state is read from its fields. `WorldNode` and `PlaneNode` only render it and feed it input; they decide nothing.
- Simulation code never reads or writes Z. The world is 2D; rendering is 3D (ADR 0001).
- The world's Y points up. Godot's `Vector2.UP` is (0, -1) and `Vector2.DOWN` is (0, 1), from its Y-down 2D convention, so never use them in simulation code or tests; write `Vector2(0.0, 1.0)` and `Vector2(0.0, -1.0)`.
- Godot 4 has a built-in global `rotate_toward` in radians; our degree helper is `turn_angle_toward`. Do not name functions after built-ins.
- Tabs for indentation, as gdformat enforces. Run `scripts/lint.sh` before committing.
- `addons/gdUnit4` is vendored and never edited by hand.
- CI is `.github/workflows/deploy.yml`: lint and tests, then the Web export through `scripts/export-web.sh`, then GitHub Pages, on every push to `main`. The Godot version is pinned there too; bump it with `scripts/fetch-godot.sh`. `export_presets.cfg` holds the one "Web" preset, threads on. Pages cannot send the cross-origin isolation headers, so the preset is a progressive web app and its service worker adds them. Tests, the test framework, model and sound scripts and reports are excluded from the export.
- The web build is slow at exactly one thing: compiling shader programs, one per material key per variant, on the main thread. So the game opens on a loading Sheet (`LoadingScreen`, `Game._load`) that builds the airfield scene and primes every effect pool on it before the title, keep the number of distinct material configurations down (a new effect reuses an existing material's features where it can, see `EffectsNode` and the ribbons), give any extra viewport the same sky-lit environment as the World, and the sun casts no shadows on the web (`WebTuning`).
