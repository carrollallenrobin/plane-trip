class_name LoadingScreen
extends MenuScreen
## The first thing on screen: a Sheet saying what is being readied while the game compiles
## its shaders and builds the airfield behind the title. On the web every shader program
## compiles on the main thread, so without this the engine's own loader sat at 100 percent
## for the whole wait. The Stamp on it compiles the ink shader; the Sheet, the paper's; the
## plane turning on it, drawn through the Refit's own viewport, readies that viewport too.

const BAR_SIZE := Vector2(420.0, 16.0)

var _stage: Label
var _bar: LoadingBar
var _plane_holder: CenterContainer


static func create(ui_sounds: UiSounds) -> LoadingScreen:
	var screen := LoadingScreen.new(ui_sounds, 30, 1.0)
	screen.name = "Loading"
	screen.small("OPERATIONS HUT")
	screen.stamp("READYING", false)
	screen._plane_holder = CenterContainer.new()
	screen._plane_holder.custom_minimum_size = PlaneViewport.SIZE
	screen._column.add_child(screen._plane_holder)
	screen.gap(4.0)
	screen._stage = Label.new()
	screen._stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen._stage.custom_minimum_size = Vector2(BAR_SIZE.x, 0.0)
	screen._column.add_child(screen._stage)
	screen._bar = LoadingBar.new()
	screen._bar.custom_minimum_size = BAR_SIZE
	screen._column.add_child(screen._bar)
	return screen


## Put the Game's plane picture on the Sheet: a frame after the Sheet first drew, so the
## engine's own loader does not wait for the viewport's first draw too.
func add_plane(picture: PlaneViewport) -> void:
	picture.move_to(_plane_holder)


## Say what is being readied and how far along it is, in [0, 1].
func set_stage(text: String, share: float) -> void:
	_stage.text = text
	_bar.show_share(share)


## A ruled box filling with ink, left to right.
class LoadingBar:
	extends Control

	var share := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_share(now: float) -> void:
		share = clampf(now, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, UiPalette.INK, false, 1.5)
		var inner := rect.grow(-3.0)
		inner.size.x *= share
		if inner.size.x > 0.0:
			draw_rect(inner, UiPalette.INK)
