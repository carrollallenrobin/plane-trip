---
status: accepted
---

# UI art is fonts, SVG and procedural drawing, outside the model pipeline

The menus and the Instrument Panel (`src/game/ui/`, `src/game/instruments/`) are drawn from three sources and nothing else: open-licensed fonts committed under `assets/fonts/`, hand-written SVG files under `art/ui/` that Godot imports directly, and procedural drawing in code (StyleBoxes, `_draw`, and two small canvas shaders for paper grain and stamp ink). No raster image is painted by hand, no texture is rendered by Blender for the UI, and the one Theme is built in code by `UiTheme` rather than kept as an editor resource. The fonts are fetched by `scripts/fetch-fonts.sh` from a pinned commit of the Google Fonts repository and checked against their sha256, the way Godot and Blender are pinned; the files and their licences are committed so nothing needs the network to build. Allerta Stencil and Oswald are under the SIL Open Font License; Special Elite is under the Apache License 2.0.

This is the UI's exception to ADR 0007, which rejected image assets for effects because they would open a second art pipeline beside the model scripts and sit in front of flat-shaded models. The UI does not share a frame with the models: it is paper and painted metal over the picture, and its shapes, dial faces, silhouettes, are flat and few. SVG is text, so it diffs and reviews like a model script, and Godot rasterises it at import, so there is no build step. Gameplay art, everything that is a thing in the World or the Backdrop, stays model-only under ADR 0005.

## Considered options

- **Procedural only**, every shape drawn in `_draw`. Workable for boxes and needles, but a dial face with twenty ticks and an arc, or a plane silhouette, is clearer as a shape file than as forty lines of drawing code, and the file can be looked at outside the game.
- **Blender-rendered textures**, through the model pipeline. One pipeline, but a render step for what is a few flat shapes, and a raster output nobody can diff.
- **Hand-painted bitmaps**, the usual way. No source to review or regenerate; this project has no artist.
- **An editor Theme resource** (`.tres`). Editable in the inspector, but a large generated text file in which every value is a diff, with the fonts and colours scattered through it. Built in code, the palette is one file and the theme is readable.
- **Godot's default font**, with Unicode symbols for gauges, as before this ADR. The symbols leaned on the default font's fallback coverage, which the web build could lack, and nothing about the look was the game's own.

## Consequences

- `assets/fonts/` and `art/ui/` are the only places image-like assets may live, and `art/ui/` holds only SVG. A new UI shape is a new SVG; a new font is a new line in `fetch-fonts.sh` with its hash and licence.
- Gauges and marks that used to be Unicode glyphs are drawn shapes, so the web build cannot lose them.
- A canvas shader cannot be checked headlessly: the two UI shaders, like the tracer and tree sway shaders, are checked in the real game.
- Colours live in `UiPalette`, type in `UiTheme`; a screen never names a colour or a font size of its own.
- The Instrument Panel keeps the rule the HUD had: it reads the World and the Picture never reads it (ADR 0006, ADR 0007).
