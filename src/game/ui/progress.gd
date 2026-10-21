class_name Progress
extends RefCounted
## What the player has done, saved locally: the missions completed. Lives in the user
## directory as JSON; the path is a parameter so tests can use their own.

const DEFAULT_PATH := "user://progress.json"

var path := DEFAULT_PATH
var completed: Array[String] = []


static func load_from(file_path := DEFAULT_PATH) -> Progress:
	var progress := Progress.new()
	progress.path = file_path
	if FileAccess.file_exists(file_path):
		var file := FileAccess.open(file_path, FileAccess.READ)
		var json := JSON.new()
		if json.parse(file.get_as_text()) != OK:
			return progress
		var data: Variant = json.data
		if data is Dictionary and data.get("completed") is Array:
			for id in data["completed"]:
				progress.completed.append(str(id))
	return progress


func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save progress to %s" % path)
		return
	file.store_string(JSON.stringify({"completed": completed}))


func is_completed(mission_id: String) -> bool:
	return completed.has(mission_id)


func mark_completed(mission_id: String) -> void:
	if not completed.has(mission_id):
		completed.append(mission_id)
	save()
