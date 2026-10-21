class_name Sway
extends RefCounted
## The small roll a Plane shows in the picture: mostly a slow wander, as if in rough air, with
## a hint of bank into its pitch change, up to MAX_BANK at the full pitch rate. (15 degrees
## of bank with 2 of noise felt wrong in play on 2026-10-18; the balance was turned around.)
## Pure: no nodes. Derived from the state after each step and eased, never fed back
## (ADR 0007). Off while the half-roll, the Ceiling tumble or a Spin owns the roll, and on
## the ground. PlaneNode applies it on a pivot between the node and the body.

const MAX_BANK := deg_to_rad(4.0)
const NOISE_BANK := deg_to_rad(5.0)
## Noise units per second: a slow wander.
const NOISE_SPEED := 0.7
## The bank eases toward what the state wants at this rate per second.
const EASING := 8.0

## Radians about the nose; positive tilts the top toward the camera when pulling up.
var bank := 0.0

var _time := 0.0
var _noise := FastNoiseLite.new()
var _last_angle := 0.0
var _has_last := false


func _init(seed_value := 0) -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = seed_value


## The state after a step of dt seconds; full_pitch_rate is the Plane's, degrees per second.
func update(state: PlaneState, full_pitch_rate: float, dt: float) -> void:
	_time += dt
	var rate := 0.0
	if _has_last and dt > 0.0:
		rate = wrapf(state.angle - _last_angle, -180.0, 180.0) / dt
	_last_angle = state.angle
	_has_last = true
	var wanted := 0.0
	if owns_roll(state):
		wanted = clampf(rate / maxf(full_pitch_rate, 1.0), -1.0, 1.0) * MAX_BANK
		wanted += _noise.get_noise_1d(_time * NOISE_SPEED) * 2.0 * NOISE_BANK
	bank = lerpf(bank, wanted, 1.0 - exp(-EASING * dt))


## A new life: nothing to compare the angle with.
func reset() -> void:
	bank = 0.0
	_has_last = false


## Sway owns the roll only when nothing else does and the Plane is flying.
static func owns_roll(state: PlaneState) -> bool:
	return (
		not state.in_spin
		and state.roll_remaining <= 0.0
		and state.ceiling_spin_remaining <= 0.0
		and not state.on_airfield
	)
