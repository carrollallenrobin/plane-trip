class_name ObjectiveSlip
extends Control
## The objective list in flight: a cream slip pinned at the top left, one typed entry per
## objective with an ink box before it, ticked red when complete and crossed red when
## failed. Dark ink on paper reads over sky, ground and smoke alike. The slip has a fixed
## width: words that do not fit wrap onto further lines under the first, past the box, and
## the slip grows a line for each.

const WIDTH := 330.0
const PADDING := Vector2(16.0, 14.0)
const LINE_HEIGHT := 27.0
const BOX := 15.0
const FONT_SIZE := 18
const TILT_DEGREES := -1.2
const PIN_RADIUS := 5.0
## Where the words start, after the box and a gap.
const TEXT_X := PADDING.x + BOX + 10.0
const TEXT_WIDTH := WIDTH - TEXT_X - PADDING.x

var statuses: Array[ObjectiveStatus] = []

## The words of each entry, shaped and wrapped to the slip's width, in the statuses' order.
var _paragraphs: Array[TextParagraph] = []
## What the paragraphs were shaped from, so the Panel can feed the slip every frame and
## nothing is reshaped or redrawn until the words or a status change.
var _shown: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotation = deg_to_rad(TILT_DEGREES)


## Show these objectives as they stand.
func show_statuses(now: Array[ObjectiveStatus]) -> void:
	var shown := []
	for entry in now:
		shown.append([MissionText.objective_line(entry), entry.status])
	if shown == _shown:
		return
	_shown = shown
	statuses = now
	visible = not now.is_empty()
	_paragraphs.clear()
	var lines := 0
	for entry in now:
		var paragraph := _shape(MissionText.objective_line(entry))
		_paragraphs.append(paragraph)
		lines += paragraph.get_line_count()
	size = Vector2(WIDTH, PADDING.y * 2.0 + LINE_HEIGHT * lines)
	queue_redraw()


## How many lines the slip shows: an entry takes one per wrapped line.
func line_count() -> int:
	var lines := 0
	for paragraph in _paragraphs:
		lines += paragraph.get_line_count()
	return lines


static func _shape(text: String) -> TextParagraph:
	var paragraph := TextParagraph.new()
	paragraph.width = TEXT_WIDTH
	paragraph.break_flags = TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY
	paragraph.add_string(text, UiTheme.TYPEWRITER, FONT_SIZE)
	return paragraph


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(
		Rect2(rect.position + Vector2(4.0, 6.0), rect.size).grow(2.0), Color(0.0, 0.0, 0.0, 0.35)
	)
	draw_rect(rect, UiPalette.CREAM)
	draw_rect(rect, UiPalette.CREAM_SHADE, false, 1.0)
	draw_circle(Vector2(size.x / 2.0, 7.0), PIN_RADIUS, UiPalette.STAMP_RED)
	draw_circle(Vector2(size.x / 2.0 - 1.5, 5.5), PIN_RADIUS * 0.4, Color(1.0, 0.7, 0.65))
	var ascent := UiTheme.TYPEWRITER.get_ascent(FONT_SIZE)
	var top := PADDING.y
	for i in statuses.size():
		var box := Rect2(PADDING.x, top + (LINE_HEIGHT - BOX) / 2.0, BOX, BOX)
		draw_rect(box, UiPalette.INK, false, 1.5)
		_draw_mark(box, statuses[i].status)
		var colour := UiPalette.INK
		if statuses[i].status != MissionRules.Status.OPEN:
			colour = UiPalette.INK_FADED
		var paragraph := _paragraphs[i]
		for line in paragraph.get_line_count():
			# A TextParagraph draws a line from its top, not its baseline, so the gap above
			# is the row's slack above the font's size, as before, less the ascent's share.
			var line_top := top + (LINE_HEIGHT - FONT_SIZE) / 2.0 + ascent
			line_top -= paragraph.get_line_ascent(line)
			paragraph.draw_line(get_canvas_item(), Vector2(TEXT_X, line_top), line, colour)
			top += LINE_HEIGHT


func _draw_mark(box: Rect2, status: MissionRules.Status) -> void:
	match status:
		MissionRules.Status.COMPLETE:
			var tick := PackedVector2Array(
				[
					box.position + Vector2(2.0, box.size.y * 0.55),
					box.position + Vector2(box.size.x * 0.4, box.size.y - 1.0),
					box.position + Vector2(box.size.x + 3.0, -3.0),
				]
			)
			draw_polyline(tick, UiPalette.STAMP_RED, 2.5)
		MissionRules.Status.FAILED:
			draw_line(box.position, box.end, UiPalette.STAMP_RED, 2.5)
			draw_line(
				Vector2(box.end.x, box.position.y),
				Vector2(box.position.x, box.end.y),
				UiPalette.STAMP_RED,
				2.5
			)
