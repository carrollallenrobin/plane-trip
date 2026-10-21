extends GdUnitTestSuite
## How the World's happenings are felt, on the pure Picture: whose shots and hits shake the
## view, what is heard from the player's Plane and how loud, what each event leaves in the
## effects plan, and the order of a step. No scene.

const DT := 1.0 / 60.0


func _plane(side: int, at: Vector2) -> WorldPlane:
	var plane := WorldPlane.create(
		Airframe.new(), TestLoadouts.fighter(), side, ScriptedPilot.new(), FlightModel.new()
	)
	plane.state.position = at
	plane.state.on_airfield = false
	return plane


func _picture(player: WorldPlane) -> Picture:
	return Picture.new(3, player)


func _shot(plane: WorldPlane, direction := Vector2(1.0, 0.0)) -> WorldEvent:
	var event := WorldEvent.for_plane(WorldEvent.Kind.GUN_FIRED, plane)
	event.position = plane.state.position + direction * AirCombat.MUZZLE_OFFSET
	event.direction = direction
	return event


func _hit(plane: WorldPlane, direction := Vector2(1.0, 0.0)) -> WorldEvent:
	var event := WorldEvent.for_plane(WorldEvent.Kind.PLANE_HIT, plane)
	event.direction = direction
	return event


func _kinds(cues: Array[Picture.Cue]) -> Array[Picture.Cue.Kind]:
	var kinds: Array[Picture.Cue.Kind] = []
	for cue in cues:
		kinds.append(cue.kind)
	return kinds


func test_sounds_fade_with_distance_from_the_player_and_fall_silent_without_one() -> void:
	assert_float(Picture.volume_db_at(0.0)).is_equal(0.0)
	assert_float(Picture.volume_db_at(Picture.HEARING_RANGE / 2.0)).is_equal_approx(
		linear_to_db(0.5), 0.001
	)
	assert_float(Picture.volume_db_at(Picture.HEARING_RANGE)).is_equal(Picture.SILENT_DB)
	assert_float(Picture.volume_db_at(Picture.HEARING_RANGE * 2.0)).is_equal(Picture.SILENT_DB)
	var player := _plane(Side.BLUE, Vector2(300.0, 100.0))
	var picture := _picture(player)
	assert_bool(picture.hears()).is_true()
	assert_float(picture.volume_from(Vector2(300.0, 100.0))).is_equal(0.0)
	assert_float(picture.volume_from(Vector2(450.0, 100.0))).is_equal_approx(
		linear_to_db(0.5), 0.001
	)
	# Dead, the player still hears from where the Plane was lost.
	player.state.position = Vector2(320.0, 100.0)
	picture.step([], [player], [], DT)
	player.state.hit_points = 0
	player.state.destroyed = true
	player.state.position = Vector2(900.0, 100.0)  # a respawn elsewhere, not yet alive
	picture.step([], [player], [], DT)
	assert_bool(picture.hears()).is_true()
	assert_vector(picture.listener).is_equal(Vector2(320.0, 100.0))
	assert_float(picture.volume_from(Vector2(320.0, 100.0))).is_equal(0.0)
	assert_bool(_picture(null).hears()).is_false()
	assert_float(_picture(null).volume_from(Vector2.ZERO)).is_equal(Picture.SILENT_DB)


func test_only_the_players_own_shot_kicks_the_view() -> void:
	var player := _plane(Side.BLUE, Vector2(300.0, 100.0))
	var enemy := _plane(Side.RED, Vector2(450.0, 100.0))
	var picture := _picture(player)
	var cues := picture.react(_shot(enemy, Vector2(-1.0, 0.0)))
	assert_array(_kinds(cues)).contains_exactly([Picture.Cue.Kind.GUN])
	assert_object(cues[0].plane).is_same(enemy)
	assert_float(cues[0].volume_db).is_less(-5.0)  # 150 m off: about half as loud
	assert_float(cues[0].volume_db).is_greater(-7.0)
	assert_float(picture.shake.trauma).is_equal(0.0)
	assert_vector(picture.shake.offset()).is_equal_approx(Vector2.ZERO, Vector2.ONE * 0.001)
	assert_int(picture.plan.flashes.size()).is_equal(1)
	cues = picture.react(_shot(player, Vector2(1.0, 0.0)))
	assert_array(_kinds(cues)).contains_exactly([Picture.Cue.Kind.GUN])
	assert_object(cues[0].plane).is_same(player)
	assert_float(cues[0].volume_db).is_greater(-0.5)  # its own gun, at the muzzle
	assert_float(picture.shake.trauma).is_equal_approx(CameraShake.GUN_TRAUMA, 0.001)
	assert_vector(picture.shake.offset()).is_equal_approx(
		Vector2(-CameraShake.GUN_KICK, 0.0), Vector2.ONE * 0.001
	)
	assert_int(picture.plan.flashes.size()).is_equal(2)


func test_a_ground_guns_shot_flashes_and_sounds_as_its_kind_but_no_plane_fires() -> void:
	var picture := _picture(_plane(Side.BLUE, Vector2(300.0, 100.0)))
	var event := WorldEvent.at(WorldEvent.Kind.GUN_FIRED, Vector2(320.0, 60.0))
	event.direction = Vector2(0.0, 1.0)
	event.target = GroundTarget.create(
		"Nest", Side.RED, GroundTarget.Kind.ANTI_AIRCRAFT_GUN, Vector2(320.0, 58.0), 4.0, 2.0
	)
	var cues := picture.react(event)
	assert_array(_kinds(cues)).contains_exactly([Picture.Cue.Kind.GROUND_GUN])
	assert_object(cues[0].plane).is_null()
	assert_vector(cues[0].position).is_equal(Vector2(320.0, 60.0))
	assert_float(cues[0].volume_db).is_equal_approx(
		Picture.GROUND_GUN_VOLUME_DB + Picture.volume_db_at(Vector2(20.0, 40.0).length()), 0.001
	)
	assert_int(picture.plan.flashes.size()).is_equal(1)
	assert_int(picture.plan.casings.size()).is_equal(0)
	assert_float(picture.shake.trauma).is_equal(0.0)
	event.target = GroundTarget.create(
		"Flak", Side.RED, GroundTarget.Kind.FLAK_GUN, Vector2(320.0, 58.0), 4.0, 2.0
	)
	cues = picture.react(event)
	assert_array(_kinds(cues)).contains_exactly([Picture.Cue.Kind.FLAK_FIRE])
	assert_float(cues[0].volume_db).is_equal_approx(
		Picture.volume_db_at(Vector2(20.0, 40.0).length()), 0.001
	)


func test_every_shot_hit_and_impact_is_pitched_a_little_off_from_a_seeded_source() -> void:
	var player := _plane(Side.BLUE, Vector2(300.0, 100.0))
	var first := _picture(player)
	var second := _picture(player)
	var pitches := PackedFloat32Array()
	for i in 12:
		var cue := first.react(_shot(player))[0]
		assert_float(cue.pitch).is_between(1.0 - Picture.PITCH_JITTER, 1.0 + Picture.PITCH_JITTER)
		assert_float(second.react(_shot(player))[0].pitch).is_equal(cue.pitch)
		pitches.append(cue.pitch)
	assert_bool(pitches.count(pitches[0]) < pitches.size()).is_true()


func test_a_round_ending_sounds_by_its_surface_and_a_bomb_leaving_its_rack_is_heard() -> void:
	var player := _plane(Side.BLUE, Vector2(300.0, 100.0))
	var picture := _picture(player)
	var landed := WorldEvent.at(WorldEvent.Kind.BULLET_IMPACT, Vector2(330.0, 100.0))
	landed.surface = BulletHit.Surface.WATER
	var cues := picture.react(landed)
	assert_array(_kinds(cues)).contains_exactly([Picture.Cue.Kind.IMPACT])
	assert_int(cues[0].surface).is_equal(BulletHit.Surface.WATER)
	assert_float(cues[0].volume_db).is_equal_approx(
		Picture.IMPACT_VOLUME_DB + Picture.volume_db_at(30.0), 0.001
	)
	landed.surface = BulletHit.Surface.TARGET
	cues = picture.react(landed)
	assert_int(cues[0].surface).is_equal(BulletHit.Surface.TARGET)
	assert_float(cues[0].volume_db).is_equal_approx(
		Picture.TARGET_IMPACT_VOLUME_DB + Picture.volume_db_at(30.0), 0.001
	)
	var release := WorldEvent.for_plane(WorldEvent.Kind.BOMB_RELEASED, player)
	cues = picture.react(release)
	assert_array(_kinds(cues)).contains_exactly([Picture.Cue.Kind.RELEASE])
	assert_float(cues[0].volume_db).is_equal_approx(Picture.RELEASE_VOLUME_DB, 0.001)
	assert_object(cues[0].plane).is_same(player)


func test_a_hit_flashes_the_plane_and_shakes_the_view_only_for_the_player() -> void:
	var player := _plane(Side.BLUE, Vector2(300.0, 100.0))
	var enemy := _plane(Side.RED, Vector2(350.0, 100.0))
	var picture := _picture(player)
	var cues := picture.react(_hit(enemy))
	assert_array(_kinds(cues)).contains_exactly([Picture.Cue.Kind.HIT_FLASH, Picture.Cue.Kind.HIT])
	assert_object(cues[0].plane).is_same(enemy)
	assert_bool(cues[1].own).is_false()
	assert_float(cues[1].volume_db).is_equal_approx(
		Picture.HIT_VOLUME_DB + Picture.volume_db_at(50.0), 0.001
	)
	assert_float(picture.shake.trauma).is_equal(0.0)
	assert_int(picture.plan.sparks.size()).is_equal(EffectsPlan.SPARKS_PER_HIT)
	cues = picture.react(_hit(player, Vector2(0.0, -1.0)))
	assert_array(_kinds(cues)).contains_exactly([Picture.Cue.Kind.HIT_FLASH, Picture.Cue.Kind.HIT])
	assert_object(cues[0].plane).is_same(player)
	assert_bool(cues[1].own).is_true()
	assert_float(cues[1].volume_db).is_equal(0.0)
	assert_float(picture.shake.trauma).is_equal_approx(CameraShake.HIT_TRAUMA, 0.001)
	assert_vector(picture.shake.offset()).is_equal_approx(
		Vector2(0.0, -CameraShake.HIT_KICK), Vector2.ONE * 0.001
	)


func test_a_hit_in_a_spin_shakes_harder() -> void:
	var player := _plane(Side.BLUE, Vector2(300.0, 100.0))
	player.state.in_spin = true
	var picture := _picture(player)
	picture.react(_hit(player))
	assert_float(picture.shake.trauma).is_equal_approx(
		CameraShake.HIT_TRAUMA * CameraShake.SPIN_HIT_FACTOR, 0.001
	)


func test_a_blast_is_heard_by_how_far_and_felt_by_how_near() -> void:
	var player := _plane(Side.BLUE, Vector2(300.0, 100.0))
	var picture := _picture(player)
	var cues := picture.react(WorldEvent.at(WorldEvent.Kind.BOMB_DETONATED, Vector2(300.0, 80.0)))
	assert_array(_kinds(cues)).contains_exactly([Picture.Cue.Kind.BLAST])
	assert_float(cues[0].volume_db).is_equal_approx(Picture.volume_db_at(20.0), 0.001)
	assert_float(picture.shake.trauma).is_equal_approx(
		CameraShake.BLAST_TRAUMA * (1.0 - 20.0 / CameraShake.BLAST_RANGE), 0.001
	)
	assert_int(picture.plan.bursts.size()).is_equal(1)
	picture.shake.trauma = 0.0
	cues = picture.react(WorldEvent.at(WorldEvent.Kind.SHELL_BURST, Vector2(360.0, 100.0)))
	assert_array(_kinds(cues)).contains_exactly([Picture.Cue.Kind.SHELL])
	assert_float(cues[0].volume_db).is_equal_approx(
		Picture.SHELL_VOLUME_DB + Picture.volume_db_at(60.0), 0.001
	)
	assert_float(picture.shake.trauma).is_equal(0.0)  # at the edge of the shake's range
	assert_object(picture.plan.bursts[1].colour).is_equal(EffectsPlan.SHELL_BURST_COLOR)


func test_a_fallen_target_and_a_destroyed_plane_are_blasts_too() -> void:
	var player := _plane(Side.BLUE, Vector2(300.0, 100.0))
	var enemy := _plane(Side.RED, Vector2(400.0, 100.0))
	var picture := _picture(player)
	var depot := GroundTarget.create(
		"Depot", Side.RED, GroundTarget.Kind.BUILDING, Vector2(300.0, 10.0), 12.0, 6.0
	)
	var fell := WorldEvent.at(WorldEvent.Kind.TARGET_DESTROYED, depot.centre())
	fell.target = depot
	assert_array(_kinds(picture.react(fell))).contains_exactly([Picture.Cue.Kind.COLLAPSE])
	assert_float(picture.plan.bursts[0].radius).is_equal(12.0)
	var gone := WorldEvent.for_plane(WorldEvent.Kind.PLANE_DESTROYED, enemy)
	gone.crash = CrashRules.Outcome.WATER
	assert_array(_kinds(picture.react(gone))).contains_exactly([Picture.Cue.Kind.SPLASH])
	assert_int(picture.plan.bursts.size()).is_equal(1)  # a splash, not a Burst
	assert_int(picture.plan.puffs.back().kind).is_equal(EffectsPlan.PuffKind.SPLASH)
	gone.crash = CrashRules.Outcome.TERRAIN
	assert_array(_kinds(picture.react(gone))).contains_exactly([Picture.Cue.Kind.BLAST])
	assert_int(picture.plan.bursts.size()).is_equal(2)
	assert_float(picture.plan.bursts[1].radius).is_equal(EffectsPlan.PLANE_BURST_RADIUS)


func test_the_players_own_end_and_the_fight_over_the_wreck_are_heard_from_it() -> void:
	var player := _plane(Side.BLUE, Vector2(300.0, 100.0))
	var enemy := _plane(Side.RED, Vector2(310.0, 100.0))
	var picture := _picture(player)
	# The Plane is destroyed: the event comes with the state already dead.
	player.state.destroyed = true
	var gone := WorldEvent.for_plane(WorldEvent.Kind.PLANE_DESTROYED, player)
	var cues := picture.react(gone)
	assert_array(_kinds(cues)).contains_exactly([Picture.Cue.Kind.BLAST])
	assert_float(cues[0].volume_db).is_equal(0.0)
	assert_float(picture.shake.trauma).is_equal_approx(CameraShake.BLAST_TRAUMA, 0.001)
	picture.shake.trauma = 0.0
	cues = []
	cues.append_array(
		picture.react(WorldEvent.at(WorldEvent.Kind.BOMB_DETONATED, Vector2(300.0, 90.0)))
	)
	cues.append_array(picture.react(_shot(enemy)))
	cues.append_array(picture.react(_hit(enemy)))
	assert_array(_kinds(cues)).contains_exactly(
		[
			Picture.Cue.Kind.BLAST,
			Picture.Cue.Kind.GUN,
			Picture.Cue.Kind.HIT_FLASH,
			Picture.Cue.Kind.HIT
		]
	)
	assert_float(cues[0].volume_db).is_equal_approx(Picture.volume_db_at(10.0), 0.001)
	assert_float(picture.shake.trauma).is_greater(0.0)
	assert_int(picture.plan.bursts.size()).is_equal(2)
	assert_int(picture.plan.flashes.size()).is_equal(1)
	assert_int(picture.plan.sparks.size()).is_equal(EffectsPlan.SPARKS_PER_HIT)


func test_a_plane_back_on_an_airfield_touches_down_but_spawning_there_is_silent() -> void:
	var player := _plane(Side.BLUE, Vector2(300.0, 100.0))
	var picture := _picture(player)
	var planes: Array[WorldPlane] = [player]
	player.state.on_airfield = true
	assert_array(picture.step([], planes, [], DT)).is_empty()  # first sight: the baseline
	assert_array(picture.step([], planes, [], DT)).is_empty()
	player.state.on_airfield = false
	assert_array(picture.step([], planes, [], DT)).is_empty()
	player.state.on_airfield = true
	var cues := picture.step([], planes, [], DT)
	assert_array(_kinds(cues)).contains_exactly([Picture.Cue.Kind.TOUCHDOWN])
	assert_object(cues[0].plane).is_same(player)
	assert_float(cues[0].volume_db).is_equal_approx(Picture.TOUCHDOWN_VOLUME_DB, 0.001)
	assert_array(picture.step([], planes, [], DT)).is_empty()


func test_bombs_in_the_air_whistle_from_where_they_are_higher_the_faster_they_fall() -> void:
	var player := _plane(Side.BLUE, Vector2(300.0, 100.0))
	var picture := _picture(player)
	var slow := Bomb.new()
	slow.position = Vector2(300.0, 90.0)
	slow.velocity = Vector2(20.0, 0.0)
	var fast := Bomb.new()
	fast.position = Vector2(450.0, 40.0)
	fast.velocity = Vector2(20.0, -60.0)
	var bombs: Array[Bomb] = [slow, fast]
	picture.step([], [player], [], DT, bombs)
	assert_int(picture.whistles.size()).is_equal(2)
	assert_object(picture.whistles[0].bomb).is_same(slow)
	assert_vector(picture.whistles[0].position).is_equal(Vector2(300.0, 90.0))
	assert_float(picture.whistles[0].volume_db).is_equal_approx(
		Picture.WHISTLE_VOLUME_DB + Picture.volume_db_at(10.0), 0.001
	)
	assert_float(picture.whistles[1].pitch).is_greater(picture.whistles[0].pitch)
	assert_float(picture.whistles[0].pitch).is_equal_approx(
		Picture.WHISTLE_PITCH_AT_REST + Picture.WHISTLE_PITCH_PER_SPEED * 20.0, 0.001
	)
	picture.step([], [player], [], DT)
	assert_int(picture.whistles.size()).is_equal(0)
	assert_int(_picture(null).whistles.size()).is_equal(0)


func test_a_step_decays_the_shake_before_this_steps_happenings_land() -> void:
	var player := _plane(Side.BLUE, Vector2(300.0, 100.0))
	var picture := _picture(player)
	picture.shake.add(1.0)
	var none: Array[WorldEvent] = []
	var planes: Array[WorldPlane] = [player]
	var shells: Array[Shell] = []
	picture.step(none, planes, shells, CameraShake.DECAY_SECONDS / 2.0)
	assert_float(picture.shake.trauma).is_equal_approx(0.5, 0.001)
	picture.step(none, planes, shells, CameraShake.DECAY_SECONDS)
	assert_float(picture.shake.trauma).is_equal(0.0)
	var blast: Array[WorldEvent] = [
		WorldEvent.at(WorldEvent.Kind.BOMB_DETONATED, Vector2(300.0, 80.0))
	]
	var cues := picture.step(blast, planes, shells, DT)
	assert_int(cues.size()).is_equal(1)
	assert_float(picture.shake.trauma).is_equal_approx(
		CameraShake.BLAST_TRAUMA * (1.0 - 20.0 / CameraShake.BLAST_RANGE), 0.001
	)


func test_a_step_trails_smoke_from_a_hurt_plane_and_from_the_shells() -> void:
	var player := _plane(Side.BLUE, Vector2(300.0, 100.0))
	player.state.hit_points = 1
	var picture := _picture(player)
	var shell := Shell.new()
	shell.position = Vector2(200.0, 50.0)
	var none: Array[WorldEvent] = []
	var planes: Array[WorldPlane] = [player]
	var shells: Array[Shell] = [shell]
	for i in 30:
		picture.step(none, planes, shells, DT)
	var smoke := 0
	var trail := 0
	for puff in picture.plan.puffs:
		if puff.kind == EffectsPlan.PuffKind.DAMAGE:
			smoke += 1
		elif puff.kind == EffectsPlan.PuffKind.SHELL_TRAIL:
			trail += 1
	assert_int(smoke).is_greater(3)
	assert_int(trail).is_greater(0)
