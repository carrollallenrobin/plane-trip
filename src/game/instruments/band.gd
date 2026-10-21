class_name Band
extends Control
## The Band a mission message is set on: a dark olive strip across the whole screen with
## stencilled cream words, faded in fast and out slow. Large for the outcome, smaller for an
## objective turning. Anything said while one shows replaces it.

const IN_SECONDS := 0.1
const OUT_SECONDS := 0.4
## Where the strip's centre sits, as a share of the screen's height.
const HEIGHT_SHARE := 0.36
const LARGE_HEIGHT := 124.0
const SMALL_HEIGHT := 66.0
const SMALL_FONT := 30

var _strip: ColorRect
var _label: Label
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_strip = ColorRect.new()
	_strip.color = UiPalette.BAND
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	_label = Label.new()
	_label.theme_type_variation = "Band"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_strip.add_child(_label)
	modulate.a = 0.0
	resized.connect(_place)


## Say this for a while.
func say(text: String, seconds: float, large := true) -> void:
	_label.text = text.to_upper()
	_label.remove_theme_font_size_override("font_size")
	if not large:
		_label.add_theme_font_size_override("font_size", SMALL_FONT)
	_strip.custom_minimum_size.y = LARGE_HEIGHT if large else SMALL_HEIGHT
	_place()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, IN_SECONDS)
	_tween.tween_interval(maxf(seconds - IN_SECONDS - OUT_SECONDS, 0.0))
	_tween.tween_property(self, "modulate:a", 0.0, OUT_SECONDS)


## Whether a message is on screen.
func is_showing() -> bool:
	return modulate.a > 0.0


func _place() -> void:
	var height := _strip.custom_minimum_size.y
	_strip.size = Vector2(size.x, height)
	_strip.position = Vector2(0.0, size.y * HEIGHT_SHARE - height / 2.0)
