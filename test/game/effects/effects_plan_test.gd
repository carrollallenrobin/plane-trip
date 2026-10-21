extends GdUnitTestSuite
## Muzzle Flashes, Casings, impact puffs and sparks as the plan keeps them: how long they
## live, where they go.

const DT := 1.0 / 60.0

var _plan: EffectsPlan


func before_test() -> void:
	_plan = EffectsPlan.new(7)


func _plane(x: float, y: float, angle := 0.0, speed := 30.0, id := 1) -> PlaneState:
	var s := TestLoadouts.plane(Side.BLUE, id)
	s.position = Vector2(x, y)
	s.angle = angle
	s.set_speed_along_nose(speed)
	return s


func test_a_flash_lives_its_life_and_goes() -> void:
	_plan.gun_fired(Vector2(10.0, 20.0), Vector2.RIGHT)
	assert_int(_plan.flashes.size()).is_equal(1)
	assert_float(_plan.flashes[0].remaining()).is_equal(1.0)
	_plan.advance(EffectsPlan.FLASH_LIFE / 2.0)
	assert_float(_plan.flashes[0].remaining()).is_equal_approx(0.5, 0.001)
	_plan.advance(EffectsPlan.FLASH_LIFE)
	assert_int(_plan.flashes.size()).is_equal(0)


func test_a_planes_flash_rides_its_muzzle_while_a_ground_guns_stays_put() -> void:
	var plane := _plane(100.0, 50.0, 90.0)
	_plan.gun_fired(Vector2(100.0, 54.8), Vector2(0.0, 1.0), plane)
	_plan.gun_fired(Vector2(300.0, 14.0), Vector2(0.3, 0.95).normalized())
	plane.position = Vector2(110.0, 50.0)
	plane.angle = 0.0
	assert_vector(_plan.flashes[0].where()).is_equal_approx(
		Vector2(110.0 + AirCombat.MUZZLE_OFFSET, 50.0), Vector2(0.001, 0.001)
	)
	assert_vector(_plan.flashes[0].heading()).is_equal_approx(Vector2.RIGHT, Vector2(0.001, 0.001))
	assert_vector(_plan.flashes[1].where()).is_equal(Vector2(300.0, 14.0))
	assert_float(_plan.flashes[1].heading().y).is_greater(0.9)


func test_only_a_planes_gun_throws_casings_two_per_shot_from_the_breech() -> void:
	_plan.gun_fired(Vector2(300.0, 14.0), Vector2(0.0, 1.0))
	assert_int(_plan.casings.size()).is_equal(0)
	var plane := _plane(100.0, 50.0, 0.0, 30.0)
	_plan.gun_fired(Vector2(104.8, 50.0), Vector2.RIGHT, plane)
	assert_int(_plan.casings.size()).is_equal(EffectsPlan.CASINGS_PER_SHOT)
	for casing in _plan.casings:
		assert_vector(casing.position).is_equal_approx(
			Vector3(104.8 - EffectsPlan.BREECH_BEHIND_MUZZLE, 50.0, 0.0), Vector3.ONE * 0.001
		)
		# Carried by the plane at 30 m/s, thrown back a little, up a little, and toward the camera.
		assert_float(casing.velocity.x).is_between(
			30.0 - EffectsPlan.CASING_BACKWARD.y, 30.0 - EffectsPlan.CASING_BACKWARD.x
		)
		assert_float(casing.velocity.y).is_between(
			EffectsPlan.CASING_UPWARD.x, EffectsPlan.CASING_UPWARD.y
		)
		assert_float(casing.velocity.z).is_between(
			EffectsPlan.CASING_TOWARD_CAMERA.x, EffectsPlan.CASING_TOWARD_CAMERA.y
		)


func test_casings_fall_tumble_and_are_gone_after_their_life() -> void:
	var plane := _plane(100.0, 50.0, 0.0, 0.0)
	_plan.gun_fired(Vector2(104.8, 50.0), Vector2.RIGHT, plane)
	var casing := _plan.casings[0]
	var start := casing.position
	var angle := casing.angle
	var upward := casing.velocity.y
	_plan.advance(0.5)
	assert_float(casing.velocity.y).is_equal_approx(
		upward - EffectsPlan.CASING_GRAVITY * 0.5, 0.001
	)
	assert_float(casing.position.z).is_greater(start.z)
	assert_float(casing.position.x).is_less(start.x)
	assert_float(casing.angle).is_not_equal(angle)
	for i in int(ceil(EffectsPlan.CASING_LIFE / DT)):
		_plan.advance(DT)
	assert_int(_plan.casings.size()).is_equal(0)


func test_a_full_pool_reuses_the_oldest_slot() -> void:
	var plane := _plane(100.0, 50.0)
	for i in EffectsPlan.MAX_CASINGS:  # more shots than either pool holds
		_plan.gun_fired(Vector2(104.8, 50.0), Vector2.RIGHT, plane)
	assert_int(_plan.flashes.size()).is_equal(EffectsPlan.MAX_FLASHES)
	assert_int(_plan.casings.size()).is_equal(EffectsPlan.MAX_CASINGS)


func test_a_bullet_landing_raises_the_puff_its_surface_gives() -> void:
	_plan.bullet_landed(Vector2(100.0, 10.0), BulletHit.Surface.GROUND)
	_plan.bullet_landed(Vector2(200.0, 10.0), BulletHit.Surface.WATER)
	_plan.bullet_landed(Vector2(300.0, 12.0), BulletHit.Surface.TARGET)
	assert_int(_plan.puffs.size()).is_equal(3)
	assert_int(_plan.puffs[0].kind).is_equal(EffectsPlan.PuffKind.DUST)
	assert_int(_plan.puffs[1].kind).is_equal(EffectsPlan.PuffKind.SPLASH)
	assert_int(_plan.puffs[2].kind).is_equal(EffectsPlan.PuffKind.TICK)
	# A puff starts small where the round landed, then grows, rises and fades.
	var dust := _plan.puffs[0]
	var look := dust.look()
	assert_vector(dust.position()).is_equal(Vector2(100.0, 10.0))
	assert_float(dust.scale()).is_equal(look["scale"].x)
	_plan.advance(look["life"] / 2.0)
	assert_float(dust.position().y).is_equal_approx(10.0 + look["rise"] * look["life"] / 2.0, 0.001)
	assert_float(dust.scale()).is_equal_approx((look["scale"].x + look["scale"].y) / 2.0, 0.001)
	assert_float(dust.remaining()).is_equal_approx(0.5, 0.001)
	# The tick is the shortest-lived; the dust lasts the longest.
	_plan.advance(look["life"] / 2.0)
	assert_int(_plan.puffs.size()).is_equal(0)


func test_sparks_fly_back_off_a_struck_plane_and_fall_away() -> void:
	_plan.plane_struck(Vector2(100.0, 50.0), Vector2.RIGHT)  # hit by a round flying right
	assert_int(_plan.sparks.size()).is_equal(EffectsPlan.SPARKS_PER_HIT)
	for spark in _plan.sparks:
		assert_vector(spark.position).is_equal(Vector2(100.0, 50.0))
		assert_float(spark.velocity.x).is_less(0.0)  # back the way the round came
		assert_float(spark.velocity.length()).is_between(
			EffectsPlan.SPARK_SPEED.x, EffectsPlan.SPARK_SPEED.y
		)
	var spark := _plan.sparks[0]
	var upward := spark.velocity.y
	_plan.advance(0.1)
	assert_float(spark.velocity.y).is_equal_approx(upward - EffectsPlan.SPARK_GRAVITY * 0.1, 0.001)
	assert_float(spark.position.x).is_less(100.0)
	_plan.advance(EffectsPlan.SPARK_LIFE)
	assert_int(_plan.sparks.size()).is_equal(0)


func test_a_bomb_burst_is_a_flash_a_growing_fading_sphere_and_smoke() -> void:
	_plan.bomb_burst(Vector2(100.0, 10.0))
	assert_int(_plan.bursts.size()).is_equal(1)
	var burst := _plan.bursts[0]
	assert_float(burst.scale()).is_equal_approx(
		EffectsPlan.BURST_SCALE.x * EffectsPlan.BOMB_BURST_RADIUS, 0.001
	)
	assert_float(burst.flash_remaining()).is_equal(1.0)
	assert_object(burst.colour).is_equal(EffectsPlan.BURST_COLOR)
	var smoke := _plan.puffs.size()
	assert_int(smoke).is_between(EffectsPlan.BURST_SMOKE.x, EffectsPlan.BURST_SMOKE.y)
	for puff in _plan.puffs:
		assert_int(puff.kind).is_equal(EffectsPlan.PuffKind.SMOKE)
		assert_float(puff.origin.distance_to(Vector2(100.0, 10.0))).is_less(
			EffectsPlan.BOMB_BURST_RADIUS
		)
		assert_float(puff.size).is_between(
			EffectsPlan.BOMB_BURST_RADIUS / 4.0 * EffectsPlan.BURST_SMOKE_SIZE.x,
			EffectsPlan.BOMB_BURST_RADIUS / 4.0 * EffectsPlan.BURST_SMOKE_SIZE.y
		)
	_plan.advance(EffectsPlan.BURST_FLASH_LIFE)
	assert_float(burst.flash_remaining()).is_equal(0.0)
	assert_float(burst.remaining()).is_greater(0.5)
	_plan.advance(EffectsPlan.BURST_LIFE)
	assert_int(_plan.bursts.size()).is_equal(0)
	assert_int(_plan.puffs.size()).is_equal(smoke)  # the smoke lingers
	_plan.advance(EffectsPlan.PUFF_LOOKS[EffectsPlan.PuffKind.SMOKE]["life"])
	assert_int(_plan.puffs.size()).is_equal(0)


func test_a_shell_burst_is_small_grey_and_flashless() -> void:
	_plan.shell_burst(Vector2(100.0, 50.0))
	var burst := _plan.bursts[0]
	assert_float(burst.radius).is_equal(EffectsPlan.SHELL_BURST_RADIUS)
	assert_object(burst.colour).is_equal(EffectsPlan.SHELL_BURST_COLOR)
	assert_float(burst.flash_remaining()).is_equal(0.0)
	assert_int(_plan.puffs.size()).is_equal(EffectsPlan.SHELL_BURST_SMOKE)


func test_smoke_rises_and_drifts_with_its_own_size() -> void:
	var puff := EffectsPlan.Puff.new()
	puff.kind = EffectsPlan.PuffKind.SMOKE
	puff.origin = Vector2(10.0, 10.0)
	puff.size = 2.0
	puff.drift = Vector2(1.0, 0.0)
	var look := puff.look()
	assert_float(puff.scale()).is_equal_approx(look["scale"].x * 2.0, 0.001)
	puff.age = 1.0
	assert_vector(puff.position()).is_equal_approx(
		Vector2(11.0, 10.0 + look["rise"]), Vector2(0.001, 0.001)
	)


func test_a_hurt_plane_trails_smoke_that_thickens_and_darkens_toward_zero() -> void:
	var healthy := _plane(100.0, 50.0)
	var states: Array[PlaneState] = [healthy]
	_plan.trail_damage_smoke(states, 1.0)
	assert_int(_plan.puffs.size()).is_equal(0)
	assert_float(EffectsPlan.damage_smoke_intensity(healthy)).is_equal(0.0)
	var hurt := _plane(200.0, 50.0, 0.0, 30.0, 2)
	hurt.hit_points = int(hurt.max_hit_points() * EffectsPlan.DAMAGE_SMOKE_FROM / 2.0)
	assert_float(EffectsPlan.damage_smoke_intensity(hurt)).is_equal_approx(0.5, 0.05)
	var dying := _plane(300.0, 50.0, 0.0, 30.0, 3)
	dying.hit_points = 0
	dying.in_spin = true
	assert_float(EffectsPlan.damage_smoke_intensity(dying)).is_equal(1.0)
	states = [hurt, dying]
	var hurt_puffs := 0
	var dying_puffs := 0
	for i in 60:
		_plan.trail_damage_smoke(states, DT)
	for puff in _plan.puffs:
		assert_int(puff.kind).is_equal(EffectsPlan.PuffKind.DAMAGE)
		if puff.origin.x < 250.0:
			hurt_puffs += 1
			assert_vector(puff.origin).is_equal_approx(
				Vector2(200.0 + EffectsPlan.DAMAGE_SMOKE_ENGINE, 50.0), Vector2(0.001, 0.001)
			)
		else:
			dying_puffs += 1
			assert_float(puff.colour.r).is_equal_approx(EffectsPlan.DAMAGE_SMOKE_DARK.r, 0.001)
			assert_float(puff.size).is_equal(EffectsPlan.DAMAGE_SMOKE_SIZE.y)
	assert_int(dying_puffs).is_greater(hurt_puffs)
	assert_int(hurt_puffs).is_between(4, 7)  # about every 0.18 s at half intensity
	assert_int(dying_puffs).is_between(14, 18)  # every 0.06 s


func test_shells_in_flight_leave_a_trail_of_puffs() -> void:
	var shell := Shell.new()
	shell.position = Vector2(100.0, 50.0)
	shell.velocity = Vector2(0.0, 75.0)
	var shells: Array[Shell] = [shell]
	for i in 30:
		shell.position += shell.velocity * DT
		_plan.trail_shells(shells, DT)
	assert_int(_plan.puffs.size()).is_between(8, 11)  # one every 0.05 s over 0.5 s, at 60 Hz
	for puff in _plan.puffs:
		assert_int(puff.kind).is_equal(EffectsPlan.PuffKind.SHELL_TRAIL)
		assert_float(puff.origin.x).is_equal(100.0)
	assert_float(_plan.puffs[0].origin.y).is_less(_plan.puffs.back().origin.y)
