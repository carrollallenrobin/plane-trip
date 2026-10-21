class_name Debris
extends FlyingObject
## A piece thrown off a destroyed Plane or Ground Target: flies under gravity with the
## velocity of what it came from plus a random spread, settles where it meets the terrain, and
## is gone after LIFETIME seconds. A piece that touches a Plane damages it
## (DamageRules.debris_hit). Simulated like the other flying objects, so every damage rule
## runs inside the deterministic step; the rendering only draws the pieces.

## Seconds before a piece disappears.
const LIFETIME := 4.0
## Original: each part gets the plane's velocity plus a random spread of PARTS_SPEED
## (270000 in 64ths of a speed unit) centred on zero, about 20 m/s each way.
const SPREAD := 270000.0 / 64.0 * SimUnits.SPEED_UNIT
## Original: up to NUMBER_OF_EXPLOSION_PARTS (30) parts.
const MAX_PARTS := 30

var age := 0.0
## True once the piece lies on the terrain.
var settled := false
## For the rendering only: size in metres and the tumble, radians and radians per second.
var size := 0.8
var angle := 0.0
var spin := 0.0


static func burst(
	origin: Vector2, base_velocity: Vector2, rng: RandomNumberGenerator
) -> Array[Debris]:
	var pieces: Array[Debris] = []
	for i in rng.randi_range(0, MAX_PARTS):
		var piece := Debris.new()
		piece.position = origin
		var spread := Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)) * SPREAD
		piece.velocity = base_velocity + spread
		piece.spin = rng.randf_range(-10.0, 10.0)
		piece.size = rng.randf_range(0.4, 1.2)
		pieces.append(piece)
	return pieces


## Come to rest on the terrain at this height.
func settle(surface_y: float) -> void:
	settled = true
	velocity = Vector2.ZERO
	position.y = surface_y
