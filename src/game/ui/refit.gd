class_name Refit
extends RefCounted
## The player's choice at a Refit: how many of each Fitting go in the airframe's Slots,
## started from a Loadout and giving one back. Pure, so the rules of the screen (no more
## Fittings than Slots, never below none) are tested without a node.

var airframe: Airframe
## The Fittings on offer, in the order the screen lists them.
var fittings: Array[Fitting] = []
## How many of each, by index into fittings.
var counts: Array[int] = []


## Start from what the Plane carries now. A Fitting of the current Loadout is matched by
## identity or, failing that, by name, so a preset and the screen's own list agree.
static func create(plane_airframe: Airframe, on_offer: Array[Fitting], current: Loadout) -> Refit:
	var refit := Refit.new()
	refit.airframe = plane_airframe
	refit.fittings = on_offer.duplicate()
	for fitting in refit.fittings:
		var count := 0
		if current != null:
			for carried in current.fittings:
				if carried == fitting or carried.display_name == fitting.display_name:
					count += 1
		refit.counts.append(count)
	while refit.slots_used() > plane_airframe.slots:
		refit._drop_one()
	return refit


func slots_used() -> int:
	var used := 0
	for count in counts:
		used += count
	return used


func slots_free() -> int:
	return airframe.slots - slots_used()


## One more of this Fitting, if a Slot is free. Returns whether anything changed.
func add(index: int) -> bool:
	if slots_free() <= 0:
		return false
	counts[index] += 1
	return true


## One fewer of this Fitting, if any. Returns whether anything changed.
func remove(index: int) -> bool:
	if counts[index] <= 0:
		return false
	counts[index] -= 1
	return true


## The Loadout as chosen: each Fitting repeated its count of times.
func loadout() -> Loadout:
	var list: Array[Fitting] = []
	for i in fittings.size():
		for n in counts[i]:
			list.append(fittings[i])
	return Loadout.of(list)


## A full Plane as it would be with this choice, for the readout.
func preview() -> PlaneState:
	return PlaneState.create(airframe, loadout())


func _drop_one() -> void:
	for i in range(counts.size() - 1, -1, -1):
		if counts[i] > 0:
			counts[i] -= 1
			return
