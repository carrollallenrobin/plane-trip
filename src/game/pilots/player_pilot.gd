class_name PlayerPilot
extends Pilot
## The human: reads the input actions registered in the project settings. Muted while a
## screen owns the keys, so walking a menu does not fly the plane.

var enabled := true


func decide(
	_state: PlaneState, _others: Array[PlaneState], _targets: Array[GroundTarget], _dt: float
) -> FlightInput:
	var input := FlightInput.new()
	if not enabled:
		return input
	input.pitch_up = Input.is_action_pressed(&"pitch_up")
	input.pitch_down = Input.is_action_pressed(&"pitch_down")
	input.thrust = Input.is_action_pressed(&"thrust")
	input.roll = Input.is_action_just_pressed(&"roll")
	input.fire = Input.is_action_pressed(&"fire")
	input.bomb = Input.is_action_just_pressed(&"bomb")
	return input
