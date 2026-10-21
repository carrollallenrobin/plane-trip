# Modelling: how a model gets into the game

Every 3D model in the game is a Python script in `art/models/` that builds geometry with Blender's `bmesh` API and exports it to `assets/models/<name>.glb` (ADR 0005). The script is the source; the `.glb` is a build product that is committed so the game and the tests never need Blender. This is the whole process, from idea to commit.

## The loop

1. **Write or edit the script** in `art/models/<name>.py`. Start from an existing one; `plane.py` is the richest, `building.py` the simplest.
2. **Build it**: `scripts/build-models.sh <name>` runs headless Blender and then the Godot import. The first run fetches Blender into `.tools/blender/` (see `scripts/fetch-blender.sh`; set `BLENDER_BIN` to use your own).
3. **Look at it**: `scripts/preview-model.sh <name>` renders `.tools/preview/<name>.png` (three-quarter view) and `<name>-side.png` (the game's view) with Cycles on the CPU, on a green ground plane, in a few seconds. Open the PNGs; an agent can read them directly. `scripts/preview-model.sh <name> <object>` renders one named object of a model that has several.
4. **Adjust the measurements** and go round again. Most changes are a number in the constants at the top of the script.
5. **Wire it up** in the node that shows it (below), run `scripts/test.sh -a res://test/game` and `scripts/lint.sh`.
6. **Commit the script and the `.glb` together**, with the `.glb.import` file Godot writes next to it. Never edit a `.glb` by hand.

## The frame

In Blender, X is the world's horizontal (a plane's nose points +X), Y is depth and Z is up. One unit is one metre. The glTF exporter turns that into Godot's frame: X stays, Z becomes +Y, Y becomes -Z. The game's camera looks along Godot's -Z, so the face a model shows on its Blender **-Y** side is the one the player sees. Put doors, windows and markings there.

The origin is what the simulation calls the object's position:

- A plane: the simulation's plane position. Its length is `FlightModel.HIT_BOX_LENGTH` and its wheels hang `FlightModel.WHEEL_OFFSET` below the origin, so a parked plane sits on the runway.
- A Ground Target: the centre of its base on the ground. The model is built at the size in `GroundTargetNode.MODEL_SIZES` and the node scales it to the target's `width` and `height`: buildings stretch in X and Y, guns scale uniformly to height so they keep their shape, the ruin stretches in X only. Keep the model's footprint inside that nominal width so the hit box and the picture agree.

## The kit

`art/modelkit.py` holds what the scripts share. A `Builder` collects closed solids into one mesh:

| Call | Makes |
| --- | --- |
| `loft(rings, material)` | skins consecutive rings of equal point count: fuselages, wings, cones (a ring may be a single point) |
| `box`, `block` | an axis-aligned box; a box turned about Z and Y, for rubble |
| `cylinder(start, end, radius, …, end_radius)` | barrels, wheels, poles; a frustum with `end_radius` |
| `strut(start, end, …)` | a slender box between two points |
| `plate(outline, thickness, …, plane, offset)` | a flat polygon extruded about the XZ plane (a wall, a flag) or the XY plane (a floor) |
| `prism(outline, start, end)` | an XZ polygon extruded along Y: walls with a gable, an arched hangar |
| `ring(centre, outer, inner, bottom, top)` | a hollow polygonal wall, for sandbags |
| `mound(levels, material, …, wobble)` | a faceted hill or peak from elliptical rings `(z, rx, ry)`, the last a point; `wobble` roughens the outline |
| `to_object(name, origin)` | finishes the mesh as one Blender object |

Every solid is closed, so `to_object` can make all normals point outwards; do not build open sheets. `materials({name: (r, g, b)})` declares the colours a script uses; `run(build)` is the entry point that reads the output path after `--`.

Several objects per model are fine. The plane has `Airframe` and `Propeller`, the propeller with its origin on the hub so `PlaneNode` can spin it about X; `SideModel.part(name)` finds such a node.

A Backdrop piece (`tree.py`, `hill.py`, `mountain.py`, `cloud.py`) is one model with two or three variants as separate named objects, all standing on the origin; `BackdropNode` picks a variant's mesh by name and draws every placement of it in one MultiMesh. Their built sizes are mirrored in `BackdropPlan.PIECES`. A Backdrop feature (`windmill.py`, `factory.py`) is placed whole, like a Ground Target, with its size and any moving part or chimney top in `BackdropPlan.FEATURES`. The variants overlap in a plain preview, so look at one at a time: `scripts/preview-model.sh tree TreeA`. Backdrop colours are faded toward the sky by depth in the game, so write them as they would look up close.

## Colour and the Side

Everything is flat colour, no textures: one material per colour, `face.smooth = False`. Write a colour as it should look, the way a Godot `Color` is written; the kit converts it to Blender's linear Base Color, so the preview, the game and the number agree. Chunky octagons and six-sided barrels are the style; keep a model under about a thousand triangles.

The material named `Side` (`modelkit.SIDE`) is painted in the Side's colour by the game: the plane's fuselage and wings, a hangar's doors, a building's flag, a gun's pennant. Everything else keeps the colour written in the script. Give every model one clearly visible `Side` part so Red and Blue read at a glance, and give each kind of thing its own palette so they are told apart from across the screen: brick and slate for buildings, olive sheet for hangars, gunmetal in sandbags for guns, charred black and broken brick for a ruin. A ruin has no `Side` material; it belongs to nobody.

The era is the Second World War: gable-roofed brick depots, arched corrugated hangars with sliding doors, quad light anti-aircraft guns and heavy flak guns on cruciform carriages in sandbag rings, windsocks and pennants. The plane itself is the triplane of the original game.

## Showing a model

`SideModel.create(packed_scene, side)` instantiates a built model, gives the instance its own copies of the materials, and paints the `Side` material. It offers `paint(side)`, `set_flashing(bool)` for the hit flash and `part(name)`. `PlaneNode` and `GroundTargetNode` are the two users; a new kind of thing gets a `preload` of its `.glb` and a `SideModel`.

Tests for a model live in the node's test suite under `test/game/` and only check wiring: the meshes are there, the `Side` material has the Side's colour, the scale matches the target's size, moving parts move. What the model looks like is checked by eye in the preview.
