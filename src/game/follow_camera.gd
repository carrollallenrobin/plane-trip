class_name FollowCamera
extends Camera3D
## Follows a plane with lookahead in its direction of travel, at a fixed distance, clamped so
## the view never leaves the World, and shaken by what happens near it. Perspective with a
## narrow field of view so the scene reads nearly flat but background layers still drift
## (ADR 0001).

## How many seconds of travel to look ahead.
@export var lookahead_seconds := 0.6
## How quickly the lookahead settles, per second.
@export var smoothing := 3.0
## The view's top stays this far under the Ceiling, so a plane can climb a little past the
## top of the screen before the Ceiling takes it.
@export var headroom := 12.0

var target: WorldPlane
var bounds: WorldBounds
## The Picture's shake, advanced in WorldNode.step; the camera only applies it on top of
## the follow.
var shake := CameraShake.new()

var _lookahead := Vector2.ZERO


func _ready() -> void:
	projection = PROJECTION_PERSPECTIVE


func _physics_process(dt: float) -> void:
	if target == null or target.state == null:
		return
	var state := target.state
	var wanted := state.nose() * state.speed * lookahead_seconds
	_lookahead = _lookahead.lerp(wanted, clampf(smoothing * dt, 0.0, 1.0))
	var centre := state.position + _lookahead
	if bounds != null:
		var half := view_half_size()
		centre.x = clampf(centre.x, half.x, maxf(half.x, bounds.width - half.x))
		centre.y = clampf(centre.y, half.y, maxf(half.y, bounds.ceiling_y - headroom - half.y))
	var offset := shake.offset()
	position = Vector3(centre.x + offset.x, centre.y + offset.y, position.z)
	rotation = Vector3(0.0, 0.0, shake.roll())


## Half the width and height of the world slice visible at z = 0, in metres.
func view_half_size() -> Vector2:
	var aspect := (
		get_viewport().get_visible_rect().size.aspect() if is_inside_tree() else 16.0 / 9.0
	)
	var half_height := position.z * tan(deg_to_rad(fov) / 2.0)
	return Vector2(half_height * aspect, half_height)
