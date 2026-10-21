class_name GunShot
extends RefCounted
## A ground gun firing this step: which gun, where its barrel is and which way it pointed.
## The round itself is in AirCombat.bullets or GroundGuns.shells; this is for the picture.

var gun: GroundTarget
var position := Vector2.ZERO
var direction := Vector2(0.0, 1.0)
