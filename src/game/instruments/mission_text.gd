class_name MissionText
## The words the Instrument Panel and the Debrief put on screen for a Mission's state. Static
## and pure, so they are tested without a scene.


## The objective list as text: one line each, ticked, open or failed.
static func objective_text(statuses: Array[ObjectiveStatus]) -> String:
	var lines := PackedStringArray()
	for entry in statuses:
		lines.append("%s %s" % [mark(entry.status), objective_line(entry)])
	return "\n".join(lines)


## One objective's words, with its optional note, and for a Shoot Down still open how far
## it has come.
static func objective_line(entry: ObjectiveStatus) -> String:
	var optional := "" if entry.objective.required else " (optional)"
	var so_far := ""
	if (
		entry.objective.kind == Objective.Kind.SHOOT_DOWN
		and entry.status == MissionRules.Status.OPEN
		and entry.tally > 0
	):
		so_far = " (%d down)" % entry.tally
	return entry.objective.display_title() + so_far + optional


## The bracketed mark of a status.
static func mark(status: MissionRules.Status) -> String:
	match status:
		MissionRules.Status.COMPLETE:
			return "[x]"
		MissionRules.Status.FAILED:
			return "[!]"
	return "[ ]"


## The banner for a finished Mission.
static func outcome_text(outcome: MissionRules.Outcome) -> String:
	return "MISSION COMPLETE" if outcome == MissionRules.Outcome.WON else "MISSION FAILED"


## The Band's words when an objective turns: its title and what became of it.
static func change_text(entry: ObjectiveStatus) -> String:
	var what := "complete" if entry.status == MissionRules.Status.COMPLETE else "failed"
	return "%s %s" % [entry.objective.display_title(), what]


## A Mission's clock as minutes and seconds.
static func time_text(seconds: float) -> String:
	var whole := int(floor(maxf(seconds, 0.0)))
	return "%d:%02d" % [whole / 60, whole % 60]
