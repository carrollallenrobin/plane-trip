class_name Sheet
extends PanelContainer
## A Sheet: the paper a menu is laid on. Cream with a soft shadow, a little tilted as if
## dropped on a desk, paper grain over everything on it. Its one child is the column of
## content; the grain is drawn on top by a shader (ADR 0008), edge to edge: the container
## would fit it inside the padding, so it is stretched back out after every sort.

const PAPER_SHADER := preload("res://src/game/ui/paper.gdshader")

## Degrees the Sheet lies off square.
var tilt := 1.2

var _grain: ColorRect


func _init(padding := 28, tilt_degrees := 1.2) -> void:
	tilt = tilt_degrees
	theme = UiTheme.get_theme()
	add_theme_stylebox_override("panel", UiTheme.sheet_box(padding))
	resized.connect(_on_resized)
	sort_children.connect(_cover_with_grain)
	_grain = ColorRect.new()
	_grain.name = "Grain"
	_grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grain.material = ShaderMaterial.new()
	_grain.material.shader = PAPER_SHADER
	add_child(_grain)


## Put the content on the Sheet, under the grain.
func lay(content: Control) -> void:
	add_child(content)
	move_child(_grain, get_child_count() - 1)


## A knock, as from a Stamp landing: the paper twists a touch and settles.
func jolt() -> void:
	var rest := deg_to_rad(tilt)
	rotation = rest + deg_to_rad(1.4)
	scale = Vector2.ONE * 1.015
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "rotation", rest, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD)


func _on_resized() -> void:
	pivot_offset = size / 2.0
	rotation = deg_to_rad(tilt)


func _cover_with_grain() -> void:
	_grain.position = Vector2.ZERO
	_grain.size = size
