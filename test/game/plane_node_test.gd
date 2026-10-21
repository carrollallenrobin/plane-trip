extends GdUnitTestSuite
## Headless checks that a PlaneNode shows the built plane model: the meshes are there, the
## body wears the Side's colour on the node's own copies of the materials, and the propeller
## turns with the engine. Flight itself is tested through the World.

const SCENE := "res://missions/strike_the_depot.tscn"
const DT := 1.0 / 60.0


func _scene() -> WorldNode:
	var runner := scene_runner(SCENE)
	return runner.scene()


## The model's meshes: not the ribbons, which are the node's own.
func _meshes(node: PlaneNode) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.find_children("*", "MeshInstance3D", true, false):
		if not child.name.begins_with("Ribbon"):
			found.append(child)
	return found


func _body_colours(node: PlaneNode) -> Array[Color]:
	var colours: Array[Color] = []
	for mesh_node in _meshes(node):
		var instance: MeshInstance3D = mesh_node
		for surface in instance.mesh.get_surface_count():
			var material: StandardMaterial3D = instance.get_surface_override_material(surface)
			if material.resource_name == SideModel.SIDE_MATERIAL:
				colours.append(material.albedo_color)
	return colours


func test_the_plane_carries_its_engine_airflow_and_wheels_on_the_world_bus() -> void:
	var node := _scene()
	var player_node: PlaneNode = node.get_node("Player")
	for player_name in ["Engine", "Airflow", "Rolling"]:
		var player: AudioStreamPlayer3D = player_node.get_node(player_name)
		assert_str(player.bus).is_equal(UiSounds.WORLD_BUS)
		assert_int(player.stream.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
		assert_int(player.attenuation_model).is_equal(AudioStreamPlayer3D.ATTENUATION_DISABLED)
	for i in 6:
		node.step(DT)
	var engine: AudioStreamPlayer3D = player_node.get_node("Engine")
	assert_bool(engine.playing).is_true()
	assert_float(engine.volume_db).is_equal(EngineVoice.IDLE_DB)
	assert_bool(player_node.get_node("Rolling").playing).is_true()
	assert_float(player_node.get_node("Rolling").volume_db).is_equal(EngineVoice.SILENT_DB)


func test_the_flash_is_a_colour_on_a_material_whose_shader_never_changes() -> void:
	var node := _scene()
	var player_node: PlaneNode = node.get_node("Player")
	var body: SideModel = player_node.find_child("SwayPivot", true, false).get_child(0)
	for material in body.materials:
		assert_bool(material.emission_enabled).is_true()
	body.set_flashing(true)
	assert_bool(body.is_flashing()).is_true()
	for material in body.materials:
		assert_bool(material.emission_enabled).is_true()
		assert_object(material.emission).is_equal(SideModel.FLASH_COLOUR)
	body.set_flashing(false)
	for material in body.materials:
		assert_bool(material.emission_enabled).is_true()
		assert_object(material.emission).is_equal(SideModel.NO_FLASH_COLOUR)


func test_the_node_shows_the_model_with_an_airframe_and_a_propeller() -> void:
	var node := _scene()
	var player_node: PlaneNode = node.get_node("Player")
	assert_int(_meshes(player_node).size()).is_equal(3)  # airframe, propeller, hanging Bomb
	assert_object(player_node.find_child(PlaneNode.PROPELLER_NODE, true, false)).is_not_null()


func test_each_side_paints_the_body_its_own_colour_on_its_own_materials() -> void:
	var node := _scene()
	for i in int(round((node.world.mission.first_launch_delay + DT) * 60.0)):
		node.step(DT)  # the enemy Hangar spawns a Red plane after the first-launch delay
	var player_node: PlaneNode = node.get_node("Player")
	var enemy_node: PlaneNode = node.get_node("Plane%d" % node.world.planes[1].state.id)
	assert_array(_body_colours(player_node)).is_not_empty().contains_exactly(
		[Side.colour(Side.BLUE), Side.colour(Side.BLUE)]
	)
	assert_array(_body_colours(enemy_node)).contains_exactly(
		[Side.colour(Side.RED), Side.colour(Side.RED)]
	)
	assert_object(_meshes(player_node)[0].mesh.surface_get_material(0)).is_not_same(
		(_meshes(player_node)[0] as MeshInstance3D).get_surface_override_material(0)
	)


func test_the_propeller_turns_only_with_the_engine_on() -> void:
	var node := _scene()
	var player_node: PlaneNode = node.get_node("Player")
	var propeller: Node3D = player_node.find_child(PlaneNode.PROPELLER_NODE, true, false)
	var at_rest := propeller.rotation.x
	node.step(DT)
	assert_float(propeller.rotation.x).is_equal_approx(at_rest, 0.0001)
	node.world.player.state.thrust_on = true
	player_node.refresh(DT)
	assert_float(propeller.rotation.x).is_greater(at_rest)


func test_wingtip_ribbons_trail_every_wing_under_load() -> void:
	var node := _scene()
	var player_node: PlaneNode = node.get_node("Player")
	for i in PlaneNode.WINGTIPS.size():
		assert_object(player_node.get_node("Ribbon%d" % i)).is_not_null()
	var state := node.world.player.state
	state.position = Vector2(300.0, 100.0)
	state.on_airfield = false
	state.set_speed_along_nose(40.0)
	node.world.player.pilot = ScriptedPilot.holding(true, true)  # full pull: high g
	for i in 12:
		node.step(DT)
	var ribbons: Array[Ribbon] = player_node._ribbons
	assert_int(ribbons.size()).is_equal(6)  # a tip on each side of three wings
	assert_int(ribbons[0].points.size()).is_equal(13)  # one from _ready, then one per tick
	# The tips sit either side of the action plane, the top wing's farthest out.
	assert_float(ribbons[0].points[12].z).is_greater(4.0)
	assert_float(ribbons[1].points[12].z).is_less(-4.0)
	assert_float(absf(ribbons[5].points[12].z)).is_less(absf(ribbons[1].points[12].z))
	assert_float(state.g_load).is_greater(Ribbon.G_FROM)
	assert_float(ribbons[0].strength).is_greater(0.0)


func test_a_bomb_hangs_under_the_belly_until_released_and_returns_for_the_next() -> void:
	var node := _scene()
	var player_node: PlaneNode = node.get_node("Player")
	var hanging: Node3D = player_node.find_child("HangingBomb", true, false)
	assert_object(hanging).is_not_null()
	assert_bool(hanging.visible).is_true()
	assert_float(hanging.position.y).is_less(0.0)  # on the wheels' side of the body
	var state := node.world.player.state
	state.position = Vector2(300.0, 100.0)
	state.on_airfield = false
	var pilot := ScriptedPilot.holding(false)
	node.world.player.pilot = pilot
	pilot.input.bomb = true
	node.step(DT)
	assert_int(state.bombs).is_equal(3)
	assert_bool(hanging.visible).is_false()
	for i in int(AirCombat.BOMB_INTERVAL / DT) + 1:
		node.step(DT)
	assert_bool(hanging.visible).is_true()
	state.bombs = 0
	node.step(DT)
	assert_bool(hanging.visible).is_false()
	assert_bool(PlaneNode.shows_hanging_bomb(state)).is_false()


func test_the_body_sways_on_a_pivot_when_the_plane_pulls() -> void:
	var node := _scene()
	var player_node: PlaneNode = node.get_node("Player")
	var pivot: Node3D = player_node.get_node("SwayPivot")
	assert_object(pivot).is_not_null()
	assert_bool(pivot.get_child(0) is SideModel).is_true()
	assert_float(pivot.rotation.x).is_equal(0.0)  # parked
	var state := node.world.player.state
	state.position = Vector2(300.0, 100.0)
	state.on_airfield = false
	state.set_speed_along_nose(40.0)
	node.world.player.pilot = ScriptedPilot.holding(true, true)  # full pull
	for i in 30:
		node.step(DT)
	# The pivot wears the Sway's bank, which is now mostly wander: only that it moved.
	assert_float(absf(pivot.rotation.x)).is_greater(0.0001)
	assert_float(pivot.rotation.x).is_equal_approx(player_node._sway.bank, 0.0001)
