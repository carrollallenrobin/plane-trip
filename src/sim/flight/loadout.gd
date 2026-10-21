class_name Loadout
extends Resource
## What a Plane carries into the air: which Fitting sits in each of its Slots, as a list with
## repeats. The player chooses theirs at a Refit; a Mission's author gives the enemy's as a
## preset in data/loadouts/. Capacities are the Airframe's base plus what the Fittings add.

@export var fittings: Array[Fitting] = []


static func of(list: Array[Fitting]) -> Loadout:
	var loadout := Loadout.new()
	loadout.fittings = list.duplicate()
	return loadout


func slots_used() -> int:
	return fittings.size()


## True when every Fitting has a Slot.
func fits(airframe: Airframe) -> bool:
	return fittings.size() <= airframe.slots


func count_of(fitting: Fitting) -> int:
	return fittings.count(fitting)


## The bare plane carries no bombs; every one hangs on a Bomb Rack.
func bombs() -> int:
	var total := 0
	for fitting in fittings:
		total += fitting.bombs
	return total


func rounds(airframe: Airframe) -> int:
	var total := airframe.base_rounds
	for fitting in fittings:
		total += fitting.rounds
	return total


func fuel_seconds(airframe: Airframe) -> float:
	var total := airframe.base_fuel_seconds
	for fitting in fittings:
		total += fitting.fuel_seconds
	return total


func hit_points(airframe: Airframe) -> int:
	var total := airframe.base_hit_points
	for fitting in fittings:
		total += fitting.hit_points
	return total


## Weight of the Fittings themselves, without the bombs hanging on the racks.
func fixed_mass() -> float:
	var total := 0.0
	for fitting in fittings:
		total += fitting.mass
	return total
