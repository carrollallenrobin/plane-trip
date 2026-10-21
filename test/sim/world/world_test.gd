extends GdUnitTestSuite
## The World's rules, driven through its interface alone: no scene. The fixture mirrors the
## Strike the Depot mission: a flat World, two Airfields, and the targets the objectives name.

const DT := 1.0 / 60.0
const GROUND := 10.0

var _world: World
var _events: Array[WorldEvent] = []


func before_test() -> void:
	_world = World.create(_map(), _targets(), _mission(), null, Side.BLUE, 1, 1.8)
	_world.add_player(TestLoadouts.fighter(), ScriptedPilot.holding(false))
	_events = []


func _map() -> WorldMap:
	var map := WorldMap.new()
	map.bounds = WorldBounds.create(960.0, 160.0)
	map.terrain = Terrain.from_points(
		PackedVector2Array([Vector2(0.0, GROUND), Vector2(960.0, GROUND)])
	)
	map.airfields.append(Airfield.create(Side.BLUE, 20.0, 100.0, GROUND))
	var enemy_field := Airfield.create(Side.RED, 820.0, 900.0, GROUND)
	enemy_field.heading_right = false
	map.airfields.append(enemy_field)
	return map


func _target(name: String, side: int, kind: GroundTarget.Kind, x: float) -> GroundTarget:
	return GroundTarget.create(name, side, kind, Vector2(x, GROUND), 12.0, 6.0)


func _targets() -> Array[GroundTarget]:
	return [
		_target("HomeHangar", Side.BLUE, GroundTarget.Kind.HANGAR, 130.0),
		_target("FuelStore", Side.BLUE, GroundTarget.Kind.BUILDING, 160.0),
		_target("AAGun", Side.RED, GroundTarget.Kind.ANTI_AIRCRAFT_GUN, 600.0),
		_target("Flak", Side.RED, GroundTarget.Kind.FLAK_GUN, 650.0),
		_target("Depot", Side.RED, GroundTarget.Kind.BUILDING, 700.0),
		_target("EnemyHangar", Side.RED, GroundTarget.Kind.HANGAR, 780.0),
	]


func _mission() -> MissionDefinition:
	var mission := MissionDefinition.new()
	mission.title = "Strike the Depot"
	mission.objectives = [
		Objective.create(Objective.Kind.DESTROY, "Depot", true, "Destroy the enemy depot"),
		Objective.create(Objective.Kind.PROTECT, "FuelStore", true, "Protect the fuel store"),
	]
	mission.player_planes = 3
	mission.enemy_pool = 3
	return mission


## Step for a while, collecting events.
func _step(seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		_events.append_array(_world.step(DT))


func _kinds() -> Array[WorldEvent.Kind]:
	var kinds: Array[WorldEvent.Kind] = []
	for event in _events:
		kinds.append(event.kind)
	return kinds


## Park a plane in the air at a point, heading right at a speed.
func _hold_in_air(plane: WorldPlane, x: float, y: float, speed: float) -> void:
	plane.state.position = Vector2(x, y)
	plane.state.angle = 0.0
	plane.state.set_speed_along_nose(speed)
	plane.state.on_airfield = false


func _enemy() -> WorldPlane:
	return _world.planes[1]


func _of_kind(kind: WorldEvent.Kind) -> Array[WorldEvent]:
	var found: Array[WorldEvent] = []
	for event in _events:
		if event.kind == kind:
			found.append(event)
	return found


## How the objective on this target (or the Return objective, for "") stands.
func _status(target_name: String) -> MissionRules.Status:
	for entry in _world.objective_statuses():
		if entry.objective.target_name == target_name:
			return entry.status
	return MissionRules.Status.OPEN


func test_the_clock_counts_the_seconds_stepped() -> void:
	assert_float(_world.time).is_equal(0.0)
	_step(2.5)
	assert_float(_world.time).is_equal_approx(2.5, 0.001)


func test_player_starts_at_rest_on_the_home_airfield() -> void:
	_step(0.1)
	var s := _world.player.state
	assert_bool(s.on_airfield).is_true()
	assert_float(s.speed).is_equal(0.0)
	assert_object(_world.map.airfield_at(s.position.x)).is_same(_world.map.home_airfield(Side.BLUE))
	assert_bool(_world.player_returned()).is_true()


func test_scripted_takeoff_leaves_the_runway() -> void:
	var pilot := ScriptedPilot.holding(true)
	_world.player.pilot = pilot
	_step(4.0)
	pilot.input.pitch_up = true
	_step(0.5)
	var s := _world.player.state
	assert_bool(_world.player.is_alive()).is_true()
	assert_bool(s.on_airfield).is_false()
	assert_float(s.position.y).is_greater(16.0)
	assert_bool(_world.player_returned()).is_false()


func test_flying_into_the_ground_destroys_the_plane_and_respawns_it() -> void:
	_world.player.pilot = ScriptedPilot.holding(true)
	_world.player.state.position = Vector2(300.0, 90.0)
	_world.player.state.angle = 270.0
	_world.player.state.set_speed_along_nose(30.0)
	_world.player.state.on_airfield = false
	_step(5.0)
	assert_int(_world.player_losses).is_equal(1)
	assert_int(_world.player_planes_left()).is_equal(2)
	assert_bool(_world.player.is_alive()).is_true()
	assert_bool(_world.player.state.on_airfield).is_true()
	# The player's end comes as an event, its next life after the respawn delay, and with
	# the new Plane a Refit.
	var player_events: Array[WorldEvent.Kind] = []
	for event in _events:
		if event.plane == _world.player:
			player_events.append(event.kind)
			if event.kind == WorldEvent.Kind.PLANE_DESTROYED:
				assert_int(event.crash).is_equal(CrashRules.Outcome.TERRAIN)
				assert_float(event.position.y).is_less(20.0)
	assert_array(player_events).contains_exactly(
		[WorldEvent.Kind.PLANE_DESTROYED, WorldEvent.Kind.PLANE_SPAWNED, WorldEvent.Kind.REFIT_DUE]
	)


func test_losing_every_plane_in_the_stock_loses_the_mission() -> void:
	for life in 3:
		_hold_in_air(_world.player, 300.0, 5.0, 30.0)  # below the ground: dead next step
		_step(2.5)
	assert_int(_world.player_losses).is_equal(3)
	assert_bool(_world.player.is_alive()).is_false()
	assert_int(_world.outcome).is_equal(MissionRules.Outcome.LOST)
	assert_array(_kinds()).contains([WorldEvent.Kind.MISSION_ENDED])


func test_an_enemy_takes_off_from_the_enemy_airfield_under_ai_control() -> void:
	_step(DT)
	assert_int(_world.enemies_alive()).is_equal(1)
	assert_int(_world.enemies_left()).is_equal(2)
	assert_array(_kinds()).contains([WorldEvent.Kind.PLANE_SPAWNED])
	var enemy := _enemy()
	assert_object(_events[0].plane).is_same(enemy)
	assert_bool(enemy.pilot is AiPilot).is_true()
	assert_int(enemy.side).is_equal(Side.RED)
	assert_bool(enemy.state.heading_right()).is_false()
	_step(12.0)
	assert_bool(enemy.is_alive()).is_true()
	assert_bool(enemy.state.on_airfield).is_false()
	assert_float(enemy.state.position.x).is_less(800.0)


func test_enemies_carry_the_missions_loadout_and_the_player_theirs() -> void:
	var mission := _mission()
	mission.enemy_loadouts = [Loadout.of([TestLoadouts.bomb_rack()])]
	_world_with(mission)
	_step(DT)
	var enemy := _enemy()
	assert_object(enemy.loadout).is_same(mission.enemy_loadouts[0])
	assert_int(enemy.state.max_bombs()).is_equal(2)
	assert_int(_world.player.state.max_bombs()).is_equal(4)
	assert_object(enemy.airframe).is_same(_world.airframe)


func test_a_refit_rearms_a_parked_player_at_once_and_builds_the_next_plane_otherwise() -> void:
	var light := Loadout.of([TestLoadouts.fuel_tank()])
	_world.player.state.rounds = 0
	_world.player.state.hit_points = 5
	assert_bool(_world.refit(light)).is_true()
	assert_object(_world.player_loadout).is_same(light)
	var s := _world.player.state
	assert_int(s.max_bombs()).is_equal(0)
	assert_int(s.bombs).is_equal(0)
	assert_int(s.rounds).is_equal(s.max_rounds())
	assert_int(s.hit_points).is_equal(s.max_hit_points())
	# In the air, or dead, the choice waits for the next Plane.
	_hold_in_air(_world.player, 300.0, 100.0, 30.0)
	var heavy := Loadout.of([TestLoadouts.armour_plate()])
	assert_bool(_world.refit(heavy)).is_false()
	assert_object(_world.player.state.loadout).is_same(light)
	_world.player.state.position.y = GROUND - 1.0  # into the ground
	_step(_world.respawn_delay + 0.1)
	assert_bool(_world.player.is_alive()).is_true()
	assert_object(_world.player.state.loadout).is_same(heavy)
	assert_int(_world.player.state.max_hit_points()).is_equal(33)


func test_a_refit_sets_the_plane_back_at_the_start_of_its_runway() -> void:
	# Landed the wrong way round and rolled to the far end, there is no room to take off.
	var s := _world.player.state
	var home := _world.map.home_airfield(Side.BLUE)
	s.position = Vector2(home.start_x + 2.0, s.position.y)
	s.angle = 180.0 - FlightModel.REST_PITCH
	s.upside_down = true
	s.vel = Vector2.ZERO
	s.speed = 0.0
	s.on_airfield = true
	s.rounds = 3
	var sortie := s.fuel
	_world.player.flown_since_refit = true
	assert_bool(_world.refit(TestLoadouts.fighter())).is_true()
	assert_vector(s.position).is_equal(home.spawn_position())
	assert_float(s.angle).is_equal(FlightModel.REST_PITCH)
	assert_bool(s.upside_down).is_false()
	assert_bool(s.on_airfield).is_true()
	assert_float(s.speed).is_equal(0.0)
	assert_int(s.rounds).is_equal(s.max_rounds())
	assert_float(s.fuel).is_greater_equal(sortie)
	# It sits there without asking for another Refit.
	_events = []
	_step(1.0)
	assert_array(_kinds()).not_contains([WorldEvent.Kind.REFIT_DUE])
	assert_float(s.position.x).is_equal(home.spawn_position().x)


## Put the player back at rest on the Home Airfield as after a landing, without a new life.
func _park_at_home() -> void:
	var s := _world.player.state
	var home := _world.map.home_airfield(Side.BLUE)
	s.position = home.spawn_position()
	s.angle = FlightModel.REST_PITCH
	s.upside_down = false
	s.vel = Vector2.ZERO
	s.speed = 0.0
	s.on_airfield = true


func test_a_refit_is_due_on_the_players_spawn_and_once_per_stop_at_home_after_flying() -> void:
	_step(DT)
	assert_array(_kinds()).not_contains([WorldEvent.Kind.REFIT_DUE])
	# Rolling on the runway and stopping again is not a sortie.
	_world.player.state.vel = Vector2(5.0, 0.0)
	_step(0.5)
	_park_at_home()
	_step(0.5)
	assert_array(_kinds()).not_contains([WorldEvent.Kind.REFIT_DUE])
	# A sortie, then a stop at home: one Refit, however long the plane sits.
	_hold_in_air(_world.player, 300.0, 100.0, 30.0)
	_step(DT)
	_park_at_home()
	_events = []
	_step(1.0)
	assert_int(_kinds().count(WorldEvent.Kind.REFIT_DUE)).is_equal(1)
	assert_object(_events[0].plane).is_same(_world.player)
	# A Refit confirmed on the runway does not ask again until the plane has flown.
	_world.refit(TestLoadouts.fighter())
	_events = []
	_step(1.0)
	assert_array(_kinds()).not_contains([WorldEvent.Kind.REFIT_DUE])
	# Lost and respawned: a Refit with the new Plane.
	_hold_in_air(_world.player, 300.0, GROUND - 1.0, 30.0)
	_events = []
	_step(_world.respawn_delay + 0.1)
	assert_array(_kinds()).contains([WorldEvent.Kind.PLANE_SPAWNED, WorldEvent.Kind.REFIT_DUE])


func test_no_refit_is_due_on_the_enemys_airfield_or_for_an_enemy_plane() -> void:
	_hold_in_air(_world.player, 300.0, 100.0, 30.0)
	_step(DT)
	var s := _world.player.state
	var theirs := _world.map.home_airfield(Side.RED)
	s.position = theirs.spawn_position()
	s.angle = 180.0 - FlightModel.REST_PITCH
	s.upside_down = true
	s.vel = Vector2.ZERO
	s.speed = 0.0
	s.on_airfield = true
	_events = []
	_step(1.0)
	assert_array(_kinds()).not_contains([WorldEvent.Kind.REFIT_DUE])
	var enemy := _enemy()
	for event in _events:
		if event.kind == WorldEvent.Kind.REFIT_DUE:
			assert_object(event.plane).is_not_same(enemy)


func test_a_plane_in_a_spin_meeting_the_runway_is_destroyed_not_landed() -> void:
	var player := _world.player
	player.pilot = ScriptedPilot.holding(false)
	_hold_in_air(player, 40.0, GROUND + 6.0, 10.0)  # over its own airfield, nose level
	player.state.hit_points = 0
	player.state.in_spin = true
	_step(2.0)
	assert_int(_world.player_losses).is_equal(1)
	var ends := _of_kind(WorldEvent.Kind.PLANE_DESTROYED)
	assert_int(ends.size()).is_equal(1)
	assert_int(ends[0].crash).is_equal(CrashRules.Outcome.TERRAIN)


func test_bullets_wound_spin_and_destroy_an_enemy_then_the_next_one_comes() -> void:
	_step(DT)
	var enemy := _enemy()
	# Park the enemy in the air in front of the player's guns and hold the trigger. Both coast
	# with the engine off so the player keeps station behind the target.
	enemy.pilot = ScriptedPilot.holding(false)
	_hold_in_air(enemy, 300.0, 100.0, 30.0)
	var shooter := ScriptedPilot.holding(false)
	shooter.input.fire = true
	_world.player.pilot = shooter
	_hold_in_air(_world.player, 280.0, 100.0, 30.0)
	var full := enemy.state.hit_points
	# A shot is reported from the muzzle, a hit at the point of impact with the round's flight;
	# both are checked on the tick they happen, before the planes move on.
	var shots := 0
	var hits := 0
	for i in 30:
		for event in _world.step(DT):
			_events.append(event)
			if event.kind == WorldEvent.Kind.GUN_FIRED:
				shots += 1
				assert_object(event.plane).is_same(_world.player)
				var state := _world.player.state
				assert_vector(event.position).is_equal_approx(
					state.position + state.nose() * AirCombat.MUZZLE_OFFSET, Vector2(0.01, 0.01)
				)
				assert_vector(event.direction).is_equal_approx(state.nose(), Vector2(0.01, 0.01))
			elif event.kind == WorldEvent.Kind.PLANE_HIT:
				hits += 1
				assert_object(event.plane).is_same(enemy)
				assert_bool(enemy.state.contains_point(event.position)).is_true()
				assert_vector(event.direction).is_equal_approx(Vector2.RIGHT, Vector2(0.05, 0.05))
	assert_int(shots).is_greater(0)
	assert_int(hits).is_greater(0)
	assert_int(enemy.state.hit_points).is_less(full)
	assert_int(_world.combat.bullets.size()).is_greater(0)
	# Each hit shoves the enemy on, so it would outrun the stream: keep it in front of the
	# player's guns until it goes down.
	for i in 180:
		if enemy.state.can_fight():
			_hold_in_air(enemy, _world.player.state.position.x + 20.0, 100.0, 30.0)
		_events.append_array(_world.step(DT))
	assert_bool(enemy.state.in_spin or not enemy.is_alive()).is_true()
	assert_int(_world.kills).is_equal(1)
	shooter.input.fire = false  # so the next enemy does not fly into the stream
	_step(12.0)
	assert_bool(enemy.is_alive()).is_false()
	assert_int(_world.kills).is_equal(1)
	assert_bool(_world.planes.has(enemy)).is_false()
	# The pool sends the next plane after the respawn delay.
	assert_int(_world.enemies_alive()).is_equal(1)
	assert_int(_world.enemies_left()).is_equal(1)


func test_bullets_ending_on_the_ground_water_or_a_target_are_reported_with_the_surface() -> void:
	var map := _map()
	map.terrain.add_water(400.0, 420.0)
	_world = World.create(map, _targets(), _mission(), null, Side.BLUE, 1, 1.8)
	var shooter := ScriptedPilot.holding(false)
	shooter.input.fire = true
	_world.add_player(TestLoadouts.fighter(), shooter)
	# Straight down onto dry ground, then onto the Water, then into the depot's wall. Each
	# dive starts high enough that the plane is still flying when the rounds land.
	_hold_in_air(_world.player, 300.0, 40.0, 30.0)
	_world.player.state.angle = 270.0
	_world.player.state.set_speed_along_nose(30.0)
	_step(0.45)
	var ground := _of_kind(WorldEvent.Kind.BULLET_IMPACT)
	assert_int(ground.size()).is_greater(0)
	assert_int(ground[0].surface).is_equal(BulletHit.Surface.GROUND)
	assert_float(ground[0].position.y).is_equal_approx(GROUND, 0.001)
	assert_float(ground[0].direction.y).is_less(0.0)
	_events = []
	_world.combat.bullets.clear()  # rounds still falling from the last dive would land here
	_hold_in_air(_world.player, 410.0, 40.0, 30.0)
	_world.player.state.angle = 270.0
	_world.player.state.set_speed_along_nose(30.0)
	_step(0.45)
	var water := _of_kind(WorldEvent.Kind.BULLET_IMPACT)
	assert_int(water.size()).is_greater(0)
	assert_int(water[0].surface).is_equal(BulletHit.Surface.WATER)
	_events = []
	_world.combat.bullets.clear()
	var depot := _world.target_named("Depot")
	_hold_in_air(_world.player, depot.base.x - 25.0, GROUND + 4.0, 30.0)
	_step(0.4)
	var wall := _of_kind(WorldEvent.Kind.BULLET_IMPACT)
	assert_int(wall.size()).is_greater(0)
	assert_int(wall[0].surface).is_equal(BulletHit.Surface.TARGET)
	assert_object(wall[0].target).is_same(depot)
	assert_bool(depot.is_alive()).is_true()  # a building shrugs off bullets


func test_ground_guns_report_their_shots_from_the_barrel() -> void:
	var gun := _world.target_named("AAGun")
	var flak := _world.target_named("Flak")
	_world.player.pilot = ScriptedPilot.holding(true)
	# Closing on the gun, so the led aim point stays inside the cone.
	_hold_in_air(_world.player, gun.base.x - 10.0, 50.0, 30.0)
	_step(1.0)
	var aa_shots := 0
	var flak_shots := 0
	for event in _of_kind(WorldEvent.Kind.GUN_FIRED):
		assert_object(event.plane).is_null()
		assert_float(event.direction.y).is_greater(0.0)
		if event.target == gun:
			aa_shots += 1
			assert_vector(event.position).is_equal(
				gun.base + Vector2(0.0, GroundGuns.BARREL_HEIGHT)
			)
		elif event.target == flak:
			flak_shots += 1
	assert_int(aa_shots).is_greater(0)
	assert_int(flak_shots).is_greater(0)


func test_a_held_bomb_key_releases_a_spaced_stick_and_reports_each_release() -> void:
	var pilot := ScriptedPilot.holding(false)
	_world.player.pilot = pilot
	_hold_in_air(_world.player, 300.0, 100.0, 30.0)
	# Two and a half intervals with the key held; the scripted pilot treats it as a press per
	# tick.
	for i in int(round(2.5 * AirCombat.BOMB_INTERVAL / DT)):
		pilot.input.bomb = true
		_step(DT)
	assert_int(_world.player.state.bombs).is_equal(1)
	var releases := _of_kind(WorldEvent.Kind.BOMB_RELEASED)
	assert_int(releases.size()).is_equal(3)
	assert_object(releases[0].plane).is_same(_world.player)
	# Released from the belly, below the plane as it flies upright.
	assert_float(releases[0].position.y).is_equal_approx(100.0 - AirCombat.BOMB_RELEASE_OFFSET, 0.5)


func test_a_blast_beside_the_plane_hits_it_pointing_away_from_the_burst() -> void:
	_hold_in_air(_world.player, 300.0, 100.0, 30.0)
	var shell := Shell.new()  # bursts 8 m below the plane: wounds, does not destroy
	shell.position = Vector2(300.0, 92.0)
	shell.velocity = Vector2(30.0, 0.0)
	shell.fuse = DT / 2.0
	_world.guns.shells.append(shell)
	_step(DT)
	var hits := _of_kind(WorldEvent.Kind.PLANE_HIT)
	assert_int(hits.size()).is_equal(1)
	assert_bool(_world.player.is_alive()).is_true()
	assert_vector(hits[0].position).is_equal(_world.player.state.position)
	assert_float(hits[0].direction.y).is_greater(0.9)


func test_a_blast_on_an_enemy_the_player_put_into_a_spin_counts_one_kill() -> void:
	_step(DT)
	var enemy := _enemy()
	enemy.pilot = ScriptedPilot.holding(false)
	_hold_in_air(enemy, 300.0, 100.0, 30.0)
	enemy.state.hit_points = 1
	var shooter := ScriptedPilot.holding(false)
	shooter.input.fire = true
	_world.player.pilot = shooter
	_hold_in_air(_world.player, 280.0, 100.0, 30.0)
	_step(0.5)
	assert_bool(enemy.state.in_spin).is_true()
	assert_int(_world.kills).is_equal(1)
	shooter.input.fire = false
	# A Shell bursting on it: the Blast finishes it, and the kill is not counted again.
	var shell := Shell.new()
	shell.position = Vector2(300.0, 99.0)
	shell.velocity = Vector2(30.0, 60.0)
	shell.fuse = 10.0
	shell.position = Vector2(enemy.state.position.x, enemy.state.position.y - 1.0)
	shell.velocity = enemy.state.velocity() + Vector2(0.0, 60.0)
	_world.guns.shells.append(shell)
	_step(DT)
	assert_bool(enemy.is_alive()).is_false()
	assert_int(_world.kills).is_equal(1)
	assert_array(_kinds()).contains([WorldEvent.Kind.SHELL_BURST, WorldEvent.Kind.PLANE_DESTROYED])


func test_enemies_lost_to_the_ground_or_to_guns_are_not_the_players_kills() -> void:
	_step(DT)
	var enemy := _enemy()
	_hold_in_air(enemy, 300.0, 5.0, 30.0)  # below the ground: dead next step
	_step(DT)
	assert_bool(enemy.is_alive()).is_false()
	assert_int(_world.kills).is_equal(0)
	_step(_world.respawn_delay + DT)
	var next := _enemy()
	next.pilot = ScriptedPilot.holding(false)
	_hold_in_air(next, 300.0, 100.0, 30.0)
	var shell := Shell.new()  # a Blue Shell, as if from a Blue Flak Gun
	shell.side = Side.BLUE
	shell.position = Vector2(300.0, 99.0)
	shell.velocity = Vector2(30.0, 60.0)
	shell.fuse = 10.0
	_world.guns.shells.append(shell)
	_step(DT)
	assert_bool(next.is_alive()).is_false()
	assert_int(_world.kills).is_equal(0)


func test_a_bomb_striking_a_parked_enemy_explodes_it_outright() -> void:
	_step(DT)
	var enemy := _enemy()
	enemy.pilot = ScriptedPilot.holding(false)  # stays parked on the runway
	var pilot := ScriptedPilot.holding(false)
	_world.player.pilot = pilot
	_hold_in_air(_world.player, enemy.state.position.x, enemy.state.position.y + 40.0, 0.0)
	pilot.input.bomb = true
	_step(DT)
	assert_int(_world.combat.bombs.size()).is_equal(1)
	var waited := 0.0
	while enemy.is_alive() and waited < 5.0:
		_step(DT)
		waited += DT
	assert_bool(enemy.is_alive()).is_false()
	assert_bool(enemy.state.in_spin).is_false()
	assert_int(_world.kills).is_equal(1)
	assert_array(_kinds()).contains([WorldEvent.Kind.BOMB_DETONATED])


func test_a_bomb_on_the_depot_completes_the_objective_and_wins_the_mission() -> void:
	var depot := _world.target_named("Depot")
	var pilot := ScriptedPilot.holding(false)
	_world.player.pilot = pilot
	_hold_in_air(_world.player, depot.base.x - 1.0, 60.0, 0.0)
	pilot.input.bomb = true
	_step(DT)
	assert_int(_world.combat.bombs.size()).is_equal(1)
	var waited := 0.0
	while depot.is_alive() and waited < 6.0:
		_step(DT)
		waited += DT
	assert_bool(depot.is_alive()).is_false()
	assert_int(_status("Depot")).is_equal(MissionRules.Status.COMPLETE)
	assert_int(_world.outcome).is_equal(MissionRules.Outcome.WON)
	var ended: Array[WorldEvent] = []
	var destroyed: Array[WorldEvent] = []
	for event in _events:
		if event.kind == WorldEvent.Kind.MISSION_ENDED:
			ended.append(event)
		elif event.kind == WorldEvent.Kind.TARGET_DESTROYED:
			destroyed.append(event)
	assert_int(ended.size()).is_equal(1)
	assert_int(ended[0].outcome).is_equal(MissionRules.Outcome.WON)
	assert_int(destroyed.size()).is_equal(1)
	assert_object(destroyed[0].target).is_same(depot)


func test_a_return_objective_completes_once_the_player_is_parked_at_home() -> void:
	var mission := _mission()
	mission.objectives.append(Objective.create(Objective.Kind.RETURN, "", true, "Return home"))
	_world = World.create(_map(), _targets(), mission, null, Side.BLUE, 1, 1.8)
	_world.add_player(TestLoadouts.fighter(), ScriptedPilot.holding(false))
	_world.target_named("Depot").damage(GroundTarget.BOMB_DAMAGE)
	_step(DT)
	assert_int(_status("")).is_equal(MissionRules.Status.COMPLETE)
	assert_int(_world.outcome).is_equal(MissionRules.Outcome.WON)


func test_destroying_the_enemy_hangar_stops_the_spawns() -> void:
	_step(DT)
	assert_int(_world.enemies_alive()).is_equal(1)
	_world.target_named("EnemyHangar").damage(GroundTarget.BOMB_DAMAGE)
	_hold_in_air(_enemy(), 300.0, 5.0, 30.0)  # below the ground: dead next step
	_step(5.0)
	assert_int(_world.enemies_alive()).is_equal(0)
	assert_int(_world.enemies_left()).is_equal(2)


func test_losing_the_fuel_store_loses_the_mission() -> void:
	_world.target_named("FuelStore").damage(GroundTarget.BOMB_DAMAGE)
	_step(DT)
	assert_int(_world.outcome).is_equal(MissionRules.Outcome.LOST)
	assert_int(_status("FuelStore")).is_equal(MissionRules.Status.FAILED)


func test_the_anti_aircraft_gun_shoots_at_the_player_overhead() -> void:
	var gun := _world.target_named("AAGun")
	_world.player.pilot = ScriptedPilot.holding(true)
	_hold_in_air(_world.player, gun.base.x, 50.0, 30.0)
	_step(0.5)
	var ground_bullets := 0
	for bullet in _world.combat.bullets:
		if bullet.owner_id < 0:
			ground_bullets += 1
	assert_int(ground_bullets).is_greater(0)


func test_a_shell_bursting_at_the_player_is_a_blast_that_destroys_it() -> void:
	_hold_in_air(_world.player, 300.0, 100.0, 30.0)
	var shell := Shell.new()
	shell.position = Vector2(300.0, 99.0)
	shell.velocity = Vector2(30.0, 60.0)
	shell.fuse = 10.0
	_world.guns.shells.append(shell)
	_step(DT)
	assert_bool(_world.player.is_alive()).is_false()
	assert_int(_world.player_losses).is_equal(1)
	assert_int(_world.kills).is_equal(0)


func test_debris_from_a_destroyed_plane_wounds_a_plane_flying_through_it() -> void:
	_step(DT)
	var enemy := _enemy()
	enemy.pilot = ScriptedPilot.holding(false)
	_hold_in_air(enemy, 300.0, 100.0, 30.0)
	# Downrange of the pieces, which inherit the enemy's 30 m/s, and outside the Blast.
	_hold_in_air(_world.player, 320.0, 100.0, 0.0)
	var full := _world.player.state.hit_points
	var shell := Shell.new()
	shell.position = Vector2(300.0, 99.0)
	shell.velocity = Vector2(30.0, 60.0)
	shell.fuse = 10.0
	_world.guns.shells.append(shell)
	_step(DT)
	assert_bool(enemy.is_alive()).is_false()
	assert_int(_world.debris.size()).is_between(1, Debris.MAX_PARTS)
	var pieces := _world.debris.duplicate()
	_step(1.5)
	assert_bool(_world.player.is_alive()).is_true()
	assert_int(_world.player.state.hit_points).is_less(full)
	for hit in _of_kind(WorldEvent.Kind.PLANE_HIT):
		if hit.plane == _world.player:  # struck by a piece flying downrange
			assert_float(hit.direction.x).is_greater(0.0)
	assert_int(_world.debris.size()).is_less(pieces.size())  # the pieces that struck are gone
	_step(Debris.LIFETIME)
	for piece in pieces:
		assert_bool(_world.debris.has(piece)).is_false()  # all aged out


func test_debris_settles_on_the_terrain_and_stays_in_the_world() -> void:
	_world.target_named("Depot").damage(GroundTarget.BOMB_DAMAGE)
	_world.debris.clear()
	var piece := Debris.new()
	piece.position = Vector2(300.0, 12.0)
	piece.velocity = Vector2(10.0, -20.0)
	_world.debris.append(piece)
	_step(0.5)
	assert_bool(piece.settled).is_true()
	assert_float(piece.position.y).is_equal_approx(GROUND, 0.001)
	assert_vector(piece.velocity).is_equal(Vector2.ZERO)
	assert_bool(_world.debris.has(piece)).is_true()


func test_the_world_knows_its_targets_and_mission() -> void:
	assert_int(_world.targets.size()).is_equal(6)
	assert_int(_world.target_named("EnemyHangar").kind).is_equal(GroundTarget.Kind.HANGAR)
	assert_object(_world.target_named("Nowhere")).is_null()
	assert_str(_world.mission.title).is_equal("Strike the Depot")
	assert_int(_world.outcome).is_equal(MissionRules.Outcome.ONGOING)
	assert_int(_world.objective_statuses().size()).is_equal(2)
	assert_int(_status("Depot")).is_equal(MissionRules.Status.OPEN)
	assert_int(_status("FuelStore")).is_equal(MissionRules.Status.COMPLETE)


func test_bullets_strike_a_spinning_plane_and_are_felt_but_do_nothing_to_it() -> void:
	_step(DT)
	var enemy := _enemy()
	enemy.pilot = ScriptedPilot.holding(false)
	_hold_in_air(enemy, 300.0, 100.0, 30.0)
	enemy.state.hit_points = 0
	enemy.state.in_spin = true
	var shooter := ScriptedPilot.holding(false)
	shooter.input.fire = true
	_world.player.pilot = shooter
	_hold_in_air(_world.player, 280.0, 100.0, 30.0)
	_step(0.5)
	var hits := _of_kind(WorldEvent.Kind.PLANE_HIT)
	assert_int(hits.size()).is_greater(0)
	assert_object(hits[0].plane).is_same(enemy)
	assert_bool(enemy.is_alive()).is_true()
	assert_bool(enemy.state.in_spin).is_true()
	assert_int(_world.kills).is_equal(0)  # nobody's: it was already out of the fight


func test_hits_shove_the_plane_along_the_round_and_a_blast_pushes_it_away() -> void:
	_step(DT)
	var enemy := _enemy()
	enemy.pilot = ScriptedPilot.holding(false)
	_hold_in_air(enemy, 300.0, 100.0, 30.0)
	var shooter := ScriptedPilot.holding(false)
	shooter.input.fire = true
	_world.player.pilot = shooter
	_hold_in_air(_world.player, 280.0, 100.0, 30.0)
	# Rounds flying right strike the enemy from behind: it is pushed on, faster than the
	# player coasting beside it.
	var hits := 0
	for i in 30:
		for event in _world.step(DT):
			if event.kind == WorldEvent.Kind.PLANE_HIT and event.plane == enemy:
				hits += 1
	assert_int(hits).is_greater(0)
	assert_float(enemy.state.vel.x).is_greater(_world.player.state.vel.x + 0.5)
	# A Shell bursting below the player pushes it up.
	shooter.input.fire = false
	_hold_in_air(_world.player, 500.0, 100.0, 30.0)
	var before := _world.player.state.vel.y
	var shell := Shell.new()  # 8 m below: 20 damage, a quarter of the full shove
	shell.position = Vector2(500.0, 92.0)
	shell.velocity = Vector2(30.0, 0.0)
	shell.fuse = DT / 2.0
	_world.guns.shells.append(shell)
	_step(DT)
	assert_bool(_world.player.is_alive()).is_true()
	assert_float(_world.player.state.vel.y - before).is_greater(Knockback.BLAST_MAX / 4.0 - 0.5)


# --- Squadrons: more than one Aloft, Wingmen, Shoot Down ---


## A World on the fixture's map and targets with this mission, the player on a fighter.
func _world_with(mission: MissionDefinition) -> void:
	_world = World.create(_map(), _targets(), mission, null, Side.BLUE, 1, 1.8)
	_world.add_player(TestLoadouts.fighter(), ScriptedPilot.holding(false))
	_events = []


func _planes_of(side: int) -> Array[WorldPlane]:
	var found: Array[WorldPlane] = []
	for plane in _world.planes:
		if plane != _world.player and plane.side == side and plane.is_alive():
			found.append(plane)
	return found


func test_the_enemy_keeps_several_aloft_spaced_by_the_interval_each_slot_with_its_preset() -> void:
	var mission := _mission()
	mission.enemy_aloft = 3
	mission.enemy_pool = 0
	mission.spawn_interval = 6.0
	mission.enemy_loadouts = [TestLoadouts.fighter(), Loadout.of([TestLoadouts.bomb_rack()])]
	_world_with(mission)
	_step(0.1)
	assert_int(_world.enemies_alive()).is_equal(1)
	_step(5.8)
	assert_int(_world.enemies_alive()).is_equal(1)
	_step(0.2)
	assert_int(_world.enemies_alive()).is_equal(2)
	_step(6.0)
	assert_int(_world.enemies_alive()).is_equal(3)
	var reds := _planes_of(Side.RED)
	assert_object(reds[0].loadout).is_same(mission.enemy_loadouts[0])
	assert_object(reds[1].loadout).is_same(mission.enemy_loadouts[1])
	assert_object(reds[2].loadout).is_same(mission.enemy_loadouts[1])  # the last repeats
	for red in reds:
		assert_bool(red.pilot is AiPilot).is_true()
	# The second slot's Plane goes down: its replacement flies the same preset, after the
	# respawn delay once the interval since the last launch has passed.
	_step(8.0)  # well past the last launch
	var lost := reds[1]
	_hold_in_air(lost, 300.0, 5.0, 30.0)  # below the ground: dead next step
	_step(DT)
	assert_int(_world.enemies_alive()).is_equal(2)
	_step(1.7)
	assert_int(_world.enemies_alive()).is_equal(2)
	_step(0.2)
	assert_int(_world.enemies_alive()).is_equal(3)
	var replacement := _planes_of(Side.RED)[2]
	assert_object(replacement.loadout).is_same(mission.enemy_loadouts[1])
	assert_int(_world.enemies_left()).is_equal(-1)  # as many as it likes
	assert_bool(_world.enemy_grounded()).is_false()


func test_wingmen_fly_for_the_players_side_from_the_home_airfield() -> void:
	var mission := _mission()
	mission.wingmen_aloft = 2
	mission.wingmen_loadouts = [Loadout.of([TestLoadouts.ammunition_box()])]
	_world_with(mission)
	_step(0.1)
	var blues := _planes_of(Side.BLUE)
	assert_int(blues.size()).is_equal(2)
	assert_int(_world.wingmen_alive()).is_equal(2)
	assert_int(_world.enemies_alive()).is_equal(1)
	for wingman in blues:
		assert_bool(wingman.pilot is AiPilot).is_true()
		assert_object(wingman.loadout).is_same(mission.wingmen_loadouts[0])
		assert_bool(wingman.state.heading_right()).is_true()
		assert_object(_world.map.airfield_at(wingman.state.position.x)).is_same(
			_world.map.home_airfield(Side.BLUE)
		)
	var spawned := 0
	for event in _of_kind(WorldEvent.Kind.PLANE_SPAWNED):
		if blues.has(event.plane):
			spawned += 1
	assert_int(spawned).is_equal(2)
	_step(12.0)
	for wingman in blues:
		assert_bool(wingman.is_alive()).is_true()
		assert_bool(wingman.state.on_airfield).is_false()
	# A Wingman lost is replaced; with the Home Hangar gone, it is not.
	_hold_in_air(blues[0], 300.0, 5.0, 30.0)
	_step(_world.respawn_delay + 0.1)
	assert_int(_world.wingmen_alive()).is_equal(2)
	_world.target_named("HomeHangar").damage(GroundTarget.BOMB_DAMAGE)
	_hold_in_air(_planes_of(Side.BLUE)[0], 300.0, 5.0, 30.0)
	_step(_world.respawn_delay + 0.1)
	assert_int(_world.wingmen_alive()).is_equal(1)
	assert_int(_world.enemies_alive()).is_equal(1)  # the enemy's Squadron is its own


func test_a_wingman_the_player_shoots_down_is_nobodys_kill() -> void:
	var mission := _mission()
	mission.wingmen_aloft = 1
	_world_with(mission)
	_step(DT)
	var wingman := _planes_of(Side.BLUE)[0]
	wingman.pilot = ScriptedPilot.holding(false)
	_hold_in_air(wingman, 300.0, 100.0, 30.0)
	wingman.state.hit_points = 1
	var shooter := ScriptedPilot.holding(false)
	shooter.input.fire = true
	_world.player.pilot = shooter
	_hold_in_air(_world.player, 280.0, 100.0, 30.0)
	_step(0.5)
	assert_bool(wingman.state.in_spin).is_true()
	assert_int(_world.kills).is_equal(0)
	shooter.input.fire = false
	_step(5.0)
	assert_bool(wingman.is_alive()).is_false()
	assert_int(_world.kills).is_equal(0)
	assert_int(_world.wingmen_alive()).is_equal(1)  # replaced all the same


func test_a_shoot_down_objective_is_won_by_the_count() -> void:
	var mission := _mission()
	mission.objectives = [Objective.shoot_down(1, true, "Down one")]
	_world_with(mission)
	_step(DT)
	assert_int(_status("")).is_equal(MissionRules.Status.OPEN)
	var enemy := _enemy()
	enemy.pilot = ScriptedPilot.holding(false)  # stays parked on the runway
	var pilot := ScriptedPilot.holding(false)
	_world.player.pilot = pilot
	_hold_in_air(_world.player, enemy.state.position.x, enemy.state.position.y + 40.0, 0.0)
	pilot.input.bomb = true
	_step(DT)
	var waited := 0.0
	while enemy.is_alive() and waited < 5.0:
		_step(DT)
		waited += DT
	assert_int(_world.kills).is_equal(1)
	assert_int(_status("")).is_equal(MissionRules.Status.COMPLETE)
	assert_int(_world.outcome).is_equal(MissionRules.Outcome.WON)


func test_a_shoot_down_objective_is_also_won_once_the_enemy_is_grounded() -> void:
	var mission := _mission()
	mission.objectives = [Objective.shoot_down(5)]
	mission.enemy_pool = 0
	_world_with(mission)
	_step(DT)
	_world.target_named("EnemyHangar").damage(GroundTarget.BOMB_DAMAGE)
	_step(DT)
	assert_bool(_world.enemy_grounded()).is_false()  # one still Aloft
	assert_int(_world.outcome).is_equal(MissionRules.Outcome.ONGOING)
	_hold_in_air(_enemy(), 300.0, 5.0, 30.0)  # into the ground: nobody's kill
	_step(_world.respawn_delay + 0.1)
	assert_int(_world.kills).is_equal(0)
	assert_int(_world.enemies_alive()).is_equal(0)
	assert_bool(_world.enemy_grounded()).is_true()
	assert_int(_world.outcome).is_equal(MissionRules.Outcome.WON)


func test_a_finite_pool_spent_by_losses_that_are_nobodys_also_grounds_the_enemy() -> void:
	var mission := _mission()
	mission.objectives = [Objective.shoot_down(5)]
	mission.enemy_pool = 2
	_world_with(mission)
	for life in 2:
		_step(DT)
		_hold_in_air(_enemy(), 300.0, 5.0, 30.0)
		_step(_world.respawn_delay + 0.1)
	assert_int(_world.enemies_left()).is_equal(0)
	assert_int(_world.enemies_alive()).is_equal(0)
	assert_bool(_world.enemy_grounded()).is_true()
	assert_int(_world.outcome).is_equal(MissionRules.Outcome.WON)


func test_the_first_launch_on_either_side_waits_for_the_missions_delay() -> void:
	var mission := _mission()
	mission.first_launch_delay = 5.0
	mission.wingmen_aloft = 1
	_world_with(mission)
	_step(4.9)
	assert_int(_world.enemies_alive()).is_equal(0)
	assert_int(_world.wingmen_alive()).is_equal(0)
	assert_int(_world.planes.size()).is_equal(1)
	_step(0.2)
	assert_int(_world.enemies_alive()).is_equal(1)
	assert_int(_world.wingmen_alive()).is_equal(1)
	assert_bool(_world.enemy_grounded()).is_false()
