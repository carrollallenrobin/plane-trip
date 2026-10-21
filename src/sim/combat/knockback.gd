class_name Knockback
extends RefCounted
## A hit shoves the Plane (docs/design.md, Damage and death): velocity only, never the nose,
## the same for every Plane. Small arms and Debris push along their own flight by the damage
## they did; a Blast pushes away from its centre, falling off like its damage. Not while
## parked: a Plane on the runway has nowhere to go but into it. Pure: no nodes.

## Metres per second per point of damage from a bullet or a piece of Debris. A full-damage
## Machine Gun round (11) shoves about 2.75 m/s.
const PER_POINT := 0.25
## Metres per second from a Blast at its centre, scaled by its damage against a Shell's
## full 80, so a Bomb's 1000 counts as a full Blast and a Shell at 16 m as nothing.
const BLAST_MAX := 12.0
const BLAST_FULL_DAMAGE := 80.0


## Apply a hit's shove to the Plane: `direction` is the round's flight, or away from the
## Blast's centre, and `hit` says how much and of which kind.
static func apply(s: PlaneState, direction: Vector2, hit: DamageRules.Hit) -> void:
	if s.on_airfield or hit.amount <= 0 or direction.is_zero_approx():
		return
	var push := 0.0
	if hit.blast:
		push = BLAST_MAX * clampf(hit.amount / BLAST_FULL_DAMAGE, 0.0, 1.0)
	else:
		push = PER_POINT * hit.amount
	s.vel += direction.normalized() * push
	s.speed = s.vel.length()
