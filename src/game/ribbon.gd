class_name Ribbon
extends RefCounted
## A wingtip ribbon: the trail of where a wingtip has been over the last LIFE seconds, each
## point carrying how strongly the ribbon showed when it was laid. Pure: no nodes. The
## strength comes from the Plane's g-load and speed, so it shows in tight turns and fast
## dives and not in cruise, and it fades in rather than snapping on. PlaneNode draws it.

const LIFE := 0.8
## Strength rises toward what the state wants at FADE_IN_RATE per second, full in 0.2 s, and
## falls at FADE_OUT_RATE, so a g-load passing through zero on a quick reversal does not
## blank the ribbon and relight it.
const FADE_IN_RATE := 5.0
const FADE_OUT_RATE := 2.0
## Nothing below G_FROM, full at G_FULL; the same for speed as a fraction of top speed.
const G_FROM := 3.0
const G_FULL := 6.0
const SPEED_FROM := 0.85
const SPEED_FULL := 1.1
const WIDTH := 0.3

var points := PackedVector3Array()
var ages := PackedFloat32Array()
var strengths := PackedFloat32Array()
var strength := 0.0


## How strongly the ribbon wants to show for this g-load and speed, 0 to 1.
static func wanted(g_load: float, speed: float, top_speed: float) -> float:
	var by_g := inverse_lerp(G_FROM, G_FULL, absf(g_load))
	var by_speed := inverse_lerp(SPEED_FROM * top_speed, SPEED_FULL * top_speed, speed)
	return clampf(maxf(by_g, by_speed), 0.0, 1.0)


## The wingtip is at `point` now; the Plane pulls `g_load` at `speed`.
func update(point: Vector3, g_load: float, speed: float, top_speed: float, dt: float) -> void:
	var target := wanted(g_load, speed, top_speed)
	var rate := FADE_IN_RATE if target > strength else FADE_OUT_RATE
	strength = move_toward(strength, target, rate * dt)
	for i in ages.size():
		ages[i] += dt
	var first_alive := 0
	while first_alive < ages.size() and ages[first_alive] >= LIFE:
		first_alive += 1
	if first_alive > 0:
		points = points.slice(first_alive)
		ages = ages.slice(first_alive)
		strengths = strengths.slice(first_alive)
	points.append(point)
	ages.append(0.0)
	strengths.append(strength)


## How visible the ribbon is at its i-th point: as strong as it was laid, fading with age.
func alpha_at(i: int) -> float:
	return strengths[i] * (1.0 - ages[i] / LIFE)


## The half-width vector across the ribbon at its i-th point, in the action plane. Kept on
## the same side as `previous` so a path that doubles back does not twist the strip; a
## point with no direction keeps the previous vector.
func across_at(i: int, previous: Vector3) -> Vector3:
	var count := points.size()
	var along := points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]
	along.z = 0.0
	if along.is_zero_approx():
		return previous
	var across := Vector3(-along.y, along.x, 0.0).normalized() * (WIDTH / 2.0)
	if across.dot(previous) < 0.0:
		across = -across
	return across


func clear() -> void:
	points.clear()
	ages.clear()
	strengths.clear()
	strength = 0.0
