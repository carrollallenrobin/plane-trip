class_name MissionDefinition
extends Resource
## What a Mission is, apart from its World: its objectives, the player's stock of planes,
## what each Side's Hangar sends up and how fast. Edited in the inspector on the mission
## scene's World node.

@export var title := "Mission"
@export_multiline var briefing := ""
@export var objectives: Array[Objective] = []
## How many planes the player has in total.
@export var player_planes := 3
## How many planes the enemy Hangar can send up in total; 0 means as many as it likes.
@export var enemy_pool := 3
## How many planes the enemy keeps Aloft at once.
@export var enemy_aloft := 1
## What the enemy's planes carry, a preset from data/loadouts/ per Aloft slot: a replacement
## flies what the Plane it replaces flew. A shorter list repeats its last entry; left empty,
## they carry what the player does.
@export var enemy_loadouts: Array[Loadout] = []
## How many Wingmen, AI planes on the player's side from the Home Airfield's Hangar, are
## kept Aloft at once. None by default.
@export var wingmen_aloft := 0
## How many Wingmen the Hangar can send up in total; 0 means as many as it likes.
@export var wingmen_pool := 0
## What the Wingmen carry, per Aloft slot, as for the enemy.
@export var wingmen_loadouts: Array[Loadout] = []
## Seconds between two launches on the same side, so planes do not leave a Hangar in a clump.
@export var spawn_interval := 0.0
## Seconds after the start before the first launch on either side, so the player is not
## caught on the runway.
@export var first_launch_delay := 0.0
