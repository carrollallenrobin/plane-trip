class_name Settings
extends RefCounted
## What the player has set, saved locally: for now, whether the sound is off. Lives in the
## user directory as a ConfigFile; the path is a parameter so tests can use their own.

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "sound"

var path := DEFAULT_PATH
var muted := false


static func load_from(file_path := DEFAULT_PATH) -> Settings:
	var settings := Settings.new()
	settings.path = file_path
	var file := ConfigFile.new()
	if file.load(file_path) == OK:
		settings.muted = bool(file.get_value(SECTION, "muted", false))
	return settings


func save() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "muted", muted)
	if file.save(path) != OK:
		push_warning("Could not save settings to %s" % path)


## Flip the sound and remember it.
func toggle_muted() -> void:
	muted = not muted
	save()
