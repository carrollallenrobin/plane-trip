class_name SlotRow
extends Control
## The Slots on the Refit form: one ink box per Slot, filled for each one in use. Drawn, not
## typed, so it does not lean on a font's symbol coverage.

const BOX := 18.0
const GAP := 8.0
const LABEL := "SLOTS"
const LABEL_WIDTH := 70.0
const FONT_SIZE := 16

var used := 0
var total := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_used(in_use: int, of: int) -> void:
	used = in_use
	total = of
	queue_redraw()


func _draw() -> void:
	var font := UiTheme.TYPEWRITER
	var ascent := font.get_ascent(FONT_SIZE)
	var origin := Vector2(0.0, (size.y - FONT_SIZE) / 2.0 + ascent)
	draw_string(font, origin, LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UiPalette.INK_FADED)
	for i in total:
		var box := Rect2(LABEL_WIDTH + i * (BOX + GAP), (size.y - BOX) / 2.0, BOX, BOX)
		if i < used:
			draw_rect(box, UiPalette.INK)
		else:
			draw_rect(box, UiPalette.INK, false, 1.5)
