class_name Stamp
extends Control
## A Stamp: a red rubber-stamp mark on a Sheet, a word in a ruled box set at an angle, its
## ink worn by a shader. It can lie on the paper from the start (a mission's COMPLETE on its
## card) or slam down (the Debrief's outcome), shrinking onto the paper and reporting when it
## lands so the scene can thunk and shake.

## The Stamp has landed after a slam.
signal landed

const INK_SHADER := preload("res://src/game/ui/ink.gdshader")
const SLAM_SECONDS := 0.14
const SLAM_FROM := 1.9
const RULE := 4.0
const PADDING := Vector2(18.0, 6.0)

var text := ""
var font_size := 40
var colour := UiPalette.STAMP_RED
var angle_degrees := -8.0

var _slam_pending := false


static func create(words: String, size := 40, tilt := -8.0) -> Stamp:
	var stamp := Stamp.new()
	stamp.text = words
	stamp.font_size = size
	stamp.angle_degrees = tilt
	stamp.theme = UiTheme.get_theme()
	stamp.material = ShaderMaterial.new()
	stamp.material.shader = INK_SHADER
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var extent := stamp._extent()
	stamp.custom_minimum_size = extent
	stamp.size = extent
	stamp.pivot_offset = extent / 2.0
	stamp.rotation = deg_to_rad(tilt)
	return stamp


## Come down onto the paper from above, large and faint to full size and solid. Starts once
## the Stamp is in the tree, so it can be asked for while a Sheet is being laid out.
func slam() -> void:
	scale = Vector2.ONE * SLAM_FROM
	modulate.a = 0.0
	_slam_pending = true
	if is_inside_tree():
		_slam_now()


func _ready() -> void:
	if _slam_pending:
		_slam_now()


func _slam_now() -> void:
	_slam_pending = false
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, SLAM_SECONDS).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 1.0, SLAM_SECONDS * 0.5)
	tween.chain().tween_callback(landed.emit)


func _draw() -> void:
	var font := UiTheme.STENCIL
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect.grow(-RULE / 2.0), colour, false, RULE)
	var ascent := font.get_ascent(font_size)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var origin := Vector2((size.x - text_size.x) / 2.0, (size.y - text_size.y) / 2.0 + ascent)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


func _extent() -> Vector2:
	var text_size := UiTheme.STENCIL.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return text_size + PADDING * 2.0 + Vector2.ONE * RULE * 2.0
