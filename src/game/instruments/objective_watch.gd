class_name ObjectiveWatch
extends RefCounted
## Watches the objective list for turns: an objective that was open and is now complete or
## failed gives one message for the Band. Nothing is said once the Mission has ended, since
## the outcome Band takes over then. Pure: statuses in, messages out.

var _previous: Array[MissionRules.Status] = []


## The messages for what changed since the last call. The first call sets the baseline.
func messages(statuses: Array[ObjectiveStatus], outcome: MissionRules.Outcome) -> Array[String]:
	var found: Array[String] = []
	var now: Array[MissionRules.Status] = []
	for entry in statuses:
		now.append(entry.status)
	if _previous.size() == now.size() and outcome == MissionRules.Outcome.ONGOING:
		for i in now.size():
			if now[i] != _previous[i] and now[i] != MissionRules.Status.OPEN:
				found.append(MissionText.change_text(statuses[i]))
	_previous = now
	return found
