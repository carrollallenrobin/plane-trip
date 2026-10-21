class_name Boot
extends Control
## The first scene: a plain cream page with one line of type, drawn with nothing the engine
## has not already compiled, so the engine's own loader leaves after one cheap frame. Then
## the game scene and everything it reaches (fonts, sounds, models, missions) is loaded on a
## background thread with a bar that moves, and the Game takes over with its loading Sheet.

## The Game takes over.
signal started(game: Game)

const GAME_SCENE := "res://src/game/ui/game.tscn"
## The typewriter alone: one small file, no theme, no shader.
const TYPEWRITER := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const BAR_SIZE := Vector2(360.0, 10.0)

var progress := 0.0
var game: Game

var _bar: ColorRect
var _fill: ColorRect


func _ready() -> void:
	# The root's full-rect anchors are in main.tscn, so it has its size before this frame.
	var page := ColorRect.new()
	page.color = UiPalette.CREAM
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	column.add_child(_line("PLANE TRIP", 40))
	column.add_child(_line("readying the operations hut", 18))
	_bar = ColorRect.new()
	_bar.color = UiPalette.INK
	_bar.custom_minimum_size = BAR_SIZE
	column.add_child(_bar)
	_fill = ColorRect.new()
	_fill.color = UiPalette.CREAM
	_fill.position = Vector2(1.5, 1.5)
	_fill.size = BAR_SIZE - Vector2(3.0, 3.0)
	_bar.add_child(_fill)
	_load()


## One frame of the page alone, then the game on a background thread, then the Game.
func _load() -> void:
	await get_tree().process_frame
	ResourceLoader.load_threaded_request(GAME_SCENE, "", true)
	while true:
		var shares := []
		var status := ResourceLoader.load_threaded_get_status(GAME_SCENE, shares)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			push_error("The game scene did not load: %d" % status)
			return
		_show_progress(shares[0] if not shares.is_empty() else 0.0)
		await get_tree().process_frame
	_show_progress(1.0)
	var scene: PackedScene = ResourceLoader.load_threaded_get(GAME_SCENE)
	game = scene.instantiate()
	get_tree().root.add_child(game)
	started.emit(game)
	# The Game's loading Sheet draws next frame; this page goes under it, then away.
	await get_tree().process_frame
	queue_free()


func _show_progress(share: float) -> void:
	progress = clampf(share, 0.0, 1.0)
	var inner := BAR_SIZE - Vector2(3.0, 3.0)
	_fill.position = Vector2(1.5 + inner.x * progress, 1.5)
	_fill.size = Vector2(inner.x * (1.0 - progress), inner.y)


func _line(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", TYPEWRITER)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", UiPalette.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
