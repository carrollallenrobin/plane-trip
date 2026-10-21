class_name FlyingObject
extends RefCounted
## Anything that flies free through the World under gravity: a bullet, a Bomb, a Shell, a
## piece of Debris. Position and velocity in metres and seconds, and the Side it belongs to.
## Each kind adds how it ends. Named after the original's fobjects.

var position := Vector2.ZERO
var velocity := Vector2.ZERO
var side: int = Side.RED


## Fall and move for dt seconds.
func advance(dt: float, gravity: float) -> void:
	velocity.y -= gravity * dt
	position += velocity * dt
