class_name Airframe
extends Resource
## The one airframe every Plane is built on (docs/design.md, Planes and Loadouts): how many
## Slots it has, what the bare plane always carries, and what it weighs empty. Flight physics
## live in FlightTuning. The game loads data/airframe.tres; tests build their own.

## Hardpoints a Loadout can fill.
@export var slots := 6
## Empty mass in the original's dimensionless units; the Loadout's weight is measured against it.
@export var empty_mass := 200.0
## What one hanging Bomb weighs, in the same units. Original: bombs * 12. A Bomb Rack weighs
## its bombs, so dropping them lightens the Plane.
@export var bomb_mass := 12.0
## What the bare plane carries with every Slot empty: enough fuel for a short sortie and a
## short belt, so no Slots is a fast option rather than a trap.
@export var base_fuel_seconds := 30.0
@export var base_rounds := 40
@export var base_hit_points := 25
