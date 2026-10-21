# The store page

What goes on the itch.io page. The covers are rendered from the game's own models by
`scripts/build-cover.sh` (`art/cover.py`), never drawn or edited by hand; itch.io wants
630x500 and the 640x512 is a spare for other listings. The folder is ignored by Godot
(`.gdignore`), so nothing here is imported or exported.

## Pitch

Plane Trip is a single-player, side-view aerial combat game in the spirit of Triplane
Turmoil. Fit your triplane out with bomb racks, ammunition, fuel and armour, take off from
your airfield, dogfight AI pilots, bomb their depot and hangar under flak, and land to
rearm and go again. Two missions, one airframe, flat-shaded WW2 models, a wireless dance
band, and it plays in the browser.

## How to play

- Pick a mission from the list. The Refit screen opens: six slots to fill with Bomb Racks,
  Ammunition Boxes, Fuel Tanks and Armour Plates. Everything you carry slows the plane; an
  empty plane is fast and fragile.
- Take off: hold Shift for thrust, push the stick (Up) to lift the tail, and pull (Down)
  once you have speed.
- Fly: Down pulls the nose up, Up pushes it down. Left or Right half-rolls the plane, which
  flips it over and swaps pitch. Fuel burns only while thrusting. Up and Down together is
  the air brake.
- Fight: Z fires the machine gun, X drops a bomb. Bombs fall from the belly with your
  speed, so line the drop up from the plane's path, not from where you are.
- Read the panel: fuel, rounds and HULL on the dials, bombs and planes left as silhouettes,
  your objectives on the slip at the top left.
- Stay inside the world: water, the left and right borders and the ground all destroy the
  plane, and above the ceiling it tumbles until it falls back under.
- Land to rearm: wheels on the runway, nose between twenty degrees up and ten down, right
  side up, no speed check. Stop on your own airfield and the Refit screen opens again;
  confirming it rearms you. The fight goes on behind the screen.
- Win by completing every required objective. Lose when a Protect target falls or your
  stock of planes runs out.
- Escape pauses. A gamepad works too: stick to fly, A fires, X bombs, B half-rolls, right
  shoulder thrusts.
