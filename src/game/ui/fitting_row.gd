class_name FittingRow
extends Button
## One line of the Refit form: a Fitting's name and how many are in the Slots. The row itself
## takes focus, so up and down walk the form and left and right change the count; A or Enter
## adds one. With the mouse, the left half of the row takes one away and the right half adds
## one. Drawn as a ruled paper line with the count between a minus and a plus.

## The count should change by this much.
signal adjusted(by: int)

const HEIGHT := 40.0
const COUNT_WIDTH := 110.0
const FONT_SIZE := 20

var fitting_name := ""
var count := 0


static func create(name_text: String) -> FittingRow:
	var row := FittingRow.new()
	row.fitting_name = name_text
	row.theme_type_variation = "Row"
	row.custom_minimum_size = Vector2(0.0, HEIGHT)
	row.focus_mode = Control.FOCUS_ALL
	return row


func show_count(now: int) -> void:
	if now == count:
		return
	count = now
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left"):
		accept_event()
		adjusted.emit(-1)
	elif event.is_action_pressed(&"ui_right"):
		accept_event()
		adjusted.emit(1)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			adjusted.emit(1 if event.position.x > size.x / 2.0 else -1)


## Enter or A on the row: one more. A click never gets here; _gui_input takes it first.
func _pressed() -> void:
	adjusted.emit(1)


func _draw() -> void:
	var font := UiTheme.TYPEWRITER
	var ascent := font.get_ascent(FONT_SIZE)
	var baseline := (size.y - FONT_SIZE) / 2.0 + ascent
	var box: StyleBox = get_theme_stylebox("normal")
	var left := box.get_margin(SIDE_LEFT)
	var right := size.x - box.get_margin(SIDE_RIGHT)
	draw_string(
		font,
		Vector2(left, baseline),
		fitting_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		FONT_SIZE,
		UiPalette.INK
	)
	var count_left := right - COUNT_WIDTH
	var hint_colour := UiPalette.INK_FADED if count > 0 else UiPalette.CREAM_SHADE
	draw_string(
		UiTheme.STENCIL,
		Vector2(count_left, baseline),
		"-",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		FONT_SIZE,
		hint_colour
	)
	draw_string(
		font,
		Vector2(count_left, baseline),
		str(count),
		HORIZONTAL_ALIGNMENT_CENTER,
		COUNT_WIDTH,
		FONT_SIZE,
		UiPalette.INK
	)
	draw_string(
		UiTheme.STENCIL,
		Vector2(count_left, baseline),
		"+",
		HORIZONTAL_ALIGNMENT_RIGHT,
		COUNT_WIDTH,
		FONT_SIZE,
		UiPalette.INK_FADED
	)
