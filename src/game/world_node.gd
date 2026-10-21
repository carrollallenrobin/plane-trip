class_name WorldNode
extends Node3D
## The rendering of a World (ADR 0001): reads the terrain, airfields and ground targets placed
## as children into a World Map and Ground Targets, builds the World, steps it once per
## physics tick, keeps a plane node per Plane, and plays what the Picture says its events are
## felt as: effects, camera shake and sounds on the SoundStage. The simulation itself is in
## World and how it is felt is in Picture; nothing here decides anything. Deterministic:
## everything advances in step(), so tests drive it directly.

## The mission ended: WON or LOST (MissionRules.Outcome).
signal mission_ended(outcome: MissionRules.Outcome)
## The player's Plane is ready for a Refit: spawned, or stopped at home after a sortie.
signal refit_due

## Horizontal extent of the world. The Borders are at 0 and width.
@export var width := 960.0
## Height of the Ceiling.
@export var ceiling_y := 160.0
## Which Side the player flies for.
@export_enum("Red", "Blue") var player_side: int = Side.BLUE
## Seconds between a plane's end and the next one appearing. Original: about 1.8 s.
@export var respawn_delay := 1.8
## Random seed for damage rolls, Debris and gunners.
@export var seed_value := 1
## Flight tuning given to every plane. Null means the defaults.
@export var flight_tuning: FlightTuning
@export var airframe: Airframe
## The mission: objectives, plane stock, enemy pool. Null means a free-flight world.
@export var mission: MissionDefinition

## The simulation. The Instrument Panel, the camera and the Debrief read it; only step()
## advances it.
var world: World

var _plane_nodes: Dictionary = {}  # WorldPlane -> PlaneNode
var _target_nodes: Dictionary = {}  # name -> GroundTargetNode
## Plays the Picture's sound Cues where they happen.
var _stage: SoundStage
## How the World is felt (ADR 0007): it owns the effects pools and the camera shake.
var _picture: Picture
## Draws the Picture's pools.
var _effects: EffectsNode

@onready var _camera: FollowCamera = $Camera
@onready var _overlay: DebugOverlay = $DebugOverlay
@onready var _projectiles: ProjectilesNode = $Projectiles
@onready var _instruments: InstrumentPanel = get_node_or_null("InstrumentPanel")
@onready var _backdrop: BackdropNode = get_node_or_null("Backdrop")
@onready var _sun: DirectionalLight3D = get_node_or_null("Sun")


func _ready() -> void:
	WebTuning.tune_sun(_sun)
	var map := _build_map()
	world = World.create(
		map,
		_collect_targets(map),
		mission,
		flight_tuning,
		player_side,
		seed_value,
		respawn_delay,
		airframe
	)
	for name in world.rules.unresolved_target_names(world.targets):
		push_warning("Objective names a Ground Target '%s' that this World does not have" % name)
	_stage = SoundStage.new()
	_stage.name = "SoundStage"
	add_child(_stage)
	var player_node := _find_player_node()
	if player_node != null:
		var loadout := player_node.loadout if player_node.loadout != null else Loadout.new()
		_bind(player_node, world.add_player(loadout, PlayerPilot.new()))
	_picture = Picture.new(seed_value, world.player)
	_effects = EffectsNode.create(_picture.plan)
	add_child(_effects)
	_camera.target = world.player
	_camera.bounds = map.bounds
	_camera.shake = _picture.shake
	if _backdrop != null:
		_backdrop.fit(map.bounds, _camera.position.z, _camera.view_half_size(), map.terrain)
	_overlay.world = world
	if _instruments != null:
		_instruments.world = world


func _physics_process(dt: float) -> void:
	step(dt)


## Whether the World advances with the physics clock. Held at the start of a Mission while
## the player reads the briefing; stepping by hand still works.
func set_running(value: bool) -> void:
	set_physics_process(value)


## Advance the World by dt seconds and bring the scene up to date with it: nodes appear and
## go with the events, then the Picture says how the step is felt, and the nodes follow.
func step(dt: float) -> void:
	var events := world.step(dt)
	for event in events:
		_on_event(event)
	for cue in _picture.step(events, world.planes, world.guns.shells, dt, world.combat.bombs):
		_play(cue)
	_stage.whistle(_picture.whistles)
	for plane in _plane_nodes:
		var node: PlaneNode = _plane_nodes[plane]
		var heard := (
			_picture.volume_from(plane.state.position) if plane.state != null else Picture.SILENT_DB
		)
		node.refresh(dt, heard)
	_projectiles.show_in_flight(
		world.combat.bullets, world.combat.bombs, world.guns.shells, world.debris
	)


func set_instruments_visible(value: bool) -> void:
	if _instruments != null:
		_instruments.visible = value


## Whether the keys fly the player's Plane; off while a screen owns them.
func set_player_input_enabled(value: bool) -> void:
	if world.player != null and world.player.pilot is PlayerPilot:
		world.player.pilot.enabled = value


## The nodes the World's objects have: a plane node per Plane while it is in the World, a
## Ground Target shown fallen, the Mission's end passed on. How the event is felt is the
## Picture's business.
func _on_event(event: WorldEvent) -> void:
	match event.kind:
		WorldEvent.Kind.PLANE_SPAWNED:
			if not _plane_nodes.has(event.plane):
				_add_plane_node(event.plane)
		WorldEvent.Kind.PLANE_DESTROYED:
			if event.plane != world.player:
				var node: PlaneNode = _plane_nodes[event.plane]
				_plane_nodes.erase(event.plane)
				node.queue_free()
		WorldEvent.Kind.TARGET_DESTROYED:
			var target_node: GroundTargetNode = _target_nodes.get(event.target.name)
			if target_node != null:
				target_node.show_destroyed()
		WorldEvent.Kind.MISSION_ENDED:
			if _instruments != null:
				_instruments.show_outcome(event.outcome)
			mission_ended.emit(event.outcome)
		WorldEvent.Kind.REFIT_DUE:
			refit_due.emit()


## Read the static layout out of the child nodes.
func _build_map() -> WorldMap:
	var result := WorldMap.new()
	result.bounds = WorldBounds.create(width, ceiling_y)
	for child in get_children():
		if child is TerrainNode:
			result.terrain = child.to_terrain()
		elif child is AirfieldNode:
			result.airfields.append(child.to_airfield())
	return result


## Ground targets stand on the terrain whatever height they were placed at.
func _collect_targets(map: WorldMap) -> Array[GroundTarget]:
	var targets: Array[GroundTarget] = []
	for child in get_children():
		if child is GroundTargetNode:
			child.position.y = map.terrain.height_at(child.position.x)
			var target: GroundTarget = child.to_target()
			targets.append(target)
			_target_nodes[target.name] = child
	return targets


## The plane node placed in the scene for the player's Side, if any.
func _find_player_node() -> PlaneNode:
	for child in get_children():
		if child is PlaneNode and child.side == player_side:
			return child
	return null


func _add_plane_node(plane: WorldPlane) -> void:
	var node := PlaneNode.new()
	node.name = "Plane%d" % plane.state.id
	_bind(node, plane)
	add_child(node)


func _bind(node: PlaneNode, plane: WorldPlane) -> void:
	node.bind(plane)
	_plane_nodes[plane] = node


## Play a Cue from the Picture. A Plane's node may already be gone when its Cue arrives, if it
## was hit and destroyed in the same step.
func _play(cue: Picture.Cue) -> void:
	match cue.kind:
		Picture.Cue.Kind.HIT_FLASH:
			var node: PlaneNode = _plane_nodes.get(cue.plane)
			if node != null:
				node.flash()
		_:
			_stage.play(cue)
