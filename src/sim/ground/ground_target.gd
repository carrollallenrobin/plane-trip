class_name GroundTarget
extends RefCounted
## A destructible object fixed to the terrain: a building, an Anti-Aircraft Gun, a Flak Gun
## or a Hangar. Belongs to a Side. Its footprint is a box standing on its base point.

enum Kind { BUILDING, ANTI_AIRCRAFT_GUN, FLAK_GUN, HANGAR }

## Buildings and hangars fall only to bombs; guns can be shot up with machine guns too.
const GUN_HIT_POINTS := 20
const BUILDING_HIT_POINTS := 1
## A bomb does this much to whatever it lands on.
const BOMB_DAMAGE := 1000

## Name of the node that placed it; objectives refer to targets by this name.
var name := ""
var side: int = Side.RED
var kind := Kind.BUILDING
## Centre of the base, on the terrain.
var base := Vector2.ZERO
var width := 10.0
var height := 6.0
var hit_points := 1


static func create(
	target_name: String,
	target_side: int,
	target_kind: Kind,
	base_point: Vector2,
	w: float,
	h: float
) -> GroundTarget:
	var target := GroundTarget.new()
	target.name = target_name
	target.side = target_side
	target.kind = target_kind
	target.base = base_point
	target.width = w
	target.height = h
	target.hit_points = GUN_HIT_POINTS if target.is_gun() else BUILDING_HIT_POINTS
	return target


func is_alive() -> bool:
	return hit_points > 0


func is_gun() -> bool:
	return kind == Kind.ANTI_AIRCRAFT_GUN or kind == Kind.FLAK_GUN


## Where the gun's barrel is, or the middle of a building.
func centre() -> Vector2:
	return base + Vector2(0.0, height / 2.0)


## True when the point is inside the footprint, with a little slack below the base so a
## bomb that reaches the ground inside it counts. Original: structure box plus 5 px.
func contains(point: Vector2) -> bool:
	var slack := 5.0 * SimUnits.PIXEL
	return (
		absf(point.x - base.x) <= width / 2.0
		and point.y >= base.y - slack
		and point.y <= base.y + height + slack
	)


## Apply damage. Returns true when this blow destroyed the target.
func damage(amount: int) -> bool:
	if hit_points <= 0:
		return false
	hit_points = maxi(0, hit_points - amount)
	return hit_points == 0
