# Triplane Turmoil / Triplane Classic: original game mechanics

Research notes based on reading the GPLv3 source of **Triplane Classic** (the SDL
port of Triplane Turmoil, 1996, Dodekaedron Software Creations Oy).

- Repository: https://github.com/suomipelit/triplane (verified; cloned to
  `/tmp/triplane`, commit `aeff311`, 2020-11-19). Licence: GPL-3.0-or-later
  (`COPYING`, `README.md`).
- Line numbers below refer to that commit. Main files:
  `src/world/plane.cpp` (flight model), `src/world/constants.h`,
  `src/world/fobjects.cpp` (bullets, bombs, debris), `src/world/tripai.cpp`
  (AI pilots, AA guns, infantry, hangar mechanic), `src/world/tripmis.cpp` +
  `src/world/tmexept.cpp` (missions), `src/triplane.cpp` (main loop,
  collisions, hangar, landing), `src/world/terrain.cpp` (rendering/camera),
  `doc/triplane.6` (manual page).

## Summary

- **Fixed 24 Hz simulation.** Everything is integer fixed point: positions in
  1/256 px, angles in 1/256 degree (0 = right, 90 = up), one physics tick per
  frame at 24 fps (`nopeuskontrolli(int fps = 24)`, `src/io/timing.h:24`;
  loop in `src/triplane.cpp:1667-1870`). Bullets and bombs are stepped twice
  per frame.
- **Plane-vs-plane collision:** pixel-mask test; if enabled, *both* planes are
  destroyed instantly and each loses one point. It is **disabled in solo
  missions** (planes pass through each other) and off by default in
  multiplayer (`config.nocollision = 0`), where it is a menu option.
  Debris ("flying parts") from a destroyed plane does damage planes, and is
  always on in solo.
- **Throttle is binary hold-to-thrust** (engine on while key held). No ramp-up,
  no throttle levels. Two config variants exist: on/off toggle mode and
  reversed mode. Thrust per tick = `(power<<8)/mass`; drag = `speed/50` per
  tick; fuel burns 1 unit per powered tick.
- **Flight model:** speed is a scalar along the nose; gravity acts only as a
  speed gain/loss proportional to nose pitch (`mass/32000` scaled); below
  `1000+mass` (power on) or `1500+mass` (power off) the plane sinks; below
  speed 768 it stalls (nose forced down 4 deg/tick, controls dead below 512).
  Turn rate = `(manover*5<<8)/(mass+200)` per tick, roughly 4-5.5 deg/tick
  (96-131 deg/s); turning costs speed. "Roll" is a half-roll completed in 3
  ticks that flips the sprite and swaps up/down controls; you must be in the
  correct roll state to land when facing left.
- **Resources (per nation):** mass 180-275, endurance = mass/8 (22-34 HP),
  fuel 1400-2047 ticks (58-85 s of engine), 80-127 rounds, 3-6 bombs. Bullet
  hit = 0-11 damage (0-5 from infantry / AA MG), debris 0-7, flak 80 (direct)
  or `40-distance`, bomb direct hit = instant kill. At 0 HP the plane either
  explodes immediately or enters an uncontrollable spin to the ground (random).
- **Landing:** no speed check at all. A plane is "on an airfield" whenever its
  wheel point is at/below runway height inside the runway x-range *and* its
  pitch is within a narrow cone (nose up <= 20 deg, nose down <= 10 deg) in
  the correct roll orientation. Outside the cone, touching any non-sky pixel
  destroys the plane. You can land on **any** airfield, but only your own
  hangar services you: stop (speed 0), press roll/bomb, a mechanic pushes you
  into the hangar, a menu lets you pick bombs/ammo/fuel, and on exit the plane
  is fully repaired (endurance reset) instantly and pushed back out.
- **Missions:** 4 nations x 6 missions hard-coded in C++ (`tripmis.cpp`,
  `tmexept.cpp`), levels are 2872-byte binary structs + a 2400x200 palette
  bitmap. Win = all "Dest" targets destroyed AND all enemy planes used up,
  then stop on a runway. Lose = your plane pool exhausted or any "Survi"
  (protect) target destroyed. Lives = `number_of_planes` per mission
  (0-7 extra planes). Ground objects: buildings (houses, factories, tents,
  barracks, stores, water tower, vehicles), infantry, AA machine guns,
  flak (AAA) guns, flags, hangars. No ships or tanks.
- **World:** 320x200 VGA, level is exactly 2400x200 px (15 screens wide, one
  screen tall). Horizontal scroll only, camera centred on the player and
  clamped to the level. Side edges and the ground are lethal; the top edge
  throws the plane into a short forced spin. Terrain is the bitmap itself:
  palette indices 112-119 are sky, 224-231 water, anything else is solid.
- **Kenney.nl:** no 3D plane/aircraft kit exists. The only "plane" assets are
  2D (Tappy Plane, Pixel Shmup). Nearest CC0 3D kits: Space Kit, Pirate Kit,
  Toy Car Kit, Car/Train/Watercraft Kits, Blaster Kit. All Kenney assets are
  CC0.

---

## 1. Plane-to-plane collision

Source: `detect_collision()` in `src/triplane.cpp:1221-1378`.

- Every present plane has a 20x20 px sprite mask (`plane_p[plane][angle/6][rolling][upsidedown]`,
  255 = transparent). For each pair whose 20x20 boxes overlap (`:1253`), the
  overlap region is scanned pixel by pixel and a collision is declared if
  both masks are opaque at the same pixel (`:1274-1277`).
- If `collision_detect` is set, **both planes are destroyed immediately**
  (`in_closing = 2`, `plane_present = 0`, `start_parts()` spawns debris),
  each is charged a self-kill (`player_shots_down[l][l]++`) and loses one
  point (`player_points[l]--`) (`:1278-1298`). There is no damage transfer or
  partial damage; it is all-or-nothing.
- `collision_detect` is **forced to 0 in solo missions** and taken from
  `config.nocollision` in multiplayer (`src/triplane.cpp:1461-1467`), whose
  default is 0 (`src/settings.cpp:505`). So by default planes fly through
  each other; the manual's "Collisions on?" option turns it on
  (`doc/triplane.6`: "a collision of two planes results in an immediate
  destruction of both planes. Both players lose one point").
- **Debris collisions** (`part_collision_detect`): the explosion parts of a
  destroyed plane (`start_parts`, `fobjects.cpp:499-530`, up to 30 parts with
  `hit_plane = 1`) damage any plane whose mask they touch by `wrandom(8)`
  (`FOBJECTS_DAMAGE 8`, `fobjects.cpp:265-294`). Forced on in solo
  (`triplane.cpp:1463`), optional in multiplayer. The manual warns: "Avoid
  shooting too many bullets at the enemy plane, because it will probably
  explode. In the solo game you cannot deactivate the part collision."

## 2. Throttle / power control

Source: `controls()` in `src/triplane.cpp:1145-1173`, `model_planes()` in
`src/world/plane.cpp:323-326`.

- Default: **hold-to-thrust**. `new_mc_power = is_key(power)` each frame
  (`triplane.cpp:1147-1150`); `controls_power` is a 0/1 flag.
- Option "on/off power" (`config.poweronoff`): the key becomes a **toggle**
  (edge-detected via `controls_power2`, `:1157-1173`); killed when the plane
  is destroyed.
- Option "reversed power" (`config.powerrev`): engine on when key *not* held
  (`:1151-1156`).
- There is **no multi-level throttle and no ramp-up**. When power is on and
  fuel > 0, per tick:
  `speed += (plane_power << 8) / mass; gas -= 1` (`plane.cpp:323-326`).
  Drag is applied every tick regardless: `speed -= speed / 50` (`:328`).
  So terminal level speed is about `50 * 256 * power / mass`
  (Germany ~3800, Finland ~5200, England ~3600, Japan ~3450 speed units).
- The engine is also cut by the game when the mechanic is pushing the plane
  (`triplane.cpp:1728-1760`), and the AI switches power off when diving
  steeply (angle 225-315 deg, `tripai.cpp:1285-1288`).
- HUD shows a power-on/off lamp only (`terrain.cpp:583-586`).

## 3. Flight model

Source: `model_planes()` in `src/world/plane.cpp:198-411`; constants in
`src/world/constants.h` and the top of `plane.cpp`. Units: positions in
1/256 px (`player_x >> 8` = pixels), angles in 1/256 degree
(`360 << 8 = 92160`), `sinit/cosinit` tables are 256-scaled integers
(`data/misc/trigdata.dta`: sin(90) = 255, cos(0) = 256). Angle 0 = flying
right, 90 = straight up, 180 = flying left, 270 = straight down.

**Tick rate.** 24 fps, one `model_planes()` per frame (`triplane.cpp:1765`,
`io/timing.h:24`). `do_shots()` and `do_bombs()` run twice per frame
(`triplane.cpp:1719-1720, 1766-1767`).

**Mass** (`plane.cpp:221-229`), recomputed every tick:
`mass = plane_mass + ammo/10 + bombs*12 (bombs*10 for the 6-bomb Japanese
plane) + gas/160`. Germany fully loaded: 200 + 9 + 48 + 10 = 267.

**Thrust / drag** (`:323-328`): see section 2.

**Gravity** acts on the scalar speed according to pitch (`:314-321`):
- nose below horizon (angle 180-360): `speed += ((90<<8) - |angle - 270<<8|) * mass / 32000`
  (straight down with mass 267: +192 units/tick)
- nose above horizon (0-180): `speed -= ((90<<8) - |angle - 90<<8|) * mass / 32000`
  (straight up: -192 units/tick)
Not applied while on an airfield.

**Lift / sink** (`:235-245`), applied to the y position directly:
- power on and `speed < 1000 + mass`: `y += (1000 - speed + mass) >> 3`
- power off and `speed < 1500 + mass`: `y += (1350 - speed + mass) >> 3`
  (y grows downward; note the second formula gives slight *lift* between
  `1350+mass` and `1500+mass`, a quirk of the original).
Above these speeds the plane flies exactly along its nose vector.

**Velocity integration** (`:373-377`):
`x_speed = cos(angle) * speed / 4; x += x_speed >> 8` so a plane moves
`speed/1024` px per tick along its nose: speed 2000 = 1.95 px/tick = 47 px/s;
top speed ~3800 (Germany) = 89 px/s; Finland ~5200 = 122 px/s. Crossing the
2400 px level takes 20-50 s.

**Stall** (`:249-283`): if `speed < 768` (or spinning) and not on an airfield:
turn authority = 0, nose is forced toward straight-down by 1024 (4 deg) per
tick, and `y += 256` (1 px/tick extra sink). Below `speed < 512` the up/down
controls are ignored entirely (`:304-308`). Recovery is simply regaining
speed in the dive. The manual recommends stalling as an emergency brake.

**Turn rate** (`:247, 281, 330-335`):
`initial_turn = (plane_manover << 8) / (mass + 200)` in 1/256 deg per tick,
where `plane_manover = NATION_MANOVER * PLANE_TURN_SPEED(5)`. Examples with
full load: Germany (475) 5.1 deg/tick = 122 deg/s; Japan (500, lighter)
5.5 deg/tick = 131 deg/s; England (450) 4.6 deg/tick; Finland (425, heavy)
4.0 deg/tick = 96 deg/s. At very high speed it is divided by
`1 + ((speed-768)/20 >> 8)` (only matters above speed ~5900, so practically
never). Turning costs speed: `speed -= initial_turn / 100` per tick while
either up or down is held (`:291-302`).

**Air brake**: holding up and down together cancels the rotation but still
applies the turn speed penalty, so the plane decelerates (`:291-302, 331-334`;
manual: "Holding up and down simultaneously activates the air brake").

**Roll / upside down** (`triplane.cpp:1051-1098`, `plane.cpp:210-214`):
pressing roll in the air sets `player_rolling = 1`; the counter advances
once per frame and at 4 (3 frames later) `player_upsidedown` toggles and
rolling resets. Effects:
- up/down controls are swapped while upside down (`plane.cpp:210-214`);
- a different sprite/mask set is used (`planes[..][..][rolling][upsidedown]`);
- bomb release point moves to the other side of the fuselage
  (`fobjects.cpp:574-575`: offset `9 - upsidedown*18`);
- wheel position flips (`yyy = -5` when upside down, `plane.cpp:380-387`,
  `triplane.cpp:739-746`), which is what makes landing orientation matter
  (section 5). Because the sprite is simply mirrored, a plane at angle 180
  with `upsidedown = 1` *looks* right-side-up flying left. The AI rolls to
  keep wheels down relative to its direction of flight
  (`tripai.cpp:1646-1648`), and the joystick "autoroll" does the same for
  humans (`triplane.cpp:1113-1120`).
- Spinning (dying) planes are forced to roll continuously (`triplane.cpp:1202-1213`).

**Ceiling**: `player_y < 0` triggers `spinning_remaining = 30..109` ticks of
forced spin with controls disabled and `y += 768` push-back
(`plane.cpp:231-233, 249-261`).

**Smoke** (`fobjects.cpp:485-497`): each tick, if `wrandom(mass/16) >= endurance`
and a coin flip, the plane emits smoke, so damaged planes smoke more.

## 4. Per-plane resources and damage

Source: `src/world/plane.cpp:110-193` (tables), `src/world/constants.h:93-105`,
`src/triplane.cpp:608, 907` (endurance), `src/world/fobjects.cpp` (damage).

| Nation (colour) | power | manover | base mass | bombs | fuel | ammo | endurance (mass>>3) |
|---|---|---|---|---|---|---|---|
| Germany (red) | 80 | 475 | 200 | 4 | 1600 | 96 | 25 |
| Finland (blue) | 135 | 425 | 275 | 3 | 1800 | 96 | 34 |
| England (green) | 80 | 450 | 200 | 5 | 2047 | 127 | 25 |
| Japan (yellow) | 69 | 500 | 180 | 6 | 1400 | 80 | 22 |
| Neutral AI (grey, slots 12-14) | 120 | 500 | 200 | 4 | 1800 | 96 | 25 |
| "Black" (slot 15) | 135 | 500 | 180 | 6 | 2047 | 127 | 22 |

Slots 0-3 are the four nations, 4-7 and 8-11 are second/third AI planes of
the same nations (same stats). The manual's star table matches these
(`doc/triplane.6` "PLANE TYPES"). Multiplayer option "all planes are" copies
one nation's stats to everyone (`triplane.cpp:3442-3450`).

- **Fuel** (`player_gas`, 0-2047, "one HUD line = 256 units"): decremented by
  1 per tick while the engine is on (`plane.cpp:325`), so full tanks last
  58 s (Japan) to 85 s (England) of engine time. Fuel also adds `gas/160` to
  mass. Out of fuel = glider.
- **Ammo** (`player_ammo`, 0-128, HUD shows 16-round "big" icons): 1 round per
  shot (`fobjects.cpp:224`). Fire rate: one shot when `player_last_shot > SHOTS_RATE(3)`,
  i.e. every 4 frames = 6 rounds/s (`triplane.cpp:1077`). Bullet speed =
  `plane speed + 4000` with gravity 400 per step, lifetime 55 steps
  (~1.1 s, ~160 px range) (`constants.h:52-56`, `fobjects.cpp:123-140`).
  Bullets spawn 12 px ahead of the nose and die on any non-sky pixel.
- **Bombs** (`player_bombs`, 0-6): released with the plane's velocity from a
  point 9 px below the fuselage; gravity 2000 per step, two steps per frame
  (`fobjects.cpp:555-590`). Bombs cannot be dropped while on an airfield
  (`triplane.cpp:1032`). Impact box: AA gun 25x35 px, structure = sprite box
  +-5 px vertically, infantry 74x50 px (`fobjects.cpp:727-849`). Bombs do
  not produce shrapnel (the `palasia` branch is dead code, `:856`).
- **Endurance / HP** (`player_endurance = plane_mass >> 3`), reset on every
  launch from the hangar (`triplane.cpp:608, 907`). Damage sources:
  - plane machine gun: `wrandom(12)` = 0-11 per hit (`fobjects.cpp:157`);
  - infantry rifle and AA machine gun (owner -1): `wrandom(6)` = 0-5 (`:159`);
  - flying debris: `wrandom(8)` = 0-7 (`:273`);
  - flak (ITGUN) shell burst: 80 if within 10 px, else `40 - distance` for
    distance < 40 px (`tripai.cpp:624-638` via `cause_damage`);
  - bomb touching a plane: `endurance = 0`, instant kill (`fobjects.cpp:650`);
  - terrain / water / level edge: instant kill (`triplane.cpp:1307-1376`);
  - plane-plane collision (if enabled): instant kill of both.
- **Death**: when endurance < 1 the plane either explodes on the spot
  (`in_closing = 2`, debris) or, if airborne, enters an uncontrollable spin
  until it hits the ground: 75% spin for bullets (`wrandom(4)`,
  `fobjects.cpp:174`), 50% for debris/flak (`:283`, `triplane.cpp:677`).
  Credit: +1 point to the shooter for an enemy, -1 for an ally
  (`fobjects.cpp:163-172`); crashing into terrain costs the pilot 1 point
  unless already spinning (`triplane.cpp:1319-1322`).
- **Multiplayer cheats**: `unlimited_ammo` / `unlimited_gas` clamp ammo/gas to
  >= 1 (`plane.cpp:398-406`); never in solo.

## 5. Landing, hangar, rearming and repair

Source: `airfield_checks()` `src/triplane.cpp:729-778`; ground handling in
`src/world/plane.cpp:249-279, 310-312, 342-393`; hangar request
`src/triplane.cpp:1030-1069`; mechanic `do_mekan()` `src/world/tripai.cpp:133-491`;
hangar menu `hangarmenu_handle()` `src/triplane.cpp:473-611`;
`init_player()` `:780-913`; level airfields `src/triplane.h:213-227`.

**Airfields**: up to 4 per level (`airfield_x/y/lenght/plane_direction`), one per
nation slot; the runway surface is at `airfield_y`, the usable length is
shortened by 4 px at each end on load (`triplane.cpp:3095-3100`). A hangar
structure ("HANGAR") inside the runway span becomes that nation's hangar
(`:3273-3298`).

**Being "on an airfield"** is evaluated every frame (`:729-778`). Conditions:
1. plane x inside `[airfield_x, airfield_x + length]`;
2. wheel point (5 px below/behind the centre, rotated by the plane angle, flipped
   if upside down) at or below `airfield_y - 1`;
3. pitch within the landing cone **in the matching roll state**:
   - flying right, not upside down: angle <= 20 deg (`TAIL_HIT_ANGLE`) or
     >= 350 deg (`360 - HIT_ANGLE`);
   - flying left, upside down flag set: angle in [166, 196] deg.
   A left-flying plane that has not rolled (wheels up) is *not* on the
   airfield and will crash.
There is **no speed or sink-rate check**: a steep, fast touchdown inside the
cone is a perfectly good landing. If the cone test fails and any non-sky pixel
is touched by the nose or wheel point, the plane is destroyed
(`detect_collision`, `:1307-1376`). Any of the four airfields qualifies, so
you *can* land on enemy or neutral airfields (and the AA guns there will keep
shooting).

**Ground roll** (`plane.cpp:262-279, 342-393`): when on an airfield and
`speed < 768` the game snaps the plane into ground mode: pitch is pulled to
the tail-down rest angle (20 deg or 166 deg) scaled by speed, `y` is pulled
down 2 px/tick and then clamped so the wheel sits on `airfield_y`. Below
`STOP_SPEED_LIMIT` (16) with no power the speed is zeroed (`:310-312`). Brake
with up+down. Take-off: hold power, the plane accelerates along the runway,
and once speed exceeds 768 the y-clamp releases.

**Entering the hangar** (`triplane.cpp:1030-1069`): press roll or bomb while
`speed == 0`, not spinning/dying, and `player_on_airfield - 1 == own slot`
(own airfield only). This sets `plane_wants_in`; a mechanic (`do_mekan`)
walks out from the hangar at 2 px/frame, pushes the plane to the hangar door,
the door closes (13 frames), the plane disappears and `init_player()` runs
(`tripai.cpp:304-310`). Any movement cancels the request (`:142-146`).

**Hangar menu** (`hangarmenu_handle`, `:473-611`): human planes get a menu
with three columns (bombs, ammo, fuel); guns/bomb keys move between columns,
up/down adjust by 1 bomb, 16 rounds, 256 fuel (minimum 2). Maximums are the
nation's limits (or mission-restricted: bombers get no ammo, fighters no
bombs, `:3523-3545`). Press roll or power to leave: the plane is placed at the
hangar, given exactly the chosen bombs/ammo/fuel and **full endurance**
(`:604-608`), then the mechanic pushes it out to the runway end
(`tripai.cpp:318-450`). Repair/rearm/refuel are therefore **instant on hangar
exit**, but the whole push-in/menu/push-out cycle takes several seconds of
mechanic animation. Nothing is replenished by merely sitting on the runway.
Entering the hangar does **not** consume a life (`init_player` only decrements
`number_of_planes` when `in_closing` is set, i.e. after a crash, `:784-803`).
AI planes request the hangar when stopped on their own field with no fuel or
after a landing mission (`tripai.cpp:1680-1684`); AI planes in solo missions
receive a fixed load instead of a menu (`triplane.cpp:878-899`).

**Bad landing**: anything that is not inside the cone/roll state with the
wheel on the runway is a terrain collision: instant destruction, debris,
-1 point, and (solo) one plane from the pool.

## 6. Single-player missions

Source: `src/world/tripmis.cpp` (24 mission definitions, `init_mission()`
`:76`), `src/world/tmexept.cpp` (per-mission scripted exceptions),
`src/triplane.cpp:1535-1549, 1808-1842` (win/lose), `:780-913` (respawn),
`:1965-2110` (scoring), `data/misc/desc.txt` (24 briefings), level files
`data/levels/<country>-<mission>`.

**Definition**: entirely in C++. For each of the 4 countries x 6 missions,
`init_<country>(number)` fills per-slot arrays for all 12 plane slots
(`tripmis.cpp:101-2047`): `player_sides[]` (ALLIED 0 / ENEMY 1 / NEUTRAL 2),
`number_of_planes[]` (extra planes in the pool), `fighter[]`
(BOMBER 0 = bombs only, PLANE 1 = both, FIGHTER 2 = guns only),
`miss_pl_x/y[]` (non-zero = spawn airborne at that position at speed 1500
instead of from the hangar, `triplane.cpp:820-845`) and `miss_plane_direction[]`.
Mission names: `tripmis.cpp:63-67` (e.g. Germany: Coast Islands, Japanese
Counter-Attack, English Channel, Treachery, Capture, Against Odds). Which
ground objects are targets is stored in the level file: `struct_type`
0 = "Decoration", 1 = "Dest" (must destroy, drawn with red box), 2 = "Survi"
(must protect) (`src/tools/lvledit/lvledit.cpp:74-78`). `tmexept.cpp` adds
small scripted tweaks (initial headings, infantry turn-around points, extra
fail conditions such as German mission 2 failing when the allied bomber
flight is exhausted while targets remain, `tmexept.cpp:183-196`).

**Win condition** (`triplane.cpp:1812-1836`): `solo_success` when no plane
slot with `player_sides == ENEMY` still exists (every enemy plane pool used up)
**and** `solo_dest_remaining == 0` (all type-1 structures/AA guns/infantry
destroyed; counted at load `:1540-1547`, decremented in
`fobjects.cpp:738-739, 767-768, 814-815`, `tripai.cpp:842-843, 866-867, 915-916`).
The mission actually ends only when `solo_success || solo_failed` **and** the
player's plane is stopped on an airfield (`:1835`). The manual states this as
"at least one plane is left and stopped on a runway".

**Lose condition**: `solo_failed` when `number_of_planes[solo] < 0`
(`:1828-1829`), when any type-2 "Survi" object is destroyed (same call sites
as above), or by a mission exception. If the player spawned airborne and
fails, the mission ends immediately (`:1838-1839`).

**Lives / respawn**: `number_of_planes[slot]` is the number of *spare* planes;
the HUD draws `number_of_planes + 1` icons (`terrain.cpp:580-581`). Player
pools range from 1 (Japan mission 0, England missions 0-1, Germany missions
1-2) up to 7 (final missions). After a crash the wreck animation runs
(`in_closing` counts 2..88 at +2 per frame, about 1.8 s,
`terrain.cpp:562-563, 889-891`), then `init_player(l, 1)`: the pool is
decremented; if it goes negative an AI slot is removed for good
(`triplane.cpp:786-799`), while the player's slot triggers `solo_failed`.
Otherwise the new plane appears via the hangar menu (humans), is pushed out
of the hangar (AI), or spawns airborne (`miss_pl_x` slots). Enemy pools are
typically 1-5 per slot, with up to three slots per nation, e.g. England
mission 2 faces 5 + 5 Japanese planes; "Against Odds" style finales use
3 planes in each of nine enemy/neutral slots.

**Ground objects** (`load_level`, `triplane.cpp:3136-3271`; struct names
`:400-454`): named 8-char bitmaps placed in the level:
- destructible buildings with destroyed variants: factories (FAC1-2), houses
  (HOU1-5, CHOU), tents, barracks (BARR, CBARR), storehouse, water tower,
  igloo, vehicles (VEC1-2), plus trees (birch/oak/palm) that burn;
- `HANGAR` (airfield building), `FLAGS<n>` (animated nation flags, cosmetic);
- `INFAN` infantry: walks along the terrain, reverses at `INSTOP` markers or
  cliffs, shoots rifles at enemy planes within 150 px (aim jitter +-20 deg,
  bullet speed 4000, 0-5 damage) and at enemy infantry within 50 px; captures
  (destroys) enemy structures/AA guns it walks into (`tripai.cpp:697-1065`);
  dies to bullets or bombs;
- `KKBASE` AA machine gun: tracks enemy planes within 150 px with lead
  prediction, fires 6-round bursts every 7 ticks (`AA_MG_SHOT_SPEED 4800`);
- `ITGUN` flak/AAA: same tracking, fires one shell every 15 ticks that
  explodes after 32-41 ticks or on contact, area damage as in section 4
  (`tripai.cpp:602-695, 1067-1155`).
Owner 4 = neutral. There are **no ships, tanks or moving ground vehicles**.

**Scoring** (`triplane.cpp:1965-2110`, manual "SOLO GAME MODE"): kills x 25 +
remaining planes x 20, plus structures destroyed (+5 target, +7 enemy, -20
allied), AA guns (+5 target, +6 enemy, -10 allied), infantry (+1 target, +4
enemy, -2 allied), regardless of who destroyed them.

**Enemy AI behaviour** (`do_ai()`, `tripai.cpp:1242-1780`), a per-plane state
machine (`AIM_*` in `constants.h:117-127`):
- Engine on unless diving steeply; always tries to keep wheels-down roll for
  its direction; pulls down when near the ceiling (`y <= 20 px`).
- `TAKEOFF` -> flies until 40 px above terrain, then `NOMISSION`.
- `NOMISSION`: scans for enemy planes within 200 px (`AI_ATTACK_DISTANCE`)
  and, if it has ammo, switches to `CHASE_PLANE`; near the level edges
  (x < 120 + speed/40 or > 2280 - speed/40) it turns around with a split-S if
  there is room below, otherwise an Immelmann; otherwise terrain evasion.
- `CHASE_PLANE`: turns toward the target's predicted position; gives up at
  350 px, when out of ammo or when the target is gone; avoids stalling in
  climbs (`AI_STALL_WARNING`-style speed checks at 1800 / 2350 + bombs*64).
- `EVADE_TERRAIN`: looks 24 frames ahead along its velocity against a
  "widened" terrain profile (`wide_terrain_level`, min over +-25 px) and pulls
  up; lasts 24 frames.
- Bombing (`ai_do_bombing`, `:549-600`): whenever roughly level and carrying
  bombs, it simulates the full bomb trajectory each tick and releases if the
  impact point is on an enemy structure or AA gun that is not already
  targeted by another falling bomb.
- Gunnery: fires when any enemy plane is within 200 px and 30 deg of the nose,
  but holds fire if a friendly plane is within 180 px and 8 deg (`:1747-1779`).
- Returns home (`HEAD_FOR_HOME`/`LAND`) when out of both bombs and ammo or fuel
  < 500; approaches on a 1:3 glide slope, lands, brakes, and requests the
  hangar, where it is refuelled/rearmed/repaired like a human
  (`:1301-1443, 1680-1718`).
- AI planes are only spawned via hangar or air-spawn as defined by the
  mission; AI cannot take off in the "Cavern" multiplayer level (manual).

## 7. World and level representation

Source: `src/world/constants.h:49` (`NUMBER_OF_SCENES 15`),
`src/triplane.h:209-227` (level struct), `src/triplane.cpp:3039-3326`
(`load_level`), `src/world/terrain.cpp` (rendering), `src/triplane.cpp:1380-1402`
(`solo_do_all` camera), `doc/triplane.6` (options).

- **Screen**: 320x200, 256-colour VGA (optionally software-scaled 1-4x). Solo
  uses the full 320x200 with a 15 px HUD strip at the top (`boards`,
  `terrain.cpp:577-640`). Multiplayer VGA splits the screen into four
  160x100 quadrants (`x_muutos/y_muutos`, `triplane.cpp:189-194`); an
  optional 800x600 SVGA mode shows the whole level as three 800 px strips
  (`terrain.cpp:1006+`).
- **Level size**: exactly **2400 x 200 px** (15 scenes x 160 px; comment at
  `triplane.cpp:1399`). Height equals the screen, so there is **no vertical
  scrolling**; horizontal scrolling keeps the player at screen x = 160 and
  clamps the camera to `[0, 2400 - 320]` (`triplane.cpp:1386-1393`,
  `terrain.cpp:568-575`).
- **Terrain representation**: a single palette-indexed background bitmap
  (`maisema`, name in `leveldata.pb_name`); `level_bitmap` is its raw pixel
  array. Pixel colour index decides physics: **112-119 = sky (passable)**,
  **224-231 = water** (lethal, splash effects), anything else is solid ground
  or scenery (`triplane.cpp:1318, 3306-3316`, `fobjects.cpp:131-136`).
  `terrain_level[x]` (2400 ints) caches the highest solid pixel per column
  for AI, infantry and bomb prediction; `wide_terrain_level[x]` is the
  minimum over +-25 px (`triplane.cpp:1600-1617`).
- **Level file** (`level_struct`, 2872 bytes, little-endian int32):
  `pb_name` background, 100 structures x {`pd_name[8]`, x, y, `struct_hit`
  (draw into background / infantry direction), `struct_owner` (0-3 nation,
  4 neutral), `struct_type` (0 decoration, 1 destroy, 2 protect)}, 4 airfields
  x {x, y, length, `plane_direction`}. Files `data/levels/0-0 .. 3-5` (solo)
  and `level1 .. level6` (multiplayer), edited with `src/tools/lvledit`.
  Structures can be bitmaps blitted into the background with a "destroyed"
  twin (`struct_names` table, `triplane.cpp:400-454`).
- **Boundaries**: no wrap. Leaving the level horizontally (`nx < 0 || nx >= 2400`)
  is treated as hitting the ground pixel at (0,199), i.e. **fatal**
  (`triplane.cpp:1310-1318`). Bullets, bombs and debris simply vanish at the
  edges. The **top** (`y < 0`) is a soft wall: forced spin for 30-109 ticks
  and a push-back (`plane.cpp:231-233, 251-252`). AI turns around 120 px
  before the sides.

## 8. Kenney.nl free 3D assets with small propeller / WWI-style planes

Checked https://kenney.nl/assets with searches for "plane", "aircraft", "toy",
the `tag:plane` page and the 3D "Transport" series (October 2026).

- **No Kenney 3D kit contains propeller aircraft or WWI-style planes.** The
  `tag:plane` listing has only two packs, both 2D: **Tappy Plane** (2D,
  75 files, CC0, side-view cartoon planes, 2014) and **Pixel Shmup** (2D).
- The 3D "Transport" series is only **Car Kit**, **Train Kit**, **Watercraft
  Kit** (all CC0). Other 3D kits that could serve as neighbouring props or a
  style reference: **Space Kit** (150 files, CC0; spaceships), **Pirate Kit**
  (70 files, CC0; ships, islands, fortress walls), **Toy Car Kit** (100 files,
  CC0; toy cars and tracks), **Blaster Kit** (40 files, CC0; weapons/targets,
  no vehicles), **City Kit** / **Nature Kit** style packs for terrain.
- Licence: every Kenney asset pack is **Creative Commons CC0** (public domain,
  no attribution required). The paid "Kenney Game Assets All-in-1" bundle on
  itch.io is also CC0.
- Kenney's **Asset Forge** tool can produce Kenney-style low-poly planes from
  blocks, but that is a paid tool, not an asset pack.

Sources: https://kenney.nl/assets/tag:plane, https://kenney.nl/assets/series:Transport,
https://kenney.nl/assets/tappy-plane, https://kenney.nl/assets/space-kit,
https://kenney.nl/assets/pirate-kit, https://kenney.nl/assets/toy-car-kit,
https://kenney.nl/assets/blaster-kit, https://kenney.itch.io/kenney-game-assets.
