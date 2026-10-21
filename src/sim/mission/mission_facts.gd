class_name MissionFacts
extends RefCounted
## What the Mission's rules read of the World at one moment: the Ground Targets, whether the
## player is parked on the Home Airfield, the player's kills, and whether the enemy is
## grounded (its Hangar gone, or its pool spent, with nothing Aloft).

var targets: Array[GroundTarget] = []
var returned := false
var kills := 0
var enemy_grounded := false


static func create(
	ground_targets: Array[GroundTarget], is_returned := false, kill_count := 0, grounded := false
) -> MissionFacts:
	var facts := MissionFacts.new()
	facts.targets = ground_targets
	facts.returned = is_returned
	facts.kills = kill_count
	facts.enemy_grounded = grounded
	return facts
