class_name CameraShake
extends RefCounted
## Trauma-style camera shake, pure: no nodes. Happenings add trauma, which decays over
## DECAY_SECONDS; the shake's strength is trauma squared, so a graze barely registers and a
## Blast next to the plane heaves the view. The offset and roll come from smooth noise over
## time, so the picture lurches rather than jitters. FollowCamera applies it (ADR 0007).

## Seconds for full trauma to decay to nothing.
const DECAY_SECONDS := 0.6
## The most the view moves, metres, and rolls, radians, at full strength. The view is about
## 160 m wide, so 1.5 m was a few pixels and went unnoticed.
const MAX_OFFSET := 4.0
const MAX_ROLL := deg_to_rad(2.0)
## Trauma a Blast adds at its centre; it falls off to nothing at BLAST_RANGE.
const BLAST_TRAUMA := 0.8
const BLAST_RANGE := 60.0
## A hit on the player's plane: trauma, and a jolt the way the round was flying, metres.
## Trauma alone squared down to a wobble lost under the gun kick.
const HIT_TRAUMA := 0.5
const HIT_KICK := 1.5
## A hit while in a Spin, with no control to steady the view, is this much worse.
const SPIN_HIT_FACTOR := 1.6
## Trauma from each of the player's own shots: a tremor while firing. Trauma squared makes a
## small value nothing, so the shot is mostly felt as the recoil kick below.
const GUN_TRAUMA := 0.12
## Each of the player's shots kicks the view this far back along the nose, metres, and the
## kick recovers with this time constant, seconds: gone before the next round at six a second.
const GUN_KICK := 0.6
const KICK_RECOVERY := 0.05
## How fast the noise moves, in noise units per second, and how much it is amplified: raw
## simplex noise seldom reaches half its range, so it is doubled and clamped to swing fully.
const NOISE_SPEED := 12.0
const NOISE_GAIN := 2.0

var trauma := 0.0

var _time := 0.0
var _kick := Vector2.ZERO
var _noise_x := FastNoiseLite.new()
var _noise_y := FastNoiseLite.new()
var _noise_roll := FastNoiseLite.new()


func _init() -> void:
	for noise in [_noise_x, _noise_y, _noise_roll]:
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 1.0
	_noise_x.seed = 1
	_noise_y.seed = 2
	_noise_roll.seed = 3


func add(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## A Blast this far from the player's plane.
func blast_at(distance: float) -> void:
	add(BLAST_TRAUMA * clampf(1.0 - distance / BLAST_RANGE, 0.0, 1.0))


## The player's gun fired along `direction`: the view jolts the other way.
func recoil(direction: Vector2) -> void:
	_kick = -direction.normalized() * GUN_KICK


## The player's plane was hit by something flying along `direction`: the view is knocked
## that way and shaken, harder when the plane is in a Spin.
func hit(direction: Vector2, in_spin := false) -> void:
	var factor := SPIN_HIT_FACTOR if in_spin else 1.0
	add(HIT_TRAUMA * factor)
	_kick = direction.normalized() * HIT_KICK * factor


func advance(dt: float) -> void:
	_time += dt
	trauma = maxf(0.0, trauma - dt / DECAY_SECONDS)
	_kick *= exp(-dt / KICK_RECOVERY)


func strength() -> float:
	return trauma * trauma


## Where the view sits relative to where it would be, metres.
func offset() -> Vector2:
	return Vector2(_swing(_noise_x), _swing(_noise_y)) * (MAX_OFFSET * strength()) + _kick


## The view's roll about the line of sight, radians.
func roll() -> float:
	return _swing(_noise_roll) * MAX_ROLL * strength()


## The noise now, amplified and clamped to [-1, 1].
func _swing(noise: FastNoiseLite) -> float:
	return clampf(noise.get_noise_1d(_time * NOISE_SPEED) * NOISE_GAIN, -1.0, 1.0)
