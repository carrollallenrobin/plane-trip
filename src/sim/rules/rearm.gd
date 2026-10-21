class_name Rearm
extends RefCounted
## Restores a stopped Plane's fuel, rounds, bombs and hit points to its Loadout's capacities
## while it sits on its own Side's Airfield. Everything refills together over DURATION
## seconds; moving off resets the progress but keeps whatever was already restored.

const DURATION := 4.0

## 0 to 1 while rearming, 0 when idle.
var progress := 0.0


## Advance by dt. Returns true on the step the plane becomes fully rearmed.
func update(s: PlaneState, on_own_airfield: bool, dt: float) -> bool:
	if not on_own_airfield or s.speed > 0.0:
		progress = 0.0
		return false
	if is_complete(s):
		progress = 0.0
		return false
	progress = minf(1.0, progress + dt / DURATION)
	s.fuel = maxf(s.fuel, s.max_fuel() * progress)
	s.rounds = maxi(s.rounds, int(floor(s.max_rounds() * progress)))
	s.bombs = maxi(s.bombs, int(floor(s.max_bombs() * progress)))
	s.hit_points = maxi(s.hit_points, int(floor(s.max_hit_points() * progress)))
	if progress >= 1.0:
		progress = 0.0
		return true
	return false


func is_active() -> bool:
	return progress > 0.0


## Fill the Plane to its Loadout's capacities at once: the player's Refit.
static func complete(s: PlaneState) -> void:
	s.fuel = s.max_fuel()
	s.rounds = s.max_rounds()
	s.bombs = s.max_bombs()
	s.hit_points = s.max_hit_points()


static func is_complete(s: PlaneState) -> bool:
	return (
		s.fuel >= s.max_fuel()
		and s.rounds >= s.max_rounds()
		and s.bombs >= s.max_bombs()
		and s.hit_points >= s.max_hit_points()
	)
