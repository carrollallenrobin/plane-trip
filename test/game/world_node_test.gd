extends GdUnitTestSuite
## Headless checks that the scene layer wires the World correctly: the map and targets come
## from the placed nodes, plane nodes follow the Planes, and events become nodes and signals.
## The rules themselves are tested in test/sim/world/world_test.gd. The node is stepped
## directly, because frames from the scene runner are not tied to the physics clock.

const SCENE := "res://missions/strike_the_depot.tscn"
const DT := 1.0 / 60.0


func _scene() -> WorldNode:
	var runner := scene_runner(SCENE)
	return runner.scene()


func _step(node: WorldNode, seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		node.step(DT)


func _plane_nodes(node: WorldNode) -> Array[PlaneNode]:
	var found: Array[PlaneNode] = []
	for child in node.get_children():
		if child is PlaneNode and not child.is_queued_for_deletion():
			found.append(child)
	return found


func test_the_scene_carries_a_sound_stage_and_bells_on_their_buses() -> void:
	var node := _scene()
	var stage: SoundStage = node.get_node("SoundStage")
	(
		assert_int(stage.find_children("Whistle*", "AudioStreamPlayer3D", false, false).size())
		. is_equal(SoundStage.WHISTLE_VOICES)
	)
	var bell: AudioStreamPlayer = node.get_node("InstrumentPanel/Bell")
	assert_str(bell.bus).is_equal(UiSounds.BUS)
	assert_object(node.get_node("InstrumentPanel/BellLow").stream).is_same(SoundBank.BELL_LOW)


func test_world_builds_its_map_from_the_placed_nodes() -> void:
	var node := _scene()
	var map := node.world.map
	assert_object(map).is_not_null()
	assert_int(map.airfields.size()).is_equal(2)
	assert_object(map.home_airfield(Side.BLUE)).is_not_null()
	assert_bool(map.home_airfield(Side.RED).heading_right).is_false()
	assert_float(map.terrain.height_at(300.0)).is_equal_approx(55.0, 0.001)
	assert_bool(map.terrain.is_water_at(470.0)).is_true()


func test_the_world_collects_its_ground_targets_and_the_mission() -> void:
	var node := _scene()
	var world := node.world
	assert_int(world.targets.size()).is_equal(6)
	assert_object(world.target_named("Depot")).is_not_null()
	assert_int(world.target_named("EnemyHangar").kind).is_equal(GroundTarget.Kind.HANGAR)
	assert_str(world.mission.title).is_equal("Strike the Depot")
	assert_int(world.objective_statuses().size()).is_equal(2)
	assert_str(world.objective_statuses()[0].objective.display_title()).is_equal(
		"Destroy the enemy depot"
	)


func test_the_placed_plane_node_shows_the_players_plane() -> void:
	var node := _scene()
	var player_node: PlaneNode = node.get_node("Player")
	assert_object(player_node.plane).is_same(node.world.player)
	assert_bool(node.world.player.pilot is PlayerPilot).is_true()
	assert_object(node.world.player.loadout).is_same(player_node.loadout)
	assert_int(node.world.player.state.max_bombs()).is_equal(4)
	_step(node, 0.1)
	var s := node.world.player.state
	assert_bool(s.on_airfield).is_true()
	assert_vector(player_node.position).is_equal_approx(
		Vector3(s.position.x, s.position.y, 0.0), Vector3.ONE * 0.001
	)


func test_an_enemy_node_appears_on_spawn_and_goes_when_destroyed() -> void:
	var node := _scene()
	_step(node, node.world.mission.first_launch_delay + DT)
	var enemy := node.world.planes[1]  # the enemy's Squadron launches before the Wingmen's
	assert_int(enemy.side).is_equal(Side.RED)
	var nodes := _plane_nodes(node)
	assert_int(nodes.size()).is_equal(3)  # the player, the enemy and the first Wingman
	var enemy_node: PlaneNode = null
	for plane_node in nodes:
		if plane_node.plane == enemy:
			enemy_node = plane_node
	assert_object(enemy_node).is_not_null()
	assert_int(enemy_node.side).is_equal(Side.RED)
	assert_vector(enemy_node.position).is_equal_approx(
		Vector3(enemy.state.position.x, enemy.state.position.y, 0.0), Vector3.ONE * 0.001
	)
	enemy.state.position = Vector2(300.0, 5.0)  # below the ground: dead next step
	enemy.state.on_airfield = false
	_step(node, DT)
	assert_bool(enemy.is_alive()).is_false()
	assert_int(_plane_nodes(node).size()).is_equal(2)


func test_a_destroyed_player_plane_is_hidden_until_it_respawns() -> void:
	var node := _scene()
	var player_node: PlaneNode = node.get_node("Player")
	node.world.player.state.position = Vector2(300.0, 5.0)
	node.world.player.state.on_airfield = false
	_step(node, DT)
	assert_bool(player_node.visible).is_false()
	_step(node, node.respawn_delay + DT)
	assert_bool(player_node.visible).is_true()
	assert_bool(node.world.player.state.on_airfield).is_true()


func test_the_mission_ending_is_signalled_from_the_node() -> void:
	var node := _scene()
	var ended: Array[MissionRules.Outcome] = []
	node.mission_ended.connect(func(outcome: MissionRules.Outcome) -> void: ended.append(outcome))
	node.world.target_named("Depot").damage(GroundTarget.BOMB_DAMAGE)
	_step(node, DT)
	assert_array(ended).contains([MissionRules.Outcome.WON])


func test_a_refit_due_is_signalled_from_the_node() -> void:
	var node := _scene()
	var due: Array[bool] = []
	node.refit_due.connect(func() -> void: due.append(true))
	node.world.player.state.position = Vector2(300.0, 50.0)  # under the 55 m hill
	node.world.player.state.on_airfield = false
	_step(node, node.world.respawn_delay + 0.1)
	assert_int(due.size()).is_equal(1)


func test_a_shot_in_the_world_shows_a_muzzle_flash() -> void:
	var node := _scene()
	var shooter := ScriptedPilot.holding(false)
	shooter.input.fire = true
	node.world.player.pilot = shooter
	node.world.player.state.position = Vector2(300.0, 100.0)
	node.world.player.state.on_airfield = false
	_step(node, DT)
	var effects: EffectsNode = node.get_node("Effects")
	assert_int(effects.plan.flashes.size()).is_equal(1)
	assert_object(effects.plan.flashes[0].follow).is_same(node.world.player.state)
	assert_int(effects.plan.casings.size()).is_equal(EffectsPlan.CASINGS_PER_SHOT)


func test_a_blast_near_the_player_shakes_the_camera_and_shows_a_burst() -> void:
	var node := _scene()
	node.world.player.state.position = Vector2(300.0, 100.0)
	node.world.player.state.on_airfield = false
	var shell := Shell.new()  # bursts 20 m below the player: felt, not fatal
	shell.position = Vector2(300.0, 80.0)
	shell.velocity = Vector2.ZERO
	shell.fuse = DT / 2.0
	node.world.guns.shells.append(shell)
	var camera: FollowCamera = node.get_node("Camera")
	assert_float(camera.shake.trauma).is_equal(0.0)
	_step(node, DT)
	assert_float(camera.shake.trauma).is_equal_approx(
		CameraShake.BLAST_TRAUMA * (1.0 - 20.0 / CameraShake.BLAST_RANGE), 0.01
	)
	var effects: EffectsNode = node.get_node("Effects")
	assert_int(effects.plan.bursts.size()).is_equal(1)
	assert_object(effects.plan.bursts[0].colour).is_equal(EffectsPlan.SHELL_BURST_COLOR)


func test_a_hurt_player_trails_damage_smoke() -> void:
	var node := _scene()
	var state := node.world.player.state
	state.position = Vector2(300.0, 100.0)
	state.on_airfield = false
	state.hit_points = 1
	_step(node, 0.5)
	var effects: EffectsNode = node.get_node("Effects")
	var smoke := 0
	for puff in effects.plan.puffs:
		if puff.kind == EffectsPlan.PuffKind.DAMAGE:
			smoke += 1
	assert_int(smoke).is_greater(3)


func test_the_big_show_puts_up_five_reds_and_four_wingmen_each_with_a_node() -> void:
	var runner := scene_runner("res://missions/the_big_show.tscn")
	var node: WorldNode = runner.scene()
	assert_str(node.world.mission.title).is_equal("The Big Show")
	assert_int(node.world.enemies_left()).is_equal(-1)
	assert_int(node.world.mission.enemy_aloft).is_equal(5)
	assert_int(node.world.mission.wingmen_aloft).is_equal(4)
	_step(node, 4.9)  # nothing before the first-launch delay
	assert_int(_plane_nodes(node).size()).is_equal(1)
	# Launches at 5, 11, 17 and 23 s on each side; checked before the melee costs anyone a
	# Plane, which the seeded World does from about 27 s.
	_step(node, 18.6)
	assert_int(node.world.enemies_alive()).is_equal(4)
	assert_int(node.world.wingmen_alive()).is_equal(4)
	var reds := 0
	var blues := 0
	for plane_node in _plane_nodes(node):
		if plane_node.plane == node.world.player:
			continue
		if plane_node.side == Side.RED:
			reds += 1
		else:
			blues += 1
	assert_int(reds).is_equal(4)
	assert_int(blues).is_equal(4)
	assert_array(node.world.rules.unresolved_target_names(node.world.targets)).is_empty()


func test_clear_the_sky_flies_one_interceptor_at_a_time_against_a_shoot_down() -> void:
	var runner := scene_runner("res://missions/clear_the_sky.tscn")
	var node: WorldNode = runner.scene()
	_step(node, node.world.mission.first_launch_delay + DT)
	assert_int(node.world.enemies_alive()).is_equal(1)
	assert_int(node.world.wingmen_alive()).is_equal(0)
	assert_int(node.world.planes[1].state.max_bombs()).is_equal(0)
	assert_int(node.world.player.state.max_bombs()).is_equal(0)
	var statuses := node.world.objective_statuses()
	assert_int(statuses.size()).is_equal(1)
	assert_int(statuses[0].objective.kind).is_equal(Objective.Kind.SHOOT_DOWN)
	assert_int(statuses[0].objective.count).is_equal(3)
