class_name AirfieldScene
extends Node3D
## The airfield behind the title and the mission list: the player's Plane parked on the
## runway before its Hangar, the depot beyond, the Backdrop's hills and mountains behind,
## seen low from three-quarters along the runway with a slow push-in. Built from the game's
## own nodes and models; nothing here is a World, and nothing is simulated. The wind over the
## field is a generated loop on the World bus.
##
## It lives as long as the Game and only sleeps behind a mission: Godot frees a shader the
## moment its last material goes, and this scene, with the pools primed on it, is what keeps
## every material configuration a mission uses alive. Freed before the mission existed, it
## took every compiled shader with it, and the mission's first draw compiled them all again.

## The sky and the light every scene shares (data/sky.tres, data/environment.tres): one Sky
## resource, so the browser renders its radiance once, not per scene.
const ENVIRONMENT := preload("res://data/environment.tres")
const BACKDROP := preload("res://src/game/backdrop/backdrop.tscn")
const WIDTH := 600.0
const CEILING := 160.0
const SURFACE := 10.0
## The game camera's distance and view the Backdrop is laid out for.
const GAME_CAMERA_DISTANCE := 205.0
const GAME_VIEW_HALF := Vector2(80.8, 45.4)
const RUNWAY_X := 230.0
const PLANE_X := 290.0
## The plane rests tail-down at the flight model's rest pitch, wheels on the runway.
const PLANE_REST := Vector3(PLANE_X, SURFACE + 2.75, 0.0)
const PLANE_REST_PITCH := 20.0
const PROPELLER_IDLE_RATE := 3.0
## The camera's resting point and the point it looks at.
const CAMERA_AT := Vector3(PLANE_X + 24.0, SURFACE + 5.5, 30.0)
const CAMERA_LOOK := Vector3(PLANE_X - 4.0, SURFACE + 3.0, -4.0)
## The push-in: this far along the view over a cycle this long.
const PUSH_METRES := 2.5
const PUSH_PERIOD := 120.0
const AMBIENT_DB := -16.0

var _camera: Camera3D
var _propeller: Node3D
var _plane: SideModel
var _wind: AudioStreamPlayer
var _elapsed := 0.0
## The effects pools, primed at start and kept, hidden, so their materials live on.
var _priming: Array[Node] = []
var _is_priming := false


func _ready() -> void:
	_build_sky()
	var terrain := TerrainNode.new()
	terrain.name = "Terrain"
	terrain.points = PackedVector2Array([Vector2(0.0, SURFACE), Vector2(WIDTH, SURFACE)])
	add_child(terrain)
	var airfield := AirfieldNode.new()
	airfield.name = "Airfield"
	airfield.side = Side.BLUE
	airfield.position = Vector3(RUNWAY_X, SURFACE, 0.0)
	add_child(airfield)
	_place_target("Hangar", GroundTarget.Kind.HANGAR, RUNWAY_X - 14.0, Vector2(16.0, 7.0))
	_place_target("Depot", GroundTarget.Kind.BUILDING, RUNWAY_X + 110.0, Vector2(12.0, 6.0))
	_plane = SideModel.create(PlaneNode.MODEL, Side.BLUE)
	_plane.name = "Plane"
	_plane.position = PLANE_REST
	_plane.rotation_degrees = Vector3(0.0, 0.0, PLANE_REST_PITCH)
	add_child(_plane)
	_propeller = _plane.part(PlaneNode.PROPELLER_NODE)
	var backdrop: BackdropNode = BACKDROP.instantiate()
	backdrop.name = "Backdrop"
	backdrop.front_line = false
	add_child(backdrop)
	backdrop.fit(
		WorldBounds.create(WIDTH, CEILING),
		GAME_CAMERA_DISTANCE,
		GAME_VIEW_HALF,
		terrain.to_terrain()
	)
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = 32.0
	_camera.near = 1.0
	_camera.far = 5000.0
	_camera.transform = PlaneViewport.aimed(CAMERA_AT, CAMERA_LOOK)
	_camera.current = true
	add_child(_camera)
	_wind = AudioStreamPlayer.new()
	_wind.name = "Wind"
	_wind.stream = SoundBank.loop(SoundBank.WIND)
	_wind.volume_db = AMBIENT_DB
	_wind.bus = UiSounds.WORLD_BUS
	_wind.autoplay = true
	add_child(_wind)


## Out of sight behind a mission: not drawn, not processed, silent, its camera stood down
## so the mission's can take over. Everything it holds stays alive.
func sleep() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_camera.current = false
	_wind.stop()


## Back behind the menus.
func wake() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_camera.make_current()
	_wind.play()


## Draw a speck of every effect and projectile pool and flash the plane for a few frames,
## so every shader a mission uses is compiled now, under the loading Sheet, rather than at
## its first use in play (ShaderWarmup). end_priming() hides the pools; they stay, so the
## shaders stay.
func start_priming() -> void:
	var effects := EffectsNode.create(EffectsPlan.new(1))
	add_child(effects)
	effects.warm_up(_camera)
	var projectiles := ProjectilesNode.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	projectiles.warm_up(_camera)
	var ribbon := PlaneNode.ribbon_mesh("Ribbon")
	add_child(ribbon)
	_priming = [effects, projectiles, ribbon]
	_is_priming = true
	_plane.set_flashing(true)


func end_priming() -> void:
	for node in _priming:
		node.visible = false
	_is_priming = false
	_plane.set_flashing(false)


## Whether the pools are being primed.
func is_priming() -> bool:
	return _is_priming


func _process(dt: float) -> void:
	_elapsed += dt
	if _is_priming:
		var none_b: Array[Bullet] = []
		var none_bomb: Array[Bomb] = []
		var none_s: Array[Shell] = []
		var none_d: Array[Debris] = []
		_priming[1].show_in_flight(none_b, none_bomb, none_s, none_d)
		PlaneNode.draw_speck(_priming[2].mesh, ShaderWarmup.speck(_camera).origin)
	_propeller.rotate_x(TAU * PROPELLER_IDLE_RATE * dt)
	var push := (0.5 - 0.5 * cos(TAU * _elapsed / PUSH_PERIOD)) * PUSH_METRES
	var forward := (CAMERA_LOOK - CAMERA_AT).normalized()
	_camera.position = CAMERA_AT + forward * push


func _build_sky() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = ENVIRONMENT
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(
		Vector3(0.866, 0.0, -0.5),
		Vector3(-0.354, 0.707, -0.612),
		Vector3(0.354, 0.707, 0.612),
		Vector3(0.0, 100.0, 100.0)
	)
	sun.shadow_enabled = true
	WebTuning.tune_sun(sun)
	add_child(sun)


func _place_target(target_name: String, kind: GroundTarget.Kind, x: float, size: Vector2) -> void:
	var target := GroundTargetNode.new()
	target.name = target_name
	target.kind = kind
	target.side = Side.BLUE
	target.width = size.x
	target.height = size.y
	target.position = Vector3(x, SURFACE, 0.0)
	add_child(target)
