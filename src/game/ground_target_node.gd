@tool
class_name GroundTargetNode
extends Node3D
## Places a Ground Target in the world and shows its model, or the ruin once it is destroyed.
## The node's position is the centre of its base on the terrain. Objectives refer to the
## target by this node's name.

## The built models (ADR 0005) by kind, and the ruin every kind leaves.
const MODELS := {
	GroundTarget.Kind.BUILDING: preload("res://assets/models/building.glb"),
	GroundTarget.Kind.ANTI_AIRCRAFT_GUN: preload("res://assets/models/aa_gun.glb"),
	GroundTarget.Kind.FLAK_GUN: preload("res://assets/models/flak_gun.glb"),
	GroundTarget.Kind.HANGAR: preload("res://assets/models/hangar.glb"),
}
const RUIN := preload("res://assets/models/ruin.glb")
## Width and height each model is built at; a node scales its model to its own size.
## Buildings stretch to width and height; guns scale uniformly to height, so they keep their
## shape; the ruin stretches to width only. Mirrored in the art/models/ scripts.
const MODEL_SIZES := {
	GroundTarget.Kind.BUILDING: Vector2(12.0, 6.0),
	GroundTarget.Kind.ANTI_AIRCRAFT_GUN: Vector2(6.0, 4.0),
	GroundTarget.Kind.FLAK_GUN: Vector2(6.0, 4.0),
	GroundTarget.Kind.HANGAR: Vector2(16.0, 7.0),
}
const RUIN_WIDTH := 12.0

@export_enum("Building", "Anti-Aircraft Gun", "Flak Gun", "Hangar") var kind: int = 0:
	set(value):
		kind = value
		_rebuild()
@export_enum("Red", "Blue") var side: int = Side.RED:
	set(value):
		side = value
		_rebuild()
@export var width := 10.0:
	set(value):
		width = value
		_rebuild()
@export var height := 6.0:
	set(value):
		height = value
		_rebuild()

## The model on show: the kind's, or the ruin.
var model: SideModel
var _destroyed := false


func _ready() -> void:
	_rebuild()


func to_target() -> GroundTarget:
	return GroundTarget.create(
		name, side, kind as GroundTarget.Kind, Vector2(position.x, position.y), width, height
	)


## Swap the model for a ruin.
func show_destroyed() -> void:
	_destroyed = true
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if model != null:
		model.queue_free()
	if _destroyed:
		model = SideModel.create(RUIN, side)
		model.scale = Vector3(width / RUIN_WIDTH, 1.0, 1.0)
	else:
		model = SideModel.create(MODELS[kind], side)
		model.scale = _model_scale()
	add_child(model)


func _model_scale() -> Vector3:
	var built: Vector2 = MODEL_SIZES[kind]
	match kind:
		GroundTarget.Kind.ANTI_AIRCRAFT_GUN, GroundTarget.Kind.FLAK_GUN:
			return Vector3.ONE * (height / built.y)
		_:
			return Vector3(width / built.x, height / built.y, 1.0)
