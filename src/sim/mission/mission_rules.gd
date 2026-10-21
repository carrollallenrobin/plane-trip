class_name MissionRules
extends RefCounted
## Decides how a Mission stands: each objective's state, and whether the mission is won,
## lost or still going. Win when every required objective is complete; lose when a Protect
## objective fails or the player's plane stock is exhausted. Pure: no nodes.

enum Outcome { ONGOING, WON, LOST }
enum Status { OPEN, COMPLETE, FAILED }

var definition: MissionDefinition


func _init(mission: MissionDefinition) -> void:
	definition = mission


## State of one objective given what the World says.
func status_of(objective: Objective, facts: MissionFacts) -> Status:
	match objective.kind:
		Objective.Kind.DESTROY:
			var target := _find(objective.target_name, facts.targets)
			return Status.COMPLETE if target != null and not target.is_alive() else Status.OPEN
		Objective.Kind.PROTECT:
			# Standing is satisfied; it only ever turns to failed.
			var target := _find(objective.target_name, facts.targets)
			return Status.FAILED if target != null and not target.is_alive() else Status.COMPLETE
		Objective.Kind.RETURN:
			return Status.COMPLETE if facts.returned and _others_complete(facts) else Status.OPEN
		Objective.Kind.SHOOT_DOWN:
			# The count by the player's own gun or Bombs, or nothing left to shoot: the enemy's
			# Hangar gone or its pool spent, with no Plane Aloft.
			var enough := facts.kills >= objective.count or facts.enemy_grounded
			return Status.COMPLETE if enough else Status.OPEN
	return Status.OPEN


## Every objective with its state, in the mission's order.
func statuses(facts: MissionFacts) -> Array[ObjectiveStatus]:
	var result: Array[ObjectiveStatus] = []
	for objective in definition.objectives:
		var tally := facts.kills if objective.kind == Objective.Kind.SHOOT_DOWN else 0
		result.append(ObjectiveStatus.create(objective, status_of(objective, facts), tally))
	return result


## The mission's outcome. `planes_lost` is how many of the player's planes are gone.
func outcome(facts: MissionFacts, planes_lost: int) -> Outcome:
	if planes_lost >= definition.player_planes:
		return Outcome.LOST
	var all_required_complete := true
	for objective in definition.objectives:
		var status := status_of(objective, facts)
		if status == Status.FAILED and objective.required:
			return Outcome.LOST
		if objective.required and status != Status.COMPLETE:
			all_required_complete = false
	if definition.objectives.is_empty():
		return Outcome.ONGOING
	return Outcome.WON if all_required_complete else Outcome.ONGOING


## Target names the objectives use that no Ground Target carries: authoring mistakes, which
## would otherwise leave a Destroy objective open and a Protect objective satisfied forever.
func unresolved_target_names(targets: Array[GroundTarget]) -> PackedStringArray:
	var missing := PackedStringArray()
	for objective in definition.objectives:
		if not _names_a_target(objective):
			continue
		if _find(objective.target_name, targets) == null and not missing.has(objective.target_name):
			missing.append(objective.target_name)
	return missing


## Planes the player has left to lose before the mission is lost.
func planes_left(planes_lost: int) -> int:
	return maxi(0, definition.player_planes - planes_lost)


static func _names_a_target(objective: Objective) -> bool:
	return objective.kind == Objective.Kind.DESTROY or objective.kind == Objective.Kind.PROTECT


## True when every required objective other than Return is complete.
func _others_complete(facts: MissionFacts) -> bool:
	for objective in definition.objectives:
		if objective.kind == Objective.Kind.RETURN or not objective.required:
			continue
		if status_of(objective, facts) != Status.COMPLETE:
			return false
	return true


static func _find(name: String, targets: Array[GroundTarget]) -> GroundTarget:
	for target in targets:
		if target.name == name:
			return target
	return null
