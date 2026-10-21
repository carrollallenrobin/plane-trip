class_name PlaneNode
extends Node3D
## The rendering of one Plane: the plane model that follows its WorldPlane's state, the
## sounds of the engine, the airflow and the wheels (EngineVoice), the hit flash, the visual
## tumble in a Spin, the Sway, the wingtip ribbons under load and the Bomb hanging under the
## belly. Reads the simulation; never steps it. The simulation is
## 2D; this node only maps x and y onto the 3D scene (ADR 0001). A node placed in a mission scene
## is the player's: its Plane Type and Side say what the world adds.

## Built by scripts/build-models.sh from art/models/plane.py (ADR 0005).
const MODEL := preload("res://assets/models/plane.glb")
## The model's node that turns with the engine.
const PROPELLER_NODE := "Propeller"
## Propeller revolutions per second with the engine on.
const PROPELLER_RATE := 20.0
## Revolutions per second of the visual tumble in a Spin.
const SPIN_ROLL_RATE := 1.5
## Seconds the body flashes after a hit.
const HIT_FLASH := 0.08
## Every wing's tips in the body's frame, top wing first: the model's span runs along Z
## (docs/modelling.md), each wing at its height with its tips half a span out, a little
## behind the leading edge. Mirrors WINGS in art/models/plane.py.
const WINGTIPS := [
	Vector3(1.85, 2.0, 5.0),
	Vector3(1.85, 2.0, -5.0),
	Vector3(1.55, 0.75, 4.3),
	Vector3(1.55, 0.75, -4.3),
	Vector3(1.25, -0.5, 3.9),
	Vector3(1.25, -0.5, -3.9),
]
const RIBBON_COLOR := Color(1.0, 1.0, 1.0)
## Where the hanging Bomb sits in the body's frame: under the fuselage, between the wheels,
## exactly where the simulation releases from, so the falling one starts where it hung.
const HANGING_BOMB := Vector3(0.3, -AirCombat.BOMB_RELEASE_OFFSET, 0.0)

## What the player's Plane carries unless the Game says otherwise.
@export var loadout: Loadout
@export_enum("Red", "Blue") var side: int = Side.BLUE

## The Plane this node shows. The record outlives the Plane's lives, so it is bound once.
var plane: WorldPlane

var _body: SideModel
## Between the node and the body: the Sway's roll, so the body's own roll logic is untouched.
var _sway_pivot: Node3D
var _sway: Sway
var _propeller: Node3D
var _shown_state: PlaneState
var _spin_roll := 0.0
var _flash_remaining := 0.0
var _voice := EngineVoice.new()
var _engine: AudioStreamPlayer3D
var _airflow: AudioStreamPlayer3D
var _rolling: AudioStreamPlayer3D
var _ribbons: Array[Ribbon] = []
var _ribbon_meshes: Array[MeshInstance3D] = []
var _hanging_bomb: SideModel


func _ready() -> void:
	_build_body()
	_build_audio()
	_build_ribbons()
	refresh(0.0)


## Show this Plane from now on.
func bind(world_plane: WorldPlane) -> void:
	plane = world_plane
	side = plane.side
	if _body != null:
		_body.paint(side)
		refresh(0.0)


## Bring the node up to date with the Plane after the world stepped by dt seconds. `heard_db`
## is how loud this Plane is from the player's, by the Picture.
func refresh(dt: float, heard_db := 0.0) -> void:
	if plane == null or plane.state == null:
		return
	var state := plane.state
	if state != _shown_state:  # a new life
		_shown_state = state
		_spin_roll = 0.0
		_clear_ribbons()
		_sway = Sway.new(state.id)
	visible = plane.is_alive()
	if not visible:
		_update_audio(state, false, heard_db, dt)
		_clear_ribbons()
		return
	if state.in_spin:
		_spin_roll += TAU * SPIN_ROLL_RATE * dt
	if state.thrust_on:
		_propeller.rotate_x(TAU * PROPELLER_RATE * dt)
	_flash_remaining = maxf(0.0, _flash_remaining - dt)
	_apply_transform(state)
	_sway.update(state, plane.model.tuning.pitch_rate, dt)
	_sway_pivot.rotation = Vector3(_sway.bank, 0.0, 0.0)
	_update_audio(state, true, heard_db, dt)
	_update_ribbons(state, dt)
	_hanging_bomb.visible = shows_hanging_bomb(state)


## Something hit the plane: flash the body.
func flash() -> void:
	_flash_remaining = HIT_FLASH


func _exit_tree() -> void:
	# Stop looping audio so the streams are released cleanly at exit.
	for player in [_engine, _airflow, _rolling]:
		if player != null:
			player.stop()


func _apply_transform(state: PlaneState) -> void:
	position = Vector3(state.position.x, state.position.y, 0.0)
	rotation = Vector3(0.0, 0.0, deg_to_rad(state.angle))
	var roll := PI if state.upside_down else 0.0
	if state.roll_remaining > 0.0:
		var progress := 1.0 - state.roll_remaining / FlightModel.ROLL_DURATION
		roll += PI * progress * (-1.0 if state.upside_down else 1.0)
	if state.ceiling_spin_remaining > 0.0:
		# Tumble at the spin's rate; the simulation flips upside_down at the end when the
		# half-rolls come to an odd number, so the tumble lands near the new state.
		roll += PI * FlightModel.CEILING_TUMBLE_RATE * state.ceiling_spin_elapsed
	_body.rotation = Vector3(roll + _spin_roll, 0.0, 0.0)
	_body.set_flashing(_flash_remaining > 0.0)


## A Bomb hangs while there is one to drop and the last one left BOMB_INTERVAL ago, so an
## enemy's bombs left can be seen and the rack is empty for a moment after each release.
static func shows_hanging_bomb(state: PlaneState) -> bool:
	return state.bombs > 0 and state.bomb_cooldown <= 0.0


func _build_body() -> void:
	_sway_pivot = Node3D.new()
	_sway_pivot.name = "SwayPivot"
	add_child(_sway_pivot)
	_body = SideModel.create(MODEL, side)
	_sway_pivot.add_child(_body)
	_propeller = _body.part(PROPELLER_NODE)
	_hanging_bomb = SideModel.create(ProjectilesNode.BOMB_MODEL, side)
	_hanging_bomb.name = "HangingBomb"
	_hanging_bomb.position = HANGING_BOMB
	_body.add_child(_hanging_bomb)


## Two ribbons, drawn in world space (top level) since their points stay where the wingtips
## were, not where they are.
func _build_ribbons() -> void:
	for i in WINGTIPS.size():
		_ribbons.append(Ribbon.new())
		var instance := ribbon_mesh("Ribbon%d" % i)
		add_child(instance)
		_ribbon_meshes.append(instance)


## An empty ribbon: an immediate mesh in the ribbons' material.
static func ribbon_mesh(mesh_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.top_level = true
	instance.mesh = ImmediateMesh.new()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Emission of nothing, so this is the Muzzle Flash's shader rather than one more to
	# compile on the web.
	material.emission_enabled = true
	material.emission = Color.BLACK
	instance.material_override = material
	return instance


## A triangle too small to see, at a point, in a ribbon mesh: primes the ribbons' shader
## (ShaderWarmup).
static func draw_speck(mesh: ImmediateMesh, at: Vector3) -> void:
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var faint := RIBBON_COLOR
	faint.a = 0.5
	for corner in [Vector3.ZERO, Vector3(0.001, 0.0, 0.0), Vector3(0.0, 0.001, 0.0)]:
		mesh.surface_set_color(faint)
		mesh.surface_add_vertex(at + corner)
	mesh.surface_end()


func _update_ribbons(state: PlaneState, dt: float) -> void:
	var top_speed := plane.model.top_speed()
	for i in WINGTIPS.size():
		var tip: Vector3 = _body.global_transform * WINGTIPS[i]
		_ribbons[i].update(tip, state.g_load, state.speed, top_speed, dt)
		_draw_ribbon(_ribbons[i], _ribbon_meshes[i].mesh)


func _clear_ribbons() -> void:
	for i in _ribbons.size():
		_ribbons[i].clear()
		_ribbon_meshes[i].mesh.clear_surfaces()


## A strip of quads along the ribbon's points, WIDTH wide across the action plane, each
## vertex as visible as its point.
static func _draw_ribbon(ribbon: Ribbon, mesh: ImmediateMesh) -> void:
	mesh.clear_surfaces()
	var count := ribbon.points.size()
	if count < 2 or ribbon.strength <= 0.0 and ribbon.alpha_at(0) <= 0.0:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var across := Vector3.ZERO
	for i in count:
		var point := ribbon.points[i]
		across = ribbon.across_at(i, across)
		var colour := RIBBON_COLOR
		colour.a = ribbon.alpha_at(i)
		mesh.surface_set_color(colour)
		mesh.surface_add_vertex(point + across)
		mesh.surface_set_color(colour)
		mesh.surface_add_vertex(point - across)
	mesh.surface_end()


## Three loops that ride with the Plane, panned by where it is: the engine, the air over the
## airframe and the wheels on the runway.
func _build_audio() -> void:
	_engine = _loop_player("Engine", SoundBank.ENGINE)
	_airflow = _loop_player("Airflow", SoundBank.AIRFLOW)
	_rolling = _loop_player("Rolling", SoundBank.ROLLING)


func _loop_player(player_name: String, stream: AudioStreamWAV) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = player_name
	player.stream = SoundBank.loop(stream)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.volume_db = EngineVoice.SILENT_DB
	player.bus = UiSounds.WORLD_BUS
	add_child(player)
	return player


## What the Plane sounds like now: the EngineVoice decides, the Picture says how much
## quieter it is from the player's Plane, the players follow.
func _update_audio(state: PlaneState, alive: bool, heard_db: float, dt: float) -> void:
	_voice.update(state, alive, plane.model.top_speed(), dt)
	_follow(_engine, _voice.running, _voice.engine_db + heard_db, _voice.engine_pitch)
	_follow(_airflow, _voice.running, _voice.airflow_db + heard_db, _voice.airflow_pitch)
	_follow(_rolling, _voice.running, _voice.rolling_db + heard_db, _voice.rolling_pitch)


static func _follow(player: AudioStreamPlayer3D, on: bool, volume_db: float, pitch: float) -> void:
	if on and not player.playing:
		player.play()
	elif not on and player.playing:
		player.stop()
	player.volume_db = maxf(volume_db, EngineVoice.SILENT_DB)
	player.pitch_scale = pitch
