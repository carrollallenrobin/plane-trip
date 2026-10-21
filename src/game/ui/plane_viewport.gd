class_name PlaneViewport
extends SubViewportContainer
## The picture of the Plane on the Refit form: the plane model, turning slowly, with one Bomb
## hung under the belly per bomb in the Loadout, so the choice can be seen. Built so more
## Fittings can hang when they have models; today only the Bomb has one. The Game makes one
## at loading and reuses it at every Refit, parked out of sight between them: a viewport
## brings a render target and a world, which the browser pays for at every new one.

const SIZE := Vector2(330.0, 230.0)
## Revolutions per second of the turntable and of the idling propeller.
const TURN_RATE := 0.05
const PROPELLER_RATE := 4.0
## Bombs hang along the belly from the release point, this far apart.
const BOMB_SPACING := 0.5
const MAX_BOMBS_SHOWN := 12

## The one World3D every PlaneViewport renders in, made at loading: a World3D brings a
## physics space and a scenario with it, which is nothing to build at every mission start.
static var _world: World3D

var side := Side.BLUE

var _viewport: SubViewport
var _turntable: Node3D
var _body: SideModel
var _propeller: Node3D
var _bombs: Array[SideModel] = []


static func create(for_side: int) -> PlaneViewport:
	var picture := PlaneViewport.new()
	picture.side = for_side
	picture.custom_minimum_size = SIZE
	picture.stretch = true
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture._viewport = SubViewport.new()
	picture._viewport.world_3d = shared_world()
	picture._viewport.transparent_bg = true
	picture._viewport.msaa_3d = Viewport.MSAA_2X
	picture.add_child(picture._viewport)
	picture._build_scene()
	return picture


## The World3D the plane pictures share, made on the first ask.
static func shared_world() -> World3D:
	if _world == null:
		_world = World3D.new()
	return _world


## Paint the plane and its bombs for a Side.
func set_side(for_side: int) -> void:
	if for_side == side:
		return
	side = for_side
	_body.paint(side)
	for bomb in _bombs:
		bomb.paint(side)


## Take the picture from wherever it is: a parent gives it up, a new one gets it.
func move_to(parent: Node) -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	parent.add_child(self)


## Hang what this Loadout carries.
func show_loadout(loadout: Loadout) -> void:
	var count := mini(loadout.bombs(), MAX_BOMBS_SHOWN)
	while _bombs.size() < count:
		var bomb := SideModel.create(ProjectilesNode.BOMB_MODEL, side)
		_body.add_child(bomb)
		_bombs.append(bomb)
	for i in _bombs.size():
		_bombs[i].visible = i < count
		var along := (i - (count - 1) / 2.0) * BOMB_SPACING
		_bombs[i].position = PlaneNode.HANGING_BOMB + Vector3(along, 0.0, 0.0)


func _process(dt: float) -> void:
	_turntable.rotate_y(TAU * TURN_RATE * dt)
	_propeller.rotate_x(TAU * PROPELLER_RATE * dt)


## A camera transform at a point looking at another; look_at needs a tree, this does not.
static func aimed(from: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(at - from, Vector3.UP), from)


func _build_scene() -> void:
	# The World's own sky for the ambient light, behind a clear background: the same Sky
	# resource, so its radiance is not rendered again, and the plane draws with the shader
	# specialisation the World already compiled.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.sky = AirfieldScene.ENVIRONMENT.sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	sun.light_energy = 1.1
	_viewport.add_child(sun)
	_turntable = Node3D.new()
	_turntable.rotation_degrees = Vector3(0.0, 25.0, 0.0)
	_viewport.add_child(_turntable)
	_body = SideModel.create(PlaneNode.MODEL, side)
	_body.rotation_degrees = Vector3(0.0, 0.0, 8.0)
	_turntable.add_child(_body)
	_propeller = _body.part(PlaneNode.PROPELLER_NODE)
	var camera := Camera3D.new()
	camera.fov = 40.0
	camera.transform = aimed(Vector3(0.0, 2.0, 16.0), Vector3(0.0, -0.4, 0.0))
	_viewport.add_child(camera)
