class_name SideModel
extends Node3D
## One instance of a built model (ADR 0005) with its own copies of the model's materials, so
## it can wear a Side's colour and flash on a hit without touching other instances. The
## material named SIDE_MATERIAL takes the Side's colour; the rest keep the model's colours.
##
## Every material has emission on from the start, of black, which adds nothing; the flash
## only turns that colour white. A material feature toggled at runtime would mean another
## shader program, which the web build compiles slowly and Godot frees again when the last
## user leaves it, so the flash was a freeze on every hit. A colour is a uniform.

const SIDE_MATERIAL := "Side"
const FLASH_COLOUR := Color.WHITE
const NO_FLASH_COLOUR := Color.BLACK

## This instance's materials, one per mesh surface.
var materials: Array[StandardMaterial3D] = []

var _side_materials: Array[StandardMaterial3D] = []
var _flashing := false


## Instantiate the model under a new SideModel painted for the Side.
static func create(model: PackedScene, side: int) -> SideModel:
	var node := SideModel.new()
	var instance: Node3D = model.instantiate()
	node.add_child(instance)
	node._copy_materials(instance)
	node.paint(side)
	return node


## Paint the Side material in the Side's colour.
func paint(side: int) -> void:
	for material in _side_materials:
		material.albedo_color = Side.colour(side)


## Light every surface white, or stop.
func set_flashing(flashing: bool) -> void:
	if flashing == _flashing:
		return
	_flashing = flashing
	for material in materials:
		material.emission = FLASH_COLOUR if flashing else NO_FLASH_COLOUR


## A named node of the model, such as a part that moves.
func part(part_name: String) -> Node3D:
	return find_child(part_name, true, false)


## Whether the body is lit white.
func is_flashing() -> bool:
	return _flashing


func _copy_materials(instance: Node3D) -> void:
	for child in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = child
		for surface in mesh_instance.mesh.get_surface_count():
			var material: StandardMaterial3D = (
				mesh_instance.mesh.surface_get_material(surface).duplicate()
			)
			material.emission_enabled = true
			material.emission = NO_FLASH_COLOUR
			mesh_instance.set_surface_override_material(surface, material)
			materials.append(material)
			if material.resource_name == SIDE_MATERIAL:
				_side_materials.append(material)
