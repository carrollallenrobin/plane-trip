@tool
class_name AirfieldNode
extends Node3D
## Places an Airfield in the world. The node's position is the start of the runway at
## surface height; the runway extends length metres toward +x.

const RUNWAY_COLOR := Color(0.3, 0.3, 0.3)
## How far the runway's top stands above the surface: visible, under a plane's wheels.
const RUNWAY_PROUD := 0.1

@export_enum("Red", "Blue") var side: int = Side.BLUE:
	set(value):
		side = value
		_rebuild()
@export var length := 80.0:
	set(value):
		length = value
		_rebuild()
## Planes take off and land toward +x when true, toward -x otherwise.
@export var heading_right := true:
	set(value):
		heading_right = value
		_rebuild()

var _runway: MeshInstance3D
var _flag: MeshInstance3D


func _ready() -> void:
	_rebuild()


func to_airfield() -> Airfield:
	var airfield := Airfield.create(side, position.x, position.x + length, position.y)
	airfield.heading_right = heading_right
	return airfield


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _runway == null:
		_runway = MeshInstance3D.new()
		add_child(_runway)
		_flag = MeshInstance3D.new()
		add_child(_flag)
	var runway := BoxMesh.new()
	runway.size = Vector3(length, 0.4, 14.0)
	runway.material = _material(RUNWAY_COLOR)
	_runway.mesh = runway
	# The top stands RUNWAY_PROUD above the surface. Flush with the slab's top face it is
	# lost to the depth buffer; it only used to show because the buffer was too coarse.
	_runway.position = Vector3(length / 2.0, RUNWAY_PROUD - runway.size.y / 2.0, 0.0)
	var flag := BoxMesh.new()
	flag.size = Vector3(1.0, 6.0, 1.0)
	flag.material = _material(Side.colour(side))
	_flag.mesh = flag
	# The flag stands at the take-off end.
	_flag.position = Vector3(-2.0 if heading_right else length + 2.0, 3.0, 0.0)


static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	return material
