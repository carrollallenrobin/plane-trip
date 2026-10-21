extends GdUnitTestSuite

const DT := 1.0 / 60.0

var _guns: GroundGuns
var _combat: AirCombat
var _map: WorldMap


func before_test() -> void:
	_guns = GroundGuns.new(4)
	_combat = AirCombat.new()
	_map = WorldMap.new()
	_map.bounds = WorldBounds.create(960.0, 160.0)
	_map.terrain = Terrain.from_points(
		PackedVector2Array([Vector2(0.0, 10.0), Vector2(960.0, 10.0)])
	)


func _plane(side: int, x: float, y: float) -> PlaneState:
	var s := TestLoadouts.plane(side, 1)
	s.position = Vector2(x, y)
	s.set_speed_along_nose(30.0)
	return s


func _aa(x: float) -> GroundTarget:
	return GroundTarget.create(
		"aa", Side.RED, GroundTarget.Kind.ANTI_AIRCRAFT_GUN, Vector2(x, 10.0), 6.0, 4.0
	)


func _flak(x: float) -> GroundTarget:
	return GroundTarget.create(
		"flak", Side.RED, GroundTarget.Kind.FLAK_GUN, Vector2(x, 10.0), 6.0, 4.0
	)


func test_an_anti_aircraft_gun_fires_bursts_at_an_enemy_overhead() -> void:
	var planes: Array[PlaneState] = [_plane(Side.BLUE, 300.0, 60.0)]
	var targets: Array[GroundTarget] = [_aa(300.0)]
	_guns.step(DT, _map, planes, targets, _combat)
	assert_int(_combat.bullets.size()).is_equal(1)
	assert_int(_combat.bullets[0].owner_id).is_equal(-1)
	assert_float(_combat.bullets[0].velocity.y).is_greater(0.0)
	assert_float(_combat.bullets[0].velocity.length()).is_equal_approx(
		GroundGuns.AA_MUZZLE_SPEED, 0.01
	)
	# The shot is reported from the barrel, pointing the way the round went.
	assert_int(_guns.shots.size()).is_equal(1)
	assert_object(_guns.shots[0].gun).is_same(targets[0])
	assert_vector(_guns.shots[0].position).is_equal(_combat.bullets[0].position)
	assert_vector(_guns.shots[0].direction).is_equal_approx(
		_combat.bullets[0].velocity.normalized(), Vector2(0.001, 0.001)
	)
	# The burst: six rounds one original tick apart, then a pause before the next burst.
	_run(planes, targets, GroundGuns.BURST_ROUNDS * GroundGuns.BURST_INTERVAL)
	assert_int(_combat.bullets.size()).is_equal(GroundGuns.BURST_ROUNDS)
	_run(planes, targets, GroundGuns.BURST_PAUSE / 2.0)
	assert_int(_combat.bullets.size()).is_equal(GroundGuns.BURST_ROUNDS)
	_run(planes, targets, GroundGuns.BURST_PAUSE)
	assert_int(_combat.bullets.size()).is_greater(GroundGuns.BURST_ROUNDS)


func _run(planes: Array[PlaneState], targets: Array[GroundTarget], seconds: float) -> void:
	for i in int(ceil(seconds / DT)):
		_guns.step(DT, _map, planes, targets, _combat)


func test_guns_ignore_friends_planes_out_of_range_and_planes_beside_them() -> void:
	var targets: Array[GroundTarget] = [_aa(300.0)]
	var friend: Array[PlaneState] = [_plane(Side.RED, 300.0, 60.0)]
	_guns.step(DT, _map, friend, targets, _combat)
	var far: Array[PlaneState] = [_plane(Side.BLUE, 400.0, 60.0)]
	_guns.step(DT, _map, far, targets, _combat)
	var low: Array[PlaneState] = [_plane(Side.BLUE, 350.0, 14.0)]  # beside, below the cone
	_guns.step(DT, _map, low, targets, _combat)
	assert_int(_combat.bullets.size()).is_equal(0)
	assert_int(_guns.shots.size()).is_equal(0)


func test_a_flak_gun_fires_shells_that_burst_on_their_fuse() -> void:
	var planes: Array[PlaneState] = [_plane(Side.BLUE, 300.0, 100.0)]
	var targets: Array[GroundTarget] = [_flak(300.0)]
	var bursts: Array[ShellBurst] = []
	var shots := 0
	var t := 0.0
	while bursts.is_empty() and t < 3.0:
		bursts = _guns.step(DT, _map, planes, targets, _combat)
		shots += _guns.shots.size()
		t += DT
	assert_int(bursts.size()).is_equal(1)
	assert_int(shots).is_between(1, 3)  # the Flak Gun's shells are shots too
	assert_float(t).is_between(GroundGuns.FUSE_MIN, GroundGuns.FUSE_MAX + DT)
	assert_float(bursts[0].position.y).is_greater(50.0)
	assert_int(_combat.bullets.size()).is_equal(0)


func test_burst_damage_falls_off_with_distance() -> void:
	assert_int(ShellBurst.damage_at(0.0)).is_equal(80)
	assert_int(ShellBurst.damage_at(4.0)).is_equal(80)
	assert_int(ShellBurst.damage_at(8.0)).is_equal(20)
	assert_int(ShellBurst.damage_at(16.0)).is_equal(0)


func test_dead_guns_are_silent() -> void:
	var planes: Array[PlaneState] = [_plane(Side.BLUE, 300.0, 60.0)]
	var gun := _aa(300.0)
	gun.damage(GroundTarget.BOMB_DAMAGE)
	var targets: Array[GroundTarget] = [gun]
	for i in 30:
		_guns.step(DT, _map, planes, targets, _combat)
	assert_int(_combat.bullets.size()).is_equal(0)


func test_guns_do_not_aim_at_a_spinning_plane() -> void:
	var spinning := _plane(Side.BLUE, 300.0, 60.0)
	spinning.hit_points = 0
	spinning.in_spin = true
	var planes: Array[PlaneState] = [spinning]
	var targets: Array[GroundTarget] = [_aa(300.0), _flak(310.0)]
	for i in 30:
		_guns.step(DT, _map, planes, targets, _combat)
	assert_int(_combat.bullets.size()).is_equal(0)
	assert_int(_guns.shells.size()).is_equal(0)


func test_a_shell_bursts_on_a_spinning_plane_but_not_on_a_destroyed_one() -> void:
	var spinning := _plane(Side.BLUE, 300.0, 60.0)
	spinning.hit_points = 0
	spinning.in_spin = true
	var shell := Shell.new()
	shell.position = Vector2(300.0, 59.0)
	shell.velocity = Vector2(0.0, 60.0)
	shell.fuse = 10.0
	_guns.shells.append(shell)
	var planes: Array[PlaneState] = [spinning]
	var bursts := _guns.step(DT, _map, planes, [], _combat)
	assert_int(bursts.size()).is_equal(1)
	assert_int(_guns.shells.size()).is_equal(0)
	spinning.destroyed = true
	var again := Shell.new()
	again.position = Vector2(300.0, 59.0)
	again.velocity = Vector2(0.0, 60.0)
	again.fuse = 10.0
	_guns.shells.append(again)
	bursts = _guns.step(DT, _map, planes, [], _combat)
	assert_int(bursts.size()).is_equal(0)
	assert_int(_guns.shells.size()).is_equal(1)
