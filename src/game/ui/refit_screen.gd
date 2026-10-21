class_name RefitScreen
extends MenuScreen
## The Refit screen as a requisition form: the mission's title and, at the start, its briefing;
## a line per Fitting that takes focus, up and down walking the lines and left and right
## changing the count (FittingRow); a row of Slot boxes filled as they are used; a typed
## readout of the Plane that results; and the Plane itself with its bombs hung, turning in a
## viewport. Fly confirms. Back is offered only at mission start. The screen owns the keys
## while it is up; the World runs on behind it, dimmed (docs/design.md, Airfields and
## rearming).

signal confirmed(loadout: Loadout)
signal cancelled

const FORM_WIDTH := 360.0
const FORM_GAP := 24

var refit: Refit

var _model: FlightModel
var _rows: Array[FittingRow] = []
var _slots: SlotRow
var _readout: Label
var _picture: PlaneViewport


static func create(
	choice: Refit,
	model: FlightModel,
	title: String,
	briefing: String,
	can_cancel: bool,
	picture: PlaneViewport = null,
	ui_sounds: UiSounds = null
) -> RefitScreen:
	var screen := RefitScreen.new(ui_sounds, 28, -0.8)
	screen.refit = choice
	screen._model = model
	screen.small("REQUISITION")
	screen.heading(title)
	if not briefing.is_empty():
		screen.line(briefing, 640.0)
	screen.gap(6.0)
	screen._form(picture)
	screen.gap(6.0)
	screen.button("fly", "Fly")
	if can_cancel:
		screen.button("back", "Back", true)
	screen.chosen.connect(
		func(id: String) -> void:
			if id == "back":
				screen.cancelled.emit()
			else:
				screen.confirmed.emit(choice.loadout())
	)
	screen._refresh()
	return screen


func adjust(index: int, by: int) -> void:
	var changed := refit.add(index) if by > 0 else refit.remove(index)
	if changed and sounds != null:
		sounds.tick()
	_refresh()


## The form's body: the Fitting lines and the readout at the left, the Plane at the right,
## in the Game's one plane picture.
func _form(picture: PlaneViewport) -> void:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", FORM_GAP)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	for i in refit.fittings.size():
		left.add_child(_row(i))
	_slots = SlotRow.new()
	_slots.custom_minimum_size = Vector2(0.0, 30.0)
	left.add_child(_slots)
	_readout = Label.new()
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_readout.custom_minimum_size = Vector2(FORM_WIDTH, 0.0)
	left.add_child(_readout)
	body.add_child(left)
	if picture != null:
		_picture = picture
		_picture.move_to(body)
	_column.add_child(body)


func _row(index: int) -> FittingRow:
	var row := FittingRow.create(refit.fittings[index].display_name)
	row.custom_minimum_size.x = FORM_WIDTH
	row.adjusted.connect(func(by: int) -> void: adjust(index, by))
	row.focus_entered.connect(
		func() -> void:
			if sounds != null and not _settling_focus:
				sounds.tick()
	)
	_rows.append(row)
	if _first_button == null:
		_first_button = row
	return row


func _refresh() -> void:
	for i in _rows.size():
		_rows[i].show_count(refit.counts[i])
	_slots.show_used(refit.slots_used(), refit.airframe.slots)
	var plane := refit.preview()
	_readout.text = (
		"Bombs %d   Rounds %d   Fuel %d s\nHull %d   Speed %d%%"
		% [
			plane.max_bombs(),
			plane.max_rounds(),
			roundi(plane.max_fuel()),
			plane.max_hit_points(),
			roundi(_model.weight_factor(plane) * 100.0)
		]
	)
	if _picture != null:
		_picture.show_loadout(refit.loadout())
