class_name ScreenFade
extends CanvasLayer
## The veil every change of screen comes in through: black over everything, lifted over a
## fraction of a second. The switch itself is instant, so the flow and its tests never wait;
## only the picture fades.

const SECONDS := 0.35

var _veil: ColorRect


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.color = Color(0.0, 0.0, 0.0, 0.0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)


## Drop the veil and lift it again.
func cover() -> void:
	_veil.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(_veil, "color:a", 0.0, SECONDS).set_trans(Tween.TRANS_SINE)
