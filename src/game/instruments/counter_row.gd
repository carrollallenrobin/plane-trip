class_name CounterRow
extends Control
## A row of silhouettes on the Instrument Panel: one per thing held, with the empty places
## drawn faint when there is a capacity, so bombs dropped leave gaps and planes lost leave
## none. The icon is an SVG from art/ui (ADR 0008). A row that would run off the plate
## shrinks its icons to fit.

const ICON_HEIGHT := 22.0
const GAP := 3.0
const LABEL_WIDTH := 54.0

var icon: Texture2D
var count := 0
var capacity := 0

var _label: Label


static func create(name_text: String, image: Texture2D) -> CounterRow:
	var row := CounterRow.new()
	row.icon = image
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(LABEL_WIDTH, ICON_HEIGHT)
	row._label = Label.new()
	row._label.theme_type_variation = "Dial"
	row._label.text = name_text
	row._label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row._label.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	row._label.offset_right = LABEL_WIDTH
	row.add_child(row._label)
	return row


## Show this many of a capacity (0 for none: only what is held is drawn).
func show_count(held: int, of: int = 0) -> void:
	if held == count and of == capacity:
		return
	count = held
	capacity = of
	queue_redraw()


func _draw() -> void:
	if icon == null:
		return
	var places := maxi(count, capacity)
	var icon_size := icon.get_size() * (ICON_HEIGHT / icon.get_size().y)
	var step := icon_size.x + GAP
	var room := size.x - LABEL_WIDTH
	if places > 0 and places * step > room:
		var shrink := room / (places * step)
		icon_size *= shrink
		step *= shrink
	for i in places:
		var x := LABEL_WIDTH + i * step
		var rect := Rect2(Vector2(x, (size.y - icon_size.y) / 2.0), icon_size)
		var tint := Color.WHITE if i < count else Color(1.0, 1.0, 1.0, 0.22)
		draw_texture_rect(icon, rect, false, tint)
