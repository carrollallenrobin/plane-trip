class_name Dial
extends Control
## One round dial on the Instrument Panel: a face from art/ui (ADR 0008), a brass needle
## eased by a Needle, a small label under it and a warning lamp that lights steadily while
## the value is in the red. Sweeps 270 degrees from bottom-left (empty) over the top to
## bottom-right (full).

const FACE := preload("res://art/ui/dial_face.svg")
const FACE_SIZE := 84.0
const LABEL_HEIGHT := 18.0
const SWEEP_START := 135.0
const SWEEP := 270.0
const NEEDLE_LENGTH := 32.0
const NEEDLE_TAIL := 8.0
const NEEDLE_WIDTH := 3.0
const HUB_RADIUS := 5.0
const LAMP_RADIUS := 5.0
## Below this share of full the lamp lights; negative means no lamp.
var warn_below := 0.2
var title := ""

var needle := Needle.at(1.0)
## The value the needle is heading for, in [0, 1].
var value := 1.0
var lit := false

var _label: Label


static func create(name_text: String, warn := 0.2) -> Dial:
	var dial := Dial.new()
	dial.title = name_text
	dial.warn_below = warn
	dial.custom_minimum_size = Vector2(FACE_SIZE, FACE_SIZE + LABEL_HEIGHT)
	dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dial._label = Label.new()
	dial._label.theme_type_variation = "Dial"
	dial._label.text = name_text
	dial._label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dial._label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dial._label.offset_top = -LABEL_HEIGHT
	dial._label.offset_bottom = 0.0
	dial.add_child(dial._label)
	return dial


## Point the needle at a share of full; it gets there over the next frames.
func set_value(share: float) -> void:
	value = clampf(share, 0.0, 1.0)
	lit = warn_below >= 0.0 and value < warn_below


func _process(dt: float) -> void:
	needle.update(value, dt)
	queue_redraw()


## The needle's angle in degrees, clockwise from +x, for a share of full.
static func angle_for(share: float) -> float:
	return SWEEP_START + SWEEP * clampf(share, 0.0, 1.0)


func _draw() -> void:
	var centre := Vector2(FACE_SIZE / 2.0, FACE_SIZE / 2.0)
	draw_texture_rect(FACE, Rect2(Vector2.ZERO, Vector2(FACE_SIZE, FACE_SIZE)), false)
	var direction := Vector2.from_angle(deg_to_rad(angle_for(needle.shown)))
	var across := direction.orthogonal() * NEEDLE_WIDTH / 2.0
	var tip := centre + direction * NEEDLE_LENGTH
	var tail := centre - direction * NEEDLE_TAIL
	draw_colored_polygon(
		PackedVector2Array([tail + across, tail - across, tip]), UiPalette.BRASS_DARK
	)
	draw_circle(centre, HUB_RADIUS, UiPalette.BRASS)
	if warn_below >= 0.0:
		var lamp := Vector2(FACE_SIZE - LAMP_RADIUS - 1.0, LAMP_RADIUS + 1.0)
		draw_circle(lamp, LAMP_RADIUS + 1.5, UiPalette.OLIVE_DARK)
		draw_circle(lamp, LAMP_RADIUS, UiPalette.LAMP_ON if lit else UiPalette.LAMP_OFF)
