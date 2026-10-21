class_name MenuScreen
extends Control
## A menu on a Sheet: a heading, typed lines, a column of buttons or index cards that
## keyboard and gamepad walk with the built-in focus navigation, and a Stamp where one is
## called for. The World or the airfield behind it is dimmed. Escape or the pad's B is Back
## wherever a button was given as the back; every move ticks and every choice clacks.

signal chosen(id: String)

const COLUMN_GAP := 10
## Between the wordmark's foot and the top of the Sheet.
const WORDMARK_GAP := 120.0
const LINE_WIDTH := 560.0
const BUTTON_SIZE := Vector2(340.0, 42.0)
const CARD_SIZE := Vector2(620.0, 92.0)

## The sounds the screen plays; silent when null.
var sounds: UiSounds
## The id Escape and B choose; none when empty.
var back_id := ""
var sheet: Sheet

var _column: VBoxContainer
## Every button by its id, so a label can change while the screen is up.
var _buttons: Dictionary = {}
var _wordmark: Label
var _first_button: Button
var _settling_focus := false


func _init(ui_sounds: UiSounds = null, padding := 28, tilt := 1.2, dim := true) -> void:
	sounds = ui_sounds
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if dim:
		var veil := ColorRect.new()
		veil.name = "Veil"
		veil.color = UiPalette.DIM
		veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(veil)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	sheet = Sheet.new(padding, tilt)
	sheet.name = "Sheet"
	centre.add_child(sheet)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.add_theme_constant_override("separation", COLUMN_GAP)
	sheet.lay(_column)


## The game's name, stencilled above the Sheet rather than on it. The Sheet stays centred;
## the wordmark hangs WORDMARK_GAP above it.
func wordmark(text: String) -> MenuScreen:
	_wordmark = Label.new()
	_wordmark.name = "Wordmark"
	_wordmark.theme_type_variation = "Wordmark"
	_wordmark.text = text
	_wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wordmark)
	resized.connect(_place_wordmark)
	sheet.resized.connect(_place_wordmark)
	_wordmark.resized.connect(_place_wordmark)
	_place_wordmark()
	return self


func _place_wordmark() -> void:
	var sheet_top := size.y / 2.0 - sheet.size.y / 2.0
	_wordmark.position = Vector2(
		(size.x - _wordmark.size.x) / 2.0, sheet_top - WORDMARK_GAP - _wordmark.size.y
	)


func heading(text: String) -> MenuScreen:
	var label := Label.new()
	label.theme_type_variation = "Heading"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(label)
	return self


## A typed paragraph.
func line(text: String, width := LINE_WIDTH) -> MenuScreen:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0.0)
	_column.add_child(label)
	return self


## A small faded note.
func small(text: String) -> MenuScreen:
	var label := Label.new()
	label.theme_type_variation = "Small"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(label)
	return self


## Empty paper.
func gap(height: float) -> MenuScreen:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	_column.add_child(spacer)
	return self


## A Stamp on the paper, lying there or slammed down.
func stamp(text: String, slam := false) -> Stamp:
	var mark := Stamp.create(text, 44, -6.0)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0.0, mark.custom_minimum_size.y + 12.0)
	holder.add_child(mark)
	_column.add_child(holder)
	if slam:
		mark.slam()
		mark.landed.connect(
			func() -> void:
				if sounds != null:
					sounds.thunk()
				sheet.jolt()
		)
	return mark


## A choice. The back button is also what Escape and B choose.
func button(id: String, text: String, is_back := false) -> MenuScreen:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = BUTTON_SIZE
	_wire(control, id, is_back)
	_column.add_child(control)
	return self


## A mission's index card: its title, a note under it, and a Stamp when it is done.
func card(id: String, title: String, note: String, done: bool) -> MenuScreen:
	var control := Button.new()
	control.theme_type_variation = "Card"
	control.custom_minimum_size = CARD_SIZE
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", UiTheme.CARD_SIZE)
	head.position = Vector2(18.0, 12.0)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(head)
	var sub := Label.new()
	sub.theme_type_variation = "Small"
	sub.text = note
	sub.position = Vector2(18.0, 52.0)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(sub)
	if done:
		var mark := Stamp.create("COMPLETE", 30, -10.0)
		mark.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		mark.offset_left = -mark.custom_minimum_size.x - 24.0
		mark.offset_right = -24.0
		mark.offset_top = -mark.custom_minimum_size.y / 2.0
		mark.offset_bottom = mark.custom_minimum_size.y / 2.0
		control.add_child(mark)
	_wire(control, id, false)
	_column.add_child(control)
	return self


## Put the keys on the first choice.
func focus() -> void:
	if _first_button != null:
		_settling_focus = true
		_first_button.grab_focus()
		_settling_focus = false


func _unhandled_input(event: InputEvent) -> void:
	if back_id.is_empty() or not is_visible_in_tree():
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_choose(back_id, true)


## The label of a button already on the screen, by its id.
func button_text(id: String) -> String:
	var control: Button = _buttons.get(id)
	return control.text if control != null else ""


## Change a button's label while the screen is up.
func relabel(id: String, text: String) -> void:
	var control: Button = _buttons.get(id)
	if control != null:
		control.text = text


func _wire(control: Button, id: String, is_back: bool) -> void:
	_buttons[id] = control
	control.pressed.connect(func() -> void: _choose(id, is_back))
	control.focus_entered.connect(
		func() -> void:
			if sounds != null and not _settling_focus:
				sounds.tick()
	)
	if is_back:
		back_id = id
	if _first_button == null:
		_first_button = control


func _choose(id: String, is_back: bool) -> void:
	if sounds != null:
		if is_back:
			sounds.back()
		else:
			sounds.clack()
	chosen.emit(id)
