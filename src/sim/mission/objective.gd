class_name Objective
extends Resource
## A single condition a Mission tracks: Destroy a target, Protect a target, Return to the
## Home Airfield, or Shoot Down a number of enemy Planes. Required objectives decide the
## mission; optional ones are extra credit.

enum Kind { DESTROY, PROTECT, RETURN, SHOOT_DOWN }

@export var kind := Kind.DESTROY
## Name of the Ground Target node this refers to. Unused for Return and Shoot Down.
@export var target_name := ""
## How many enemy Planes the player must shoot down. Only for Shoot Down.
@export var count := 1
@export var required := true
## Shown in the objective list.
@export var title := ""


## The title as shown: the authored one, or one made from the kind and the target.
func display_title() -> String:
	if not title.is_empty():
		return title
	match kind:
		Kind.DESTROY:
			return "Destroy " + target_name
		Kind.PROTECT:
			return "Protect " + target_name
		Kind.SHOOT_DOWN:
			return "Shoot down %d %s" % [count, "plane" if count == 1 else "planes"]
	return "Return home"


static func create(objective_kind: Kind, name := "", is_required := true, label := "") -> Objective:
	var objective := Objective.new()
	objective.kind = objective_kind
	objective.target_name = name
	objective.required = is_required
	objective.title = label
	return objective


static func shoot_down(planes: int, is_required := true, label := "") -> Objective:
	var objective := create(Kind.SHOOT_DOWN, "", is_required, label)
	objective.count = planes
	return objective
