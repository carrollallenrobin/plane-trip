class_name ObjectiveStatus
extends RefCounted
## One Objective and how it stands right now, for the HUD and the Debrief to show.

var objective: Objective
var status := MissionRules.Status.OPEN
## How far a Shoot Down objective has come: the player's kills so far.
var tally := 0


static func create(of: Objective, now: MissionRules.Status, so_far := 0) -> ObjectiveStatus:
	var result := ObjectiveStatus.new()
	result.objective = of
	result.status = now
	result.tally = so_far
	return result
