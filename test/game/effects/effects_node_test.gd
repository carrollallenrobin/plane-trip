extends GdUnitTestSuite
## The node draws its plan: one pooled MultiMesh per kind, as many shown as the plan holds.
## The plan is filled through the Picture, as in play. The headless renderer keeps no
## transforms, so the transform rules are checked directly.

var _picture: Picture


func _node() -> EffectsNode:
	_picture = Picture.new(3)
	var node := EffectsNode.create(_picture.plan)
	add_child(auto_free(node))
	return node


func _flash(muzzle: Vector2, direction: Vector2) -> EffectsPlan.MuzzleFlash:
	var flash := EffectsPlan.MuzzleFlash.new()
	flash.position = muzzle
	flash.direction = direction
	return flash


func test_the_pools_are_built_to_their_caps_with_colours() -> void:
	var node := _node()
	var flashes: MultiMeshInstance3D = node.get_node("MuzzleFlashes")
	var casings: MultiMeshInstance3D = node.get_node("Casings")
	assert_int(flashes.multimesh.instance_count).is_equal(EffectsPlan.MAX_FLASHES)
	assert_int(casings.multimesh.instance_count).is_equal(EffectsPlan.MAX_CASINGS)
	assert_bool(flashes.multimesh.use_colors).is_true()
	assert_bool(casings.multimesh.use_colors).is_true()
	var glow: StandardMaterial3D = flashes.multimesh.mesh.surface_get_material(0)
	assert_bool(glow.emission_enabled).is_true()
	assert_int(flashes.multimesh.visible_instance_count).is_equal(0)


func test_warming_up_draws_a_speck_of_every_pool_for_a_few_frames_then_nothing() -> void:
	var node := _node()
	var camera := Camera3D.new()
	camera.position = Vector3(120.0, 40.0, 205.0)
	add_child(auto_free(camera))
	node.warm_up(camera)
	var pools := ["MuzzleFlashes", "Casings", "Puffs", "Sparks", "BurstSpheres", "BurstFlashes"]
	for frame in ShaderWarmup.FRAMES:
		node.advance(1.0 / 60.0)
		for pool_name in pools:
			var pool: MultiMeshInstance3D = node.get_node(pool_name)
			assert_int(pool.multimesh.visible_instance_count).is_equal(1)
	node.advance(1.0 / 60.0)
	for pool_name in pools:
		var pool: MultiMeshInstance3D = node.get_node(pool_name)
		assert_int(pool.multimesh.visible_instance_count).is_equal(0)
	var speck := ShaderWarmup.speck(camera)
	assert_vector(speck.origin).is_equal(Vector3(120.0, 40.0, 205.0 - ShaderWarmup.AHEAD))
	assert_float(speck.basis.get_scale().x).is_equal_approx(ShaderWarmup.SCALE, 0.000001)


func test_a_gun_fired_event_shows_a_flash_and_casings_until_they_are_spent() -> void:
	var node := _node()
	var plane := WorldPlane.create(
		Airframe.new(), TestLoadouts.fighter(), Side.BLUE, ScriptedPilot.new(), FlightModel.new()
	)
	plane.state.position = Vector2(100.0, 50.0)
	var event := WorldEvent.for_plane(WorldEvent.Kind.GUN_FIRED, plane)
	event.position = Vector2(104.8, 50.0)
	event.direction = Vector2.RIGHT
	_picture.react(event)
	node.advance(0.0)
	var flashes: MultiMeshInstance3D = node.get_node("MuzzleFlashes")
	var casings: MultiMeshInstance3D = node.get_node("Casings")
	assert_int(flashes.multimesh.visible_instance_count).is_equal(1)
	assert_int(casings.multimesh.visible_instance_count).is_equal(EffectsPlan.CASINGS_PER_SHOT)
	node.advance(EffectsPlan.FLASH_LIFE)
	assert_int(flashes.multimesh.visible_instance_count).is_equal(0)
	assert_int(casings.multimesh.visible_instance_count).is_equal(EffectsPlan.CASINGS_PER_SHOT)
	node.advance(EffectsPlan.CASING_LIFE)
	assert_int(casings.multimesh.visible_instance_count).is_equal(0)
	# Other events are not its business.
	_picture.react(WorldEvent.at(WorldEvent.Kind.SHELL_BURST, Vector2.ZERO))
	node.advance(0.0)
	assert_int(flashes.multimesh.visible_instance_count).is_equal(0)


func test_impacts_and_hits_show_puffs_and_sparks() -> void:
	var node := _node()
	var puffs: MultiMeshInstance3D = node.get_node("Puffs")
	var sparks: MultiMeshInstance3D = node.get_node("Sparks")
	assert_int(puffs.multimesh.instance_count).is_equal(EffectsPlan.MAX_PUFFS)
	assert_int(sparks.multimesh.instance_count).is_equal(EffectsPlan.MAX_SPARKS)
	var landed := WorldEvent.at(WorldEvent.Kind.BULLET_IMPACT, Vector2(100.0, 10.0))
	landed.surface = BulletHit.Surface.WATER
	_picture.react(landed)
	var plane := WorldPlane.create(
		Airframe.new(), TestLoadouts.fighter(), Side.RED, ScriptedPilot.new(), FlightModel.new()
	)
	var struck := WorldEvent.for_plane(WorldEvent.Kind.PLANE_HIT, plane)
	struck.position = Vector2(200.0, 60.0)
	struck.direction = Vector2.RIGHT
	_picture.react(struck)
	node.advance(0.0)
	assert_int(puffs.multimesh.visible_instance_count).is_equal(1)
	assert_int(node.plan.puffs[0].kind).is_equal(EffectsPlan.PuffKind.SPLASH)
	assert_int(sparks.multimesh.visible_instance_count).is_equal(EffectsPlan.SPARKS_PER_HIT)
	# The splash is a tall blob; its transform stretches the unit puff upward.
	var transform := EffectsNode.puff_transform(node.plan.puffs[0])
	var top := transform * Vector3(0.0, 1.0, 0.0)
	var side := transform * Vector3(1.0, 0.0, 0.0)
	assert_float(top.y - 10.0).is_greater(side.x - 100.0)
	node.advance(1.0)
	assert_int(puffs.multimesh.visible_instance_count).is_equal(0)
	assert_int(sparks.multimesh.visible_instance_count).is_equal(0)


func test_the_cone_opens_from_the_muzzle_along_the_barrel() -> void:
	var flash := _flash(Vector2(100.0, 50.0), Vector2(0.0, 1.0))  # a gun firing straight up
	var transform := EffectsNode.flash_transform(flash)
	# The mesh's apex is at local +Y, half a length up; it must land on the muzzle.
	var apex := transform * Vector3(0.0, EffectsNode.FLASH_LENGTH / 2.0, 0.0)
	var base := transform * Vector3(0.0, -EffectsNode.FLASH_LENGTH / 2.0, 0.0)
	assert_vector(apex).is_equal_approx(Vector3(100.0, 50.0, 0.0), Vector3.ONE * 0.001)
	assert_float(base.y).is_greater(apex.y)
	assert_float(base.x).is_equal_approx(100.0, 0.001)
	# It is small to begin with and full size at the end.
	assert_float(base.y - apex.y).is_equal_approx(
		EffectsNode.FLASH_LENGTH * EffectsNode.FLASH_POP_FROM, 0.001
	)
	flash.age = EffectsPlan.FLASH_LIFE
	transform = EffectsNode.flash_transform(flash)
	base = transform * Vector3(0.0, -EffectsNode.FLASH_LENGTH / 2.0, 0.0)
	assert_float(base.y - 50.0).is_equal_approx(EffectsNode.FLASH_LENGTH, 0.001)


func test_the_flash_stays_solid_until_its_last_stretch() -> void:
	var flash := _flash(Vector2.ZERO, Vector2.RIGHT)
	assert_float(EffectsNode.flash_alpha(flash)).is_equal(1.0)
	flash.age = EffectsPlan.FLASH_LIFE * (1.0 - EffectsNode.FLASH_FADE_FROM)
	assert_float(EffectsNode.flash_alpha(flash)).is_equal_approx(1.0, 0.001)
	flash.age = EffectsPlan.FLASH_LIFE * (1.0 - EffectsNode.FLASH_FADE_FROM / 2.0)
	assert_float(EffectsNode.flash_alpha(flash)).is_equal_approx(0.5, 0.001)
	flash.age = EffectsPlan.FLASH_LIFE
	assert_float(EffectsNode.flash_alpha(flash)).is_equal(0.0)


func test_bursts_show_as_a_flash_sphere_and_a_coloured_sphere() -> void:
	var node := _node()
	var flashes: MultiMeshInstance3D = node.get_node("BurstFlashes")
	var spheres: MultiMeshInstance3D = node.get_node("BurstSpheres")
	assert_int(spheres.multimesh.instance_count).is_equal(EffectsPlan.MAX_BURSTS)
	var glow: StandardMaterial3D = spheres.multimesh.mesh.surface_get_material(0)
	assert_bool(glow.emission_enabled).is_true()
	_picture.react(WorldEvent.at(WorldEvent.Kind.BOMB_DETONATED, Vector2(100.0, 10.0)))
	_picture.react(WorldEvent.at(WorldEvent.Kind.SHELL_BURST, Vector2(200.0, 80.0)))
	var depot := GroundTarget.create(
		"Depot", Side.RED, GroundTarget.Kind.BUILDING, Vector2(300.0, 10.0), 12.0, 6.0
	)
	var fell := WorldEvent.at(WorldEvent.Kind.TARGET_DESTROYED, depot.centre())
	fell.target = depot
	_picture.react(fell)
	var plane := WorldPlane.create(
		Airframe.new(), TestLoadouts.fighter(), Side.RED, ScriptedPilot.new(), FlightModel.new()
	)
	var gone := WorldEvent.for_plane(WorldEvent.Kind.PLANE_DESTROYED, plane)
	gone.crash = CrashRules.Outcome.BORDER
	_picture.react(gone)
	node.advance(0.0)
	assert_int(spheres.multimesh.visible_instance_count).is_equal(4)  # the Border too
	assert_int(flashes.multimesh.visible_instance_count).is_equal(4)
	assert_float(node.plan.bursts[2].radius).is_equal(12.0)
	assert_float(node.plan.bursts[3].radius).is_equal(EffectsPlan.PLANE_BURST_RADIUS)
	gone.crash = CrashRules.Outcome.WATER
	_picture.react(gone)
	assert_int(node.plan.bursts.size()).is_equal(4)
	assert_int(node.plan.puffs.back().kind).is_equal(EffectsPlan.PuffKind.SPLASH)
	gone.crash = CrashRules.Outcome.TERRAIN
	_picture.react(gone)
	assert_int(node.plan.bursts.size()).is_equal(5)
