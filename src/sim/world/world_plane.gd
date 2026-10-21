class_name WorldPlane
extends RefCounted
## A Plane as the World runs it: its state, the Pilot flying it, its flight model and its
## Rearm progress. The record outlives one life: when the Plane is destroyed and a new one
## spawns, the state is replaced and the Pilot stays, so a plane node or the camera can hold
## on to the record. Pure: no nodes.

var side: int = Side.BLUE
var airframe: Airframe
## What this Plane carries; every new life is built from it.
var loadout: Loadout
var state: PlaneState
var pilot: Pilot
var model: FlightModel
var rearm := Rearm.new()
## True once this Plane's loss has been counted as a kill, so a Spin and the Blast that
## finishes it count once.
var kill_counted := false
## True once the Plane has been off the ground since its last Refit (or its spawn), so a
## stop at home after a sortie is a Refit and sitting on the runway after one is not.
var flown_since_refit := false


static func create(
	plane_airframe: Airframe,
	plane_loadout: Loadout,
	plane_side: int,
	plane_pilot: Pilot,
	flight_model: FlightModel
) -> WorldPlane:
	var plane := WorldPlane.new()
	plane.airframe = plane_airframe
	plane.loadout = plane_loadout
	plane.side = plane_side
	plane.pilot = plane_pilot
	plane.model = flight_model
	plane.state = PlaneState.create(plane_airframe, plane_loadout, plane_side)
	return plane


## True while the Plane is in the World: flying, parked, or falling in a Spin.
func is_alive() -> bool:
	return state != null and state.in_play()


## Start a new life: a fresh Plane at rest on a runway, ready to take off in the given
## direction. Keeps the id so bullets and events still tell the Planes apart.
func place_on_runway(spawn: Vector2, heading_right: bool) -> void:
	var id := state.id if state != null else 0
	state = PlaneState.create(airframe, loadout, side, id)
	park_at(spawn, heading_right)
	rearm = Rearm.new()
	kill_counted = false
	flown_since_refit = false
	pilot.start_life()


## Set the Plane down at rest on a runway, tail down, ready to take off in the given
## direction, as it is; nothing it carries changes.
func park_at(spawn: Vector2, heading_right: bool) -> void:
	state.position = spawn
	state.angle = FlightModel.REST_PITCH if heading_right else 180.0 - FlightModel.REST_PITCH
	state.upside_down = not heading_right  # wheels down for the heading
	state.vel = Vector2.ZERO
	state.speed = 0.0
	state.on_airfield = true


## Show the Pilot the other Planes and the Ground Targets and let it decide, fly the Plane
## for dt seconds, and rearm it while it is parked on its own Side's Airfield. Returns the
## controls, for the Machine Gun and the bomb rack. The caller checks the crash rules afterwards.
func step(
	map: WorldMap, others: Array[PlaneState], targets: Array[GroundTarget], dt: float
) -> FlightInput:
	var input := pilot.decide(state, others, targets, dt)
	model.step(state, input, map.environment_at(state.position.x), dt)
	if not state.on_airfield:
		flown_since_refit = true
	rearm.update(state, parked_on_own_airfield(map), dt)
	return input


## True when the Plane is stopped on an Airfield of its own Side: the Rearm condition and
## the player's Return.
func parked_on_own_airfield(map: WorldMap) -> bool:
	if not state.on_airfield or state.speed > 0.0:
		return false
	var airfield := map.airfield_at(state.position.x)
	return airfield != null and airfield.side == side
