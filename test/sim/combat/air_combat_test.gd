extends GdUnitTestSuite

const DT := 1.0 / 60.0

var _combat: AirCombat
var _map: WorldMap


func before_test() -> void:
	_combat = AirCombat.new()
	_map = WorldMap.new()
	_map.bounds = WorldBounds.create(960.0, 160.0)
	_map.terrain = Terrain.from_points(
		PackedVector2Array([Vector2(0.0, 10.0), Vector2(960.0, 10.0)])
	)


func _plane(id: int, side: int, x: float, y: float, angle := 0.0, speed := 30.0) -> PlaneState:
	var s := TestLoadouts.plane(side, id)
	s.position = Vector2(x, y)
	s.angle = angle
	s.set_speed_along_nose(speed)
	return s


func _trigger() -> FlightInput:
	var input := FlightInput.new()
	input.fire = true
	return input


func test_firing_spends_a_round_and_respects_the_rate_of_fire() -> void:
	var s := _plane(1, Side.BLUE, 100.0, 80.0)
	assert_object(_combat.try_fire(s, _trigger())).is_not_null()
	assert_int(s.rounds).is_equal(s.max_rounds() - 1)
	assert_object(_combat.try_fire(s, _trigger())).is_null()
	# Six rounds per second: a second of holding the trigger fires six.
	var fired := 1
	for i in 60:
		var model := FlightModel.new()
		model.step(s, FlightInput.new(), _map.environment_at(s.position.x), DT)
		if _combat.try_fire(s, _trigger()):
			fired += 1
	assert_int(fired).is_between(6, 7)
	assert_object(_combat.try_fire(s, FlightInput.new())).is_null()


func test_empty_gun_does_not_fire() -> void:
	var s := _plane(1, Side.BLUE, 100.0, 80.0)
	s.rounds = 0
	assert_object(_combat.try_fire(s, _trigger())).is_null()
	assert_int(_combat.bullets.size()).is_equal(0)


func test_bullet_leaves_the_muzzle_at_plane_speed_plus_muzzle_speed() -> void:
	var s := _plane(1, Side.BLUE, 100.0, 80.0, 0.0, 30.0)
	_combat.try_fire(s, _trigger())
	var bullet := _combat.bullets[0]
	assert_vector(bullet.position).is_equal_approx(Vector2(104.8, 80.0), Vector2(0.01, 0.01))
	assert_float(bullet.velocity.x).is_equal_approx(30.0 + 37.5, 0.01)


func test_bullets_arc_down_and_expire_at_the_original_range() -> void:
	var s := _plane(1, Side.BLUE, 100.0, 80.0, 0.0, SimUnits.speed_from_original(2000.0))
	_combat.try_fire(s, _trigger())
	var planes: Array[PlaneState] = [s]
	var last := Vector2.ZERO
	var steps := 0
	while not _combat.bullets.is_empty():
		last = _combat.bullets[0].position
		_combat.step(DT, _map, planes)
		steps += 1
	# Original: about 1.15 s and 160 px (64 m) at speed 2000; ours flies half again as long.
	assert_float(steps * DT).is_between(1.7, 1.8)
	assert_float(last.x - 104.8).is_between(93.0, 101.0)
	assert_float(last.y).is_less(80.0)
	assert_float(80.0 - last.y).is_less(6.0)


func test_bullets_die_on_the_ground_and_at_the_borders() -> void:
	var down := _plane(1, Side.BLUE, 100.0, 12.0, 270.0)
	var out := _plane(2, Side.BLUE, 958.0, 80.0, 0.0)
	_combat.try_fire(down, _trigger())
	_combat.try_fire(out, _trigger())
	assert_int(_combat.bullets.size()).is_equal(2)
	var planes: Array[PlaneState] = [down, out]
	var hits := _combat.step(DT, _map, planes)
	assert_int(_combat.bullets.size()).is_equal(0)
	# The one into the ground ends on it, at the surface; the one over the Border is just gone.
	assert_int(hits.size()).is_equal(1)
	assert_int(hits[0].surface).is_equal(BulletHit.Surface.GROUND)
	assert_float(hits[0].position.y).is_equal_approx(10.0, 0.001)
	assert_float(hits[0].position.x).is_equal_approx(100.0, 0.1)
	assert_vector(hits[0].direction()).is_equal_approx(Vector2(0.0, -1.0), Vector2(0.05, 0.05))


func test_a_bullet_into_water_ends_on_water() -> void:
	_map.terrain.add_water(90.0, 110.0)
	var down := _plane(1, Side.BLUE, 100.0, 12.0, 270.0)
	_combat.try_fire(down, _trigger())
	var planes: Array[PlaneState] = [down]
	var hits := _combat.step(DT, _map, planes)
	assert_int(hits.size()).is_equal(1)
	assert_int(hits[0].surface).is_equal(BulletHit.Surface.WATER)


func test_bullet_strikes_an_enemy_plane_in_front_but_never_the_shooter() -> void:
	var shooter := _plane(1, Side.BLUE, 100.0, 80.0, 0.0, 30.0)
	var target := _plane(2, Side.RED, 110.0, 80.0, 0.0, 30.0)
	_combat.try_fire(shooter, _trigger())
	var planes: Array[PlaneState] = [shooter, target]
	var hits: Array[BulletHit] = []
	for i in 10:
		hits.append_array(_combat.step(DT, _map, planes))
	assert_int(hits.size()).is_equal(1)
	assert_int(hits[0].surface).is_equal(BulletHit.Surface.PLANE)
	assert_object(hits[0].target).is_same(target)
	assert_bool(target.contains_point(hits[0].position)).is_true()
	assert_vector(hits[0].direction()).is_equal_approx(Vector2.RIGHT, Vector2(0.05, 0.05))
	assert_int(_combat.bullets.size()).is_equal(0)


func test_hit_box_follows_the_plane_angle() -> void:
	var s := _plane(1, Side.BLUE, 0.0, 0.0, 90.0)
	assert_bool(s.contains_point(Vector2(0.0, 3.5))).is_true()
	assert_bool(s.contains_point(Vector2(3.5, 0.0))).is_false()
	assert_bool(s.contains_point(Vector2(2.0, 0.0))).is_true()


func test_a_bomb_leaves_the_belly_with_the_planes_velocity_and_falls() -> void:
	var s := _plane(1, Side.BLUE, 100.0, 80.0, 0.0, 30.0)
	var input := FlightInput.new()
	input.bomb = true
	assert_object(_combat.try_drop(s, input)).is_not_null()
	assert_int(s.bombs).is_equal(3)
	var bomb := _combat.bombs[0]
	assert_vector(bomb.position).is_equal_approx(
		Vector2(100.0, 80.0 - AirCombat.BOMB_RELEASE_OFFSET), Vector2(0.01, 0.01)
	)
	assert_vector(bomb.velocity).is_equal_approx(Vector2(30.0, 0.0), Vector2(0.01, 0.01))
	var planes: Array[PlaneState] = [s]
	var impacts: Array[BombImpact] = []
	var steps := 0
	while impacts.is_empty() and steps < 600:
		impacts = _combat.step_bombs(DT, _map, planes, [])
		steps += 1
	assert_int(impacts.size()).is_equal(1)
	assert_object(impacts[0].plane).is_null()
	assert_object(impacts[0].ground_target).is_null()
	assert_float(impacts[0].position.y).is_equal_approx(10.0, 0.001)
	# About sqrt(2 h / g) seconds to fall 66 m at 9 m/s^2.
	assert_float(steps * DT).is_between(3.5, 4.2)


func test_bombs_release_one_interval_apart_while_the_key_is_held() -> void:
	var s := _plane(1, Side.BLUE, 100.0, 80.0, 0.0, 30.0)
	var input := FlightInput.new()
	input.bomb = true
	assert_object(_combat.try_drop(s, input)).is_not_null()
	assert_object(_combat.try_drop(s, input)).is_null()
	var model := FlightModel.new()
	var released := 1
	for i in int(round(2.5 * AirCombat.BOMB_INTERVAL / DT)):  # the second and third intervals
		model.step(s, FlightInput.new(), _map.environment_at(s.position.x), DT)
		if _combat.try_drop(s, input) != null:
			released += 1
	assert_int(released).is_equal(3)
	assert_int(s.bombs).is_equal(1)


func test_no_bombs_on_the_airfield_or_with_an_empty_rack() -> void:
	var s := _plane(1, Side.BLUE, 100.0, 12.0)
	s.on_airfield = true
	var input := FlightInput.new()
	input.bomb = true
	assert_object(_combat.try_drop(s, input)).is_null()
	s.on_airfield = false
	s.bombs = 0
	assert_object(_combat.try_drop(s, input)).is_null()


func test_a_bomb_landing_on_a_target_names_it() -> void:
	var s := _plane(1, Side.BLUE, 300.0, 80.0, 0.0, 0.0)
	var house := GroundTarget.create(
		"house", Side.RED, GroundTarget.Kind.BUILDING, Vector2(300.0, 10.0), 10.0, 6.0
	)
	var input := FlightInput.new()
	input.bomb = true
	_combat.try_drop(s, input)
	var planes: Array[PlaneState] = [s]
	var targets: Array[GroundTarget] = [house]
	var impacts: Array[BombImpact] = []
	var steps := 0
	while impacts.is_empty() and steps < 600:
		impacts = _combat.step_bombs(DT, _map, planes, targets)
		steps += 1
	assert_object(impacts[0].ground_target).is_same(house)


func test_bullets_stop_at_buildings_and_wound_guns() -> void:
	var shooter := _plane(1, Side.BLUE, 280.0, 13.0, 0.0, 30.0)
	var house := GroundTarget.create(
		"house", Side.RED, GroundTarget.Kind.BUILDING, Vector2(300.0, 10.0), 10.0, 6.0
	)
	var gun := GroundTarget.create(
		"aa", Side.RED, GroundTarget.Kind.ANTI_AIRCRAFT_GUN, Vector2(330.0, 10.0), 6.0, 4.0
	)
	_combat.try_fire(shooter, _trigger())
	var planes: Array[PlaneState] = [shooter]
	var targets: Array[GroundTarget] = [house, gun]
	var hits: Array[BulletHit] = []
	for i in 30:
		hits.append_array(_combat.step(DT, _map, planes, targets))
	assert_int(hits.size()).is_equal(1)  # the house swallowed it
	assert_int(hits[0].surface).is_equal(BulletHit.Surface.TARGET)
	assert_object(hits[0].ground_target).is_same(house)
	assert_bool(house.contains(hits[0].position)).is_true()
	assert_int(_combat.bullets.size()).is_equal(0)
	shooter.position = Vector2(315.0, 12.5)
	shooter.gun_cooldown = 0.0
	_combat.try_fire(shooter, _trigger())
	for i in 30:
		hits.append_array(_combat.step(DT, _map, planes, targets))
	assert_int(hits.size()).is_equal(2)
	assert_object(hits[1].ground_target).is_same(gun)


func test_a_bomb_blasts_a_spinning_plane_and_bullets_strike_it() -> void:
	var shooter := _plane(1, Side.BLUE, 100.0, 80.0, 0.0, 30.0)
	var spinning := _plane(2, Side.RED, 110.0, 80.0, 0.0, 30.0)
	spinning.hit_points = 0
	spinning.in_spin = true
	var planes: Array[PlaneState] = [shooter, spinning]
	_combat.try_fire(shooter, _trigger())
	var hits: Array[BulletHit] = []
	for i in 10:
		hits.append_array(_combat.step(DT, _map, planes))
	assert_int(hits.size()).is_equal(1)  # the strike is reported; DamageRules ignores it
	assert_object(hits[0].target).is_same(spinning)
	var bomber := _plane(3, Side.BLUE, 110.0, 90.0, 0.0, 0.0)
	var input := FlightInput.new()
	input.bomb = true
	_combat.try_drop(bomber, input)
	planes.append(bomber)
	var impacts: Array[BombImpact] = []
	var steps := 0
	while impacts.is_empty() and steps < 600:
		impacts = _combat.step_bombs(DT, _map, planes, [])
		steps += 1
	assert_object(impacts[0].plane).is_same(spinning)


func test_a_destroyed_plane_is_never_struck() -> void:
	var shooter := _plane(1, Side.BLUE, 100.0, 80.0, 0.0, 30.0)
	var gone := _plane(2, Side.RED, 110.0, 80.0, 0.0, 30.0)
	gone.destroyed = true
	var planes: Array[PlaneState] = [shooter, gone]
	_combat.try_fire(shooter, _trigger())
	var hits: Array[BulletHit] = []
	for i in 10:
		hits.append_array(_combat.step(DT, _map, planes))
	assert_int(hits.size()).is_equal(0)
	var bomber := _plane(3, Side.BLUE, 110.0, 90.0, 0.0, 0.0)
	var input := FlightInput.new()
	input.bomb = true
	_combat.try_drop(bomber, input)
	planes.append(bomber)
	var impacts: Array[BombImpact] = []
	var steps := 0
	while impacts.is_empty() and steps < 600:
		impacts = _combat.step_bombs(DT, _map, planes, [])
		steps += 1
	assert_object(impacts[0].plane).is_null()
	assert_float(impacts[0].position.y).is_equal_approx(10.0, 0.001)
