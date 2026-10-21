class_name BombImpact
extends RefCounted
## A bomb detonating this step: on a plane, on a Ground Target, or on the ground.

var bomb: Bomb
var position := Vector2.ZERO
var plane: PlaneState
var ground_target: GroundTarget
