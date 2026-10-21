class_name BulletHit
extends RefCounted
## A bullet ending on something this step, before damage is applied: a Plane, a Ground Target
## (only guns take damage, but every one stops the round), the ground or Water. A bullet that
## ages out or leaves the World ends on nothing and is not reported.

enum Surface { PLANE, TARGET, GROUND, WATER }

var bullet: Bullet
var surface := Surface.GROUND
## Where the round ended: inside the hit box, on the footprint, or on the terrain.
var position := Vector2.ZERO
## The Plane struck, for PLANE.
var target: PlaneState
## The Ground Target struck, for TARGET.
var ground_target: GroundTarget


## The round's direction of flight as it ended.
func direction() -> Vector2:
	return bullet.velocity.normalized()
