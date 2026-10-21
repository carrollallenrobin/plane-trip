# Plane Trip

A single-player, side-view aerial combat game inspired by Triplane Turmoil. The world is simulated on a 2D plane; the player flies missions, fights, and returns to an airfield to rearm.

## Language

### Combatants

**Side**:
One of the two factions in a mission: Red or Blue. Every plane, airfield and ground target belongs to exactly one side.
_Avoid_: Team, nation, faction, player (the player is one pilot on a side, not the side itself)

**Pilot**:
Whoever is flying a Plane: the player or an AI. A Pilot belongs to a Side and may fly several Planes over a Mission.
_Avoid_: Player (only for the human), bot, enemy

**Plane**:
An aircraft in the World, flown by a Pilot. Every Plane is the same airframe; what one carries is its Loadout.
_Avoid_: Aircraft, ship, triplane, Plane Type (the four named types were replaced by Loadouts on 2026-10-18)

**Loadout**:
What a Plane carries into the air: which Fitting sits in each of its Slots. The player chooses theirs at a Refit; a Mission's author gives the enemy's as data.
_Avoid_: Plane Type, build, kit, configuration

**Interceptor**:
The Loadout preset with no Bomb Racks: Ammunition Boxes, Fuel Tanks and an Armour Plate. A Plane on it can only fight other Planes.
_Avoid_: Fighter (the preset that carries bombs too), pure fighter, gunship

**Wingman**:
An AI-flown Plane on the player's Side, sent up by the Home Airfield's Hangar. It fights like any AI Pilot; a Wingman the player shoots down is nobody's kill.
_Avoid_: Ally, friendly, escort, teammate

**Squadron**:
A Side's AI Planes as its Hangar sends them up: how many it keeps Aloft, the Loadout each slot flies, the pool they are drawn from, and the interval between launches. The enemy has one; the player's Side has one for its Wingmen.
_Avoid_: Wave, spawner, pool (one part of it), team

**Aloft**:
A Squadron's cap on Planes in the air at once. A Plane lost frees its slot, and the replacement flies the same Loadout.
_Avoid_: Concurrent, simultaneous, max planes, wave size

**Slot**:
One of a Plane's fixed number of hardpoints. Empty, or holding one Fitting.
_Avoid_: Hardpoint, pylon, point

**Fitting**:
A kind of thing a Slot can hold: a Bomb Rack, an Ammunition Box, a Fuel Tank or an Armour Plate. Each raises one capacity (bombs, rounds, fuel or hit points; hit points are shown to the player as HULL) and adds weight, which slows the Plane. A Bomb Rack weighs its bombs, so dropping them lightens the Plane; every other Fitting weighs the same full or empty.
_Avoid_: Kit, pack, module, upgrade, item

**Spin**:
The state of a Plane whose hit points were brought to zero by bullets or Debris: it falls with greatly reduced control until it hits something, a runway included. A blast or an impact destroys a Plane outright instead.
_Avoid_: Stall (a flight-model state the Pilot can recover from), tailspin, death spiral

**Blast**:
Damage from a Bomb or a Flak Gun shell. A blast that brings a Plane to zero hit points destroys it outright, including a Plane already in a Spin.
_Avoid_: Explosion damage, splash, area damage

**Debris**:
Pieces thrown off a destroyed Plane or Ground Target. Debris damages Planes it hits.
_Avoid_: Wreckage, particles, shrapnel

### Weapons

**Machine Gun**:
The plane's forward-firing weapon, fed from a finite supply of rounds.
_Avoid_: Gun, cannon, MG

**Bomb**:
A dropped weapon that falls under gravity and detonates on impact.
_Avoid_: Ordnance, payload

### Ground

**Ground Target**:
A destructible object fixed to the terrain, such as a building or an anti-aircraft gun. Belongs to a Side.
_Avoid_: Structure, building (too narrow), prop

**Anti-Aircraft Gun**:
A Ground Target that fires bursts of bullets at enemy Planes, leading its aim.
_Avoid_: AA, AA gun, machine gun nest, turret

**Flak Gun**:
A Ground Target that fires Shells which burst after a set time and damage Planes near the burst.
_Avoid_: Artillery, cannon, AA

**Shell**:
A Flak Gun's round: flies on a fuse and bursts in the air, or on touching a Plane, as a Blast.
_Avoid_: Flak (the gun), bullet, projectile

**Airfield**:
A stretch of ground belonging to a side where a plane can land. Any Plane can land on any Airfield, but only its own Side's Airfield will Rearm it.
_Avoid_: Base, runway, hangar

**Home Airfield**:
The Airfield where the player's Planes start and respawn in a Mission.
_Avoid_: Base, spawn point

**Hangar**:
The Ground Target on an Airfield that produces that Side's AI-flown Planes. Destroying it stops new Planes from appearing there.
_Avoid_: Spawner, factory, barracks

**Rearm**:
Restoring a Plane's fuel, rounds, bombs and hit points to its Loadout's capacities while it is stopped on its own Side's Airfield.
_Avoid_: Refuel, repair, resupply (these are parts of rearming, not the whole)

**Refit**:
The player choosing a Loadout on the ground: at Mission start, at every respawn, and whenever their Plane stops on its own Airfield. Confirming a Refit Rearms the Plane and sets it back at the start of its runway. The Refit screen is where it happens; the World runs on behind it, except at Mission start, where it waits for the first confirm.
_Avoid_: Hangar menu (a Hangar is a Ground Target), rearming screen, shop, loadout screen

### Mission

**Mission**:
A self-contained single-player scenario: one World, a list of Objectives, and a stock of Planes for the player.
_Avoid_: Level, map, stage

**Objective**:
A single condition a Mission tracks: Destroy a target, Protect a target, Return to the Home Airfield, or Shoot Down a number of enemy Planes. Objectives are required or optional. A Protect objective is satisfied while its target stands.
_Avoid_: Goal, task, quest

**Shoot Down**:
The Objective that asks for a number of enemy Planes taken out of the fight by the player's own Machine Gun or Bombs. It is also complete once the enemy is grounded: its Hangar gone or its pool spent, with nothing Aloft. Kills by Wingmen or ground guns do not count.
_Avoid_: Kill count, frag, score, air superiority

**Debrief**:
The screen after a Mission ends, showing the outcome and the objectives, with the choice to fly again or return to the mission list.
_Avoid_: Results, summary, score screen

**World**:
The bounded side-view space a Mission is played in and everything in it as the Mission runs: the World Map, the Ground Targets, the Planes, and the bullets, Bombs, Shells and Debris in the air. One World is simulated as a whole, and the player sees it through its rendering.
_Avoid_: Level, map, arena, scene (the rendering of a World, not the World)

**World Map**:
The fixed part of a World: terrain, Water, Borders, Ceiling and Airfields. Nothing in it moves or can be destroyed.
_Avoid_: Level, layout, map, terrain (one part of it)

**Water**:
A stretch of terrain that destroys any Plane touching it. Not an Airfield, not a Ground Target.
_Avoid_: Sea, lake, hazard

**Border**:
The left and right edges of the World. Touching a Border destroys a Plane.
_Avoid_: Wall, boundary, edge

**Ceiling**:
The top of the World. A Plane above the Ceiling tumbles without control until it falls back under it.
_Avoid_: Top wall, altitude limit

### Picture

**Picture**:
Everything the player sees and hears that is not a World object itself: the drawn Planes, Ground Targets and projectiles, the Backdrop, the effects, the camera's shake and the sounds. One pure module, `Picture`, decides how each World event and each step is felt (what the effects pools get, whose shots and hits shake the view, what is heard from the player's Plane and how loud); the nodes draw and play what it decides. Nothing in it is read by a rule, a Pilot or the Instrument Panel (ADR 0007).
_Avoid_: Visuals, FX, juice, view layer

**Backdrop**:
Everything drawn behind the action that is not part of the World: four layers at increasing depth, Near (a tree line), Hills, Clouds and Mountains, on a ground sheet that runs to the horizon, plus the dressing on the terrain slab. Laid out from a seed to cover whatever the camera can see, faded toward the sky with depth, and animated on the render clock. Nothing in it is simulated and nothing in it informs play (ADR 0006).
_Avoid_: Background, scenery, parallax layers, environment

**Tracer**:
The drawn bullet: a bright streak along its flight with a short fading tail. A Tracer is how a bullet looks, not a thing in the World; the bullet record has no size.
_Avoid_: Bullet (the simulated object), projectile, trail (the Tracer's tail is part of it)

**Muzzle Flash**:
The brief flare drawn at a gun's muzzle when it fires, on Planes and Ground Targets alike. Emissive flat colour, no light.
_Avoid_: Gun flash, flash (alone; the Backdrop has distant flashes that mean nothing)

**Casing**:
A spent cartridge thrown from a Plane's Machine Gun as it fires, drawn toward the camera and gone within two seconds. Picture only; it touches nothing.
_Avoid_: Shell (the Flak Gun's round), brass, particle

**Burst**:
The picture of something exploding: a flash, an expanding sphere and rising puffs, drawn where a Bomb detonates, a Shell bursts, a Ground Target falls or a Plane explodes. The Blast is the damage; the Burst is what you see.
_Avoid_: Explosion (ambiguous between Blast and Burst), particles

**Sway**:
The small roll a Plane shows in the picture, banking into its pitch with a little turbulence on top. Derived from the simulated state, never fed back into it.
_Avoid_: Roll (the simulated half-roll), bank (as a state), wobble

### Screens

**Sheet**:
The paper a menu is laid on: cream, a little tilted, with a shadow and paper grain. Every screen outside flight (title, mission list, Refit, Debrief, pause) is one or more Sheets over the picture behind it, dimmed (ADR 0008).
_Avoid_: Panel, dialog, window, popup

**Instrument Panel**:
What the player reads in flight: a riveted olive plate at the bottom left with dials for fuel, rounds and HULL (hit points) and silhouettes for bombs and planes left, the objective slip pinned top left, and the Band. It reads the World and never writes it; no rule and nothing in the Picture reads it.
_Avoid_: HUD, overlay (the debug overlay is ours, not the player's), status bar

**Stamp**:
The red rubber-stamp mark on a Sheet: a word in a ruled box at an angle. A mission's card carries COMPLETE once it is won; the Debrief's outcome slams down as one.
_Avoid_: Badge, label, banner

**Band**:
The dark olive strip across the screen a mission message is set on in stencil: the outcome for the moments before the Debrief, an objective turning complete or failed in flight.
_Avoid_: Banner, toast, notification, popup
