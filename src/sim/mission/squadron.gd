class_name Squadron
extends RefCounted
## A Side's AI Planes as its Hangar sends them up: a fixed number of slots kept Aloft, each
## flying its own Loadout, drawn from a pool that may be unlimited, with an interval between
## any two launches so Planes do not leave the Hangar in a clump. Pure and clocked by the
## World: fill() schedules a Plane for every empty slot the pool allows, step() says which
## slots are due one, and release() frees the slot of a Plane that is gone. Whether the
## Hangar still stands is the World's to check before filling and before launching.

## A pool of this size never runs dry.
const UNLIMITED := 0

var side: int = Side.RED
## How many Planes are kept Aloft at once.
var aloft := 1
## Planes the pool has left to send; meaningless when unlimited.
var pool := 0
var unlimited := false
## One Loadout per slot: a replacement flies what the Plane it replaces flew. A shorter list
## repeats its last entry; an empty one gives null.
var loadouts: Array[Loadout] = []
## Seconds between two launches.
var interval := 0.0

var _planes: Array[WorldPlane] = []  # per slot, null while empty
var _due: Array[float] = []  # per slot, the launch time, or -1 with nothing scheduled
var _time := 0.0
var _last_launch := -INF


static func create(
	squadron_side: int, slots: int, pool_size: int, presets: Array[Loadout], spacing: float
) -> Squadron:
	var squadron := Squadron.new()
	squadron.side = squadron_side
	squadron.aloft = maxi(slots, 0)
	squadron.pool = pool_size
	squadron.unlimited = pool_size == UNLIMITED
	squadron.loadouts = presets
	squadron.interval = spacing
	for slot in squadron.aloft:
		squadron._planes.append(null)
		squadron._due.append(-1.0)
	return squadron


## What the Plane in this slot carries, or null when the Squadron has no presets.
func loadout_for(slot: int) -> Loadout:
	if loadouts.is_empty():
		return null
	return loadouts[mini(slot, loadouts.size() - 1)]


## How many slots hold a Plane.
func aloft_count() -> int:
	var count := 0
	for plane in _planes:
		if plane != null:
			count += 1
	return count


## Planes the pool has left to send; -1 when unlimited.
func left() -> int:
	return -1 if unlimited else pool


## Schedule a launch for every empty slot nothing is scheduled for, while the pool allows:
## at `delay` from now, or the interval after the last launch scheduled, whichever is later.
func fill(delay: float) -> void:
	for slot in aloft:
		if _planes[slot] != null or _due[slot] >= 0.0:
			continue
		if not unlimited:
			if pool <= 0:
				return
			pool -= 1
		var at := maxf(_time + delay, _last_launch + interval)
		_due[slot] = at
		_last_launch = at


## Advance the clock and return the slots whose launch is due, each once.
func step(dt: float) -> Array[int]:
	_time += dt
	var due: Array[int] = []
	for slot in aloft:
		if _due[slot] >= 0.0 and _due[slot] <= _time:
			_due[slot] = -1.0
			due.append(slot)
	return due


## The Plane launched into this slot.
func occupy(slot: int, plane: WorldPlane) -> void:
	_planes[slot] = plane


## The Plane is gone and its slot is free.
func release(plane: WorldPlane) -> void:
	var slot := _planes.find(plane)
	if slot >= 0:
		_planes[slot] = null


func holds(plane: WorldPlane) -> bool:
	return _planes.has(plane)


## True when nothing is Aloft and nothing more can come: the Hangar is gone, or the pool is
## spent with no launch scheduled.
func grounded(hangar_alive: bool) -> bool:
	if aloft_count() > 0:
		return false
	if aloft == 0 or not hangar_alive:
		return true
	if unlimited or pool > 0:
		return false
	for due in _due:
		if due >= 0.0:
			return false
	return true
