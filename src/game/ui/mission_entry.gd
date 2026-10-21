class_name MissionEntry
extends Resource
## One line of the mission list: which scene to load, and the mission it plays, whose title
## and briefing the list shows. The scene's World node carries the same MissionDefinition.

@export var id := ""
@export var scene: PackedScene
@export var mission: MissionDefinition
