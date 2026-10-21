class_name DamageRules
extends RefCounted
## Applies damage to planes and decides how a plane dies. The final blow decides: bullets
## and Debris put an airborne plane into a Spin, a Blast or an impact destroys it outright
## (docs/design.md, Damage and death). Damage amounts are the original's random rolls. Each
## hit reports its outcome and how much it took, for the knockback (Knockback).

enum Outcome { NONE, SPIN, EXPLODE }


## What one hit did: the outcome, the points it took off, and whether it was a Blast.
class Hit:
	var outcome := Outcome.NONE
	var amount := 0
	var blast := false

	static func of(hit_outcome: Outcome, taken: int, was_blast := false) -> Hit:
		var hit := Hit.new()
		hit.outcome = hit_outcome
		hit.amount = taken
		hit.blast = was_blast
		return hit


## Original: a plane's machine gun does wrandom(12), i.e. 0 to 11.
const BULLET_DAMAGE_MAX := 11
## Original: anti-aircraft and infantry bullets do wrandom(6), 0 to 5.
const GROUND_BULLET_DAMAGE_MAX := 5
## Original: flying parts do wrandom(FOBJECTS_DAMAGE 8), 0 to 7.
const DEBRIS_DAMAGE_MAX := 7

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


func bullet_hit(s: PlaneState) -> Hit:
	return _small_arms(s, _rng.randi_range(0, BULLET_DAMAGE_MAX))


func ground_bullet_hit(s: PlaneState) -> Hit:
	return _small_arms(s, _rng.randi_range(0, GROUND_BULLET_DAMAGE_MAX))


func debris_hit(s: PlaneState) -> Hit:
	return _small_arms(s, _rng.randi_range(0, DEBRIS_DAMAGE_MAX))


## A plane's Machine Gun round striking a gun: the original's roll against the gun's hit
## points. Returns true when this round destroyed the Ground Target.
func bullet_hit_ground_target(target: GroundTarget) -> bool:
	return target.damage(_rng.randi_range(0, BULLET_DAMAGE_MAX))


## A Blast of the given strength: destroys outright when it brings the plane to zero,
## including a plane already in a Spin.
func blast(s: PlaneState, amount: int) -> Hit:
	# Already destroyed, or exploded this very tick and not yet marked: nothing left to do.
	if not s.in_play() or s.hit_points <= 0 and not s.in_spin:
		return Hit.of(Outcome.NONE, 0, true)
	s.hit_points = maxi(0, s.hit_points - amount)
	if s.hit_points <= 0:
		s.in_spin = false
		return Hit.of(Outcome.EXPLODE, amount, true)
	return Hit.of(Outcome.NONE, amount, true)


## Bullets and Debris: a plane brought to zero in the air enters a Spin; on the ground it
## explodes, as there is nowhere to fall. A plane already in a Spin takes no further notice,
## not even a shove.
func _small_arms(s: PlaneState, amount: int) -> Hit:
	if not s.can_fight():
		return Hit.of(Outcome.NONE, 0)
	s.hit_points = maxi(0, s.hit_points - amount)
	if s.hit_points > 0:
		return Hit.of(Outcome.NONE, amount)
	if s.on_airfield:
		return Hit.of(Outcome.EXPLODE, amount)
	s.in_spin = true
	return Hit.of(Outcome.SPIN, amount)
