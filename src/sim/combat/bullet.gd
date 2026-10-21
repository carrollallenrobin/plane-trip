class_name Bullet
extends FlyingObject
## One Machine Gun or Anti-Aircraft Gun round in flight: ages out, or stops at the first thing
## it touches.

var age := 0.0
## id of the PlaneState that fired it, so a plane never shoots itself; -1 from a ground gun.
var owner_id := 0
