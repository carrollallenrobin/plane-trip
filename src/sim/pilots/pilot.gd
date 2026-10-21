class_name Pilot
extends RefCounted
## Whoever flies a Plane: the player or an AI. Each step the Pilot is shown its own Plane, the
## other Planes in play and the Ground Targets, and produces the controls. Adapters override
## decide(): PlayerPilot reads the input actions, AiPilot runs the ported state machine,
## ScriptedPilot holds fixed controls for tests. The World tells every Pilot the same things
## and never asks which kind it has.


## The controls for this step, given the Plane's state and what the Pilot can see.
func decide(
	_state: PlaneState, _others: Array[PlaneState], _targets: Array[GroundTarget], _dt: float
) -> FlightInput:
	return FlightInput.new()


## A new Plane is the Pilot's: the previous one is gone, and this one sits on the runway.
func start_life() -> void:
	pass
