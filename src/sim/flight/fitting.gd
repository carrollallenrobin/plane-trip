class_name Fitting
extends Resource
## A kind of thing a Slot can hold: a Bomb Rack, an Ammunition Box, a Fuel Tank or an Armour
## Plate. Each raises one capacity and adds weight (docs/design.md, Planes and Loadouts).
## Defined as data in data/fittings/; the Refit screen lists what it finds there.

@export var display_name := "Fitting"
@export var bombs := 0
@export var rounds := 0
@export var fuel_seconds := 0.0
@export var hit_points := 0
## Weight that stays whether the Fitting is full or empty, in the airframe's units. The
## bombs a Bomb Rack carries are weighed separately, by the Airframe, so they can drop.
@export var mass := 0.0


static func create(
	name: String,
	bomb_count := 0,
	round_count := 0,
	fuel := 0.0,
	hit_point_count := 0,
	weight := 0.0
) -> Fitting:
	var fitting := Fitting.new()
	fitting.display_name = name
	fitting.bombs = bomb_count
	fitting.rounds = round_count
	fitting.fuel_seconds = fuel
	fitting.hit_points = hit_point_count
	fitting.mass = weight
	return fitting
