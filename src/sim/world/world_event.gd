class_name WorldEvent
extends RefCounted
## Something that happened in the World during one step, for the rendering to react to with
## a sound, a Muzzle Flash, a Burst, an impact puff, or a plane node appearing or going. What
## simply is (positions, projectiles, kills, the outcome) is read from the World instead. An
## event carries what the picture needs to draw it and nothing a rule did not already know
## (ADR 0007).

enum Kind {
	PLANE_SPAWNED,
	PLANE_HIT,
	PLANE_DESTROYED,
	GUN_FIRED,
	BOMB_RELEASED,
	BULLET_IMPACT,
	BOMB_DETONATED,
	SHELL_BURST,
	TARGET_DESTROYED,
	MISSION_ENDED,
	## The player's Plane is ready for a Refit: just spawned, or stopped on its own Airfield
	## having flown since the last one. Once per landing.
	REFIT_DUE,
}

var kind: Kind
## The Plane involved, for the Plane events; null on a GUN_FIRED from a ground gun.
var plane: WorldPlane
## Where it happened: the muzzle for GUN_FIRED, the point of impact for PLANE_HIT and
## BULLET_IMPACT, where the Bomb left for BOMB_RELEASED, the burst, or the Plane or Ground
## Target as it was destroyed.
var position := Vector2.ZERO
## A destroyed Plane's velocity, which its Debris inherits.
var velocity := Vector2.ZERO
## Which way: the round's flight for GUN_FIRED, and what hit the Plane for PLANE_HIT (the
## bullet's or Debris' flight, or away from the Blast's centre).
var direction := Vector2.ZERO
## What ended a destroyed Plane: the crash kind, or NONE for a Blast.
var crash := CrashRules.Outcome.NONE
## The Ground Target: destroyed for TARGET_DESTROYED, firing for a ground gun's GUN_FIRED,
## struck for a BULLET_IMPACT on one.
var target: GroundTarget
## What the round ended on, for BULLET_IMPACT.
var surface := BulletHit.Surface.GROUND
## The Mission's outcome, for MISSION_ENDED.
var outcome := MissionRules.Outcome.ONGOING


static func make(event_kind: Kind) -> WorldEvent:
	var event := WorldEvent.new()
	event.kind = event_kind
	return event


static func for_plane(event_kind: Kind, world_plane: WorldPlane) -> WorldEvent:
	var event := make(event_kind)
	event.plane = world_plane
	event.position = world_plane.state.position
	event.velocity = world_plane.state.velocity()
	return event


static func at(event_kind: Kind, where: Vector2) -> WorldEvent:
	var event := make(event_kind)
	event.position = where
	return event
