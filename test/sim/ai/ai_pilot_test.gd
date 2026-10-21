extends GdUnitTestSuite
## Runs the AI pilot against the flight model on small worlds. Each test states a behaviour of
## the original AI (docs/research/triplane-classic-mechanics.md, section 6).

const DT := 1.0 / 60.0
const GROUND := 10.0

var _model: FlightModel
var _map: WorldMap
var _home: Airfield
var _pilot: AiPilot
var _crash := CrashRules.Outcome.NONE
var _fired := 0
var _landed := false
var _turned_around := false
var _combat: AirCombat
var _bombs_dropped := 0


func before_test() -> void:
	_model = FlightModel.new()
	_map = WorldMap.new()
	_map.bounds = WorldBounds.create(960.0, 160.0)
	_map.terrain = Terrain.from_points(
		PackedVector2Array([Vector2(0.0, GROUND), Vector2(960.0, GROUND)])
	)
	_home = Airfield.create(Side.RED, 820.0, 900.0, GROUND)
	_map.airfields.append(_home)
	_pilot = AiPilot.create(_map, _home)
	_crash = CrashRules.Outcome.NONE
	_fired = 0
	_landed = false
	_turned_around = false
	_combat = AirCombat.new()
	_combat.gravity = _model.tuning.gravity
	_bombs_dropped = 0


func _red(x: float, y: float, angle: float, speed: float, id := 1) -> PlaneState:
	var s := TestLoadouts.plane(Side.RED, id)
	s.position = Vector2(x, y)
	s.angle = angle
	s.set_speed_along_nose(speed)
	return s


func _blue(x: float, y: float, angle: float, speed: float, id := 2) -> PlaneState:
	var s := _red(x, y, angle, speed, id)
	s.side = Side.BLUE
	return s


## Fly for up to `seconds`, stopping early on a crash. Others are static.
func _run(
	s: PlaneState, seconds: float, others: Array[PlaneState] = [], targets: Array[GroundTarget] = []
) -> void:
	for i in int(round(seconds / DT)):
		var input := _pilot.decide(s, others, targets, DT)
		if input.bomb and _combat.try_drop(s, input):
			_bombs_dropped += 1
		if _pilot.mission == AiPilot.Mission.TURNAROUND:
			_turned_around = true
		if input.fire and s.gun_cooldown <= 0.0:
			_fired += 1
			s.gun_cooldown = FlightModel.GUN_INTERVAL
		_model.step(s, input, _map.environment_at(s.position.x), DT)
		_crash = CrashRules.check(s, _map)
		if _crash != CrashRules.Outcome.NONE:
			return
		if s.on_airfield and s.speed == 0.0 and _home.contains_x(s.position.x):
			_landed = true
			return


func test_takes_off_and_climbs_clear_of_the_ground() -> void:
	var s := _red(830.0, GROUND + FlightModel.WHEEL_OFFSET + FlightModel.TYRE_OFFSET, 20.0, 0.0)
	s.on_airfield = true
	_run(s, 12.0)
	assert_int(_crash).is_equal(CrashRules.Outcome.NONE)
	assert_bool(s.on_airfield).is_false()
	assert_float(s.position.y - GROUND).is_greater(4.0)
	assert_int(_pilot.mission).is_not_equal(AiPilot.Mission.TAKEOFF)


func test_takes_off_heading_left_from_a_left_facing_airfield() -> void:
	_home.heading_right = false
	var s := _red(890.0, GROUND + FlightModel.WHEEL_OFFSET + FlightModel.TYRE_OFFSET, 160.0, 0.0)
	s.upside_down = true
	s.on_airfield = true
	_run(s, 12.0)
	assert_int(_crash).is_equal(CrashRules.Outcome.NONE)
	assert_bool(s.on_airfield).is_false()
	assert_bool(s.heading_right()).is_false()
	assert_float(s.position.x).is_less(800.0)


func test_climbs_over_a_hill_in_its_path() -> void:
	_map.terrain = Terrain.from_points(
		PackedVector2Array(
			[
				Vector2(0.0, GROUND),
				Vector2(400.0, GROUND),
				Vector2(600.0, 45.0),
				Vector2(800.0, GROUND),
				Vector2(960.0, GROUND)
			]
		)
	)
	_pilot.mission = AiPilot.Mission.NOMISSION
	var s := _red(250.0, 25.0, 0.0, 30.0)
	_run(s, 14.0)
	assert_int(_crash).is_equal(CrashRules.Outcome.NONE)
	assert_float(s.position.x).is_greater(600.0)


func test_turns_around_before_the_border() -> void:
	_pilot.mission = AiPilot.Mission.NOMISSION
	var s := _red(700.0, 80.0, 0.0, 30.0)
	_run(s, 15.0)
	assert_int(_crash).is_equal(CrashRules.Outcome.NONE)
	assert_float(s.position.x).is_between(0.0, 960.0)
	assert_bool(_turned_around).is_true()


func test_chases_and_shoots_an_enemy_ahead() -> void:
	_pilot.mission = AiPilot.Mission.NOMISSION
	var s := _red(300.0, 80.0, 0.0, 30.0)
	var enemy := _blue(350.0, 84.0, 0.0, 30.0)
	_run(s, 2.0, [enemy])
	assert_int(_pilot.target_id).is_equal(enemy.id)
	assert_int(_fired).is_greater(0)
	assert_int(_crash).is_equal(CrashRules.Outcome.NONE)


func test_holds_fire_with_a_friend_in_the_line() -> void:
	_pilot.mission = AiPilot.Mission.NOMISSION
	var s := _red(300.0, 80.0, 0.0, 30.0)
	var friend := _red(330.0, 80.0, 0.0, 30.0, 3)
	var enemy := _blue(360.0, 80.0, 0.0, 30.0)
	_run(s, 0.5, [friend, enemy])
	assert_int(_fired).is_equal(0)


func test_ignores_enemies_out_of_range() -> void:
	_pilot.mission = AiPilot.Mission.NOMISSION
	var s := _red(100.0, 80.0, 0.0, 30.0)
	var enemy := _blue(300.0, 80.0, 0.0, 30.0)
	_run(s, 1.0, [enemy])
	assert_int(_pilot.mission).is_not_equal(AiPilot.Mission.CHASE_PLANE)
	assert_int(_fired).is_equal(0)


func test_comes_home_and_lands_when_out_of_ammunition() -> void:
	_pilot.mission = AiPilot.Mission.NOMISSION
	var s := _red(300.0, 60.0, 0.0, 30.0)
	s.rounds = 0
	s.bombs = 0
	_run(s, 120.0)
	assert_int(_crash).is_equal(CrashRules.Outcome.NONE)
	assert_bool(_landed).is_true()


func test_releases_a_bomb_that_lands_on_an_enemy_structure() -> void:
	_pilot.mission = AiPilot.Mission.NOMISSION
	var depot := GroundTarget.create(
		"depot", Side.BLUE, GroundTarget.Kind.BUILDING, Vector2(300.0, GROUND), 14.0, 6.0
	)
	var own := GroundTarget.create(
		"hangar", Side.RED, GroundTarget.Kind.HANGAR, Vector2(150.0, GROUND), 16.0, 6.0
	)
	var s := _red(60.0, 60.0, 0.0, 30.0)
	_run(s, 8.0, [], [depot, own])
	assert_int(_crash).is_equal(CrashRules.Outcome.NONE)
	assert_int(_bombs_dropped).is_equal(1)
	var impacts: Array[BombImpact] = []
	var steps := 0
	while impacts.is_empty() and steps < 600:
		impacts = _combat.step_bombs(DT, _map, [], [depot, own])
		steps += 1
	assert_int(impacts.size()).is_equal(1)
	assert_object(impacts[0].ground_target).is_same(depot)


func test_a_new_life_starts_with_the_take_off() -> void:
	_pilot.mission = AiPilot.Mission.CHASE_PLANE
	_pilot.target_id = 7
	_pilot.phase = 2
	_pilot.start_life()
	assert_int(_pilot.mission).is_equal(AiPilot.Mission.TAKEOFF)
	assert_int(_pilot.phase).is_equal(0)
	assert_int(_pilot.target_id).is_equal(-1)
