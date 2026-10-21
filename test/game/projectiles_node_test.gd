extends GdUnitTestSuite
## The Tracer rule, and that the node draws one per bullet. The headless renderer keeps no
## MultiMesh transforms or colours, so those are checked on the static rules and the node is
## checked for counts and the shader.


func _bullet(position: Vector2, velocity: Vector2, age: float, owner_id := 1) -> Bullet:
	var bullet := Bullet.new()
	bullet.position = position
	bullet.velocity = velocity
	bullet.age = age
	bullet.owner_id = owner_id
	return bullet


func test_the_tail_is_as_long_as_the_round_has_flown_up_to_the_tail_time() -> void:
	var head := ProjectilesNode.TRACER_HEAD
	(
		assert_float(ProjectilesNode.tracer_length(_bullet(Vector2.ZERO, Vector2(60.0, 0.0), 0.0)))
		. is_equal(head)
	)
	(
		assert_float(ProjectilesNode.tracer_length(_bullet(Vector2.ZERO, Vector2(60.0, 0.0), 0.1)))
		. is_equal_approx(head + 6.0, 0.001)
	)
	(
		assert_float(ProjectilesNode.tracer_length(_bullet(Vector2.ZERO, Vector2(60.0, 0.0), 1.0)))
		. is_equal_approx(head + 60.0 * ProjectilesNode.TRACER_TAIL_SECONDS, 0.001)
	)


func test_the_streak_leads_with_the_round_and_trails_along_its_flight() -> void:
	var bullet := _bullet(Vector2(100.0, 50.0), Vector2(0.0, -40.0), 0.1)  # straight down
	var transform := ProjectilesNode.tracer_transform(bullet)
	var length := ProjectilesNode.tracer_length(bullet)
	var head := transform * Vector3(0.5, 0.0, 0.0)
	var tail := transform * Vector3(-0.5, 0.0, 0.0)
	assert_vector(head).is_equal_approx(Vector3(100.0, 50.0, 0.0), Vector3.ONE * 0.001)
	assert_vector(tail).is_equal_approx(Vector3(100.0, 50.0 + length, 0.0), Vector3.ONE * 0.001)
	# The width is not stretched.
	var side := transform * Vector3(0.5, 0.5, 0.0)
	assert_float(side.distance_to(head)).is_equal_approx(0.5, 0.001)


func test_ground_guns_rounds_are_tinted_apart_from_planes() -> void:
	(
		assert_object(ProjectilesNode.tracer_colour(_bullet(Vector2.ZERO, Vector2.RIGHT, 0.0, 1)))
		. is_equal(ProjectilesNode.TRACER_COLOR)
	)
	(
		assert_object(ProjectilesNode.tracer_colour(_bullet(Vector2.ZERO, Vector2.RIGHT, 0.0, -1)))
		. is_equal(ProjectilesNode.GROUND_TRACER_COLOR)
	)


func test_the_node_draws_one_coloured_tracer_per_bullet_with_the_shader() -> void:
	var node: ProjectilesNode = auto_free(ProjectilesNode.new())
	add_child(node)
	var tracers: MultiMeshInstance3D = node.get_node("Tracers")
	assert_int(tracers.multimesh.instance_count).is_equal(ProjectilesNode.CAPACITY)
	assert_bool(tracers.multimesh.use_colors).is_true()
	var material: ShaderMaterial = tracers.multimesh.mesh.surface_get_material(0)
	assert_object(material.shader).is_same(ProjectilesNode.TRACER_SHADER)
	var bullets: Array[Bullet] = [
		_bullet(Vector2(10.0, 50.0), Vector2(60.0, 0.0), 0.2, 1),
		_bullet(Vector2(20.0, 50.0), Vector2(0.0, 45.0), 0.0, -1),
	]
	node.show_in_flight(bullets, [], [], [])
	assert_int(tracers.multimesh.visible_instance_count).is_equal(2)
	node.show_in_flight([], [], [], [])
	assert_int(tracers.multimesh.visible_instance_count).is_equal(0)


func test_bombs_in_flight_wear_the_bomb_model() -> void:
	var node: ProjectilesNode = auto_free(ProjectilesNode.new())
	add_child(node)
	var bombs: MultiMeshInstance3D = node.get_node("Bombs")
	assert_bool(bombs.multimesh.mesh is BoxMesh).is_false()
	assert_int(bombs.multimesh.mesh.get_surface_count()).is_equal(3)  # olive, band, dark
	var bomb := Bomb.new()
	bomb.position = Vector2(100.0, 50.0)
	bomb.velocity = Vector2(30.0, -10.0)
	node.show_in_flight([], [bomb], [], [])
	assert_int(bombs.multimesh.visible_instance_count).is_equal(1)
