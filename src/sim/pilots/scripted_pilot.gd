class_name ScriptedPilot
extends Pilot
## A pilot that holds fixed controls. For tests and demos.

var input := FlightInput.new()


static func holding(thrust := false, up := false, down := false) -> ScriptedPilot:
	var pilot := ScriptedPilot.new()
	pilot.input.thrust = thrust
	pilot.input.pitch_up = up
	pilot.input.pitch_down = down
	return pilot


func decide(
	_state: PlaneState, _others: Array[PlaneState], _targets: Array[GroundTarget], _dt: float
) -> FlightInput:
	var copy := FlightInput.new()
	copy.thrust = input.thrust
	copy.pitch_up = input.pitch_up
	copy.pitch_down = input.pitch_down
	copy.roll = input.roll
	copy.fire = input.fire
	copy.bomb = input.bomb
	input.roll = false  # a roll is a press, not a hold
	input.bomb = false
	return copy
