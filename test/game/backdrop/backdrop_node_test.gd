extends GdUnitTestSuite
## Headless checks that the Backdrop renders its plan: one MultiMesh per piece variant per
## layer with an instance per placement, a ground sheet, colours faded by depth and no
## shadows, and that a mission scene fits it to its World Map. The layout itself is tested
## in backdrop_plan_test.gd.

const BACKDROP := preload("res://src/game/backdrop/backdrop.tscn")
const SCENE := "res://missions/strike_the_depot.tscn"


func _fitted() -> BackdropNode:
	var node: BackdropNode = auto_free(BACKDROP.instantiate())
	add_child(node)
	node.fit(WorldBounds.create(960.0, 160.0), 205.0, Vector2(80.8, 45.4))
	return node


func _instance_counts(node: BackdropNode, layer_name: String) -> int:
	var total := 0
	for instance in node.layer_instances(layer_name):
		total += instance.multimesh.instance_count
	return total


func test_every_placement_becomes_a_multimesh_instance() -> void:
	var node := _fitted()
	for layer in node.plan.layers:
		assert_int(_instance_counts(node, layer.name)).is_equal(layer.placements.size())
		for instance in node.layer_instances(layer.name):
			assert_int(instance.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


## The headless renderer does not keep MultiMesh transforms, so the rule is checked on its own.
func test_a_placement_is_put_at_its_depth_scaled_and_turned_as_planned() -> void:
	var placement := BackdropPlan.Placement.new()
	placement.position = Vector2(120.0, 2.0)
	placement.scale = Vector2(1.2, 0.9)
	placement.turned = false
	placement.depth = 250.0
	var transform := BackdropNode.placement_transform(placement)
	assert_vector(transform.origin).is_equal_approx(
		Vector3(120.0, 2.0, -250.0), Vector3.ONE * 0.001
	)
	assert_vector(transform.basis.get_scale()).is_equal_approx(
		Vector3(1.2, 0.9, 1.2), Vector3.ONE * 0.001
	)
	assert_float(transform.basis.z.normalized().z).is_equal_approx(1.0, 0.001)
	placement.turned = true
	transform = BackdropNode.placement_transform(placement)
	assert_float(transform.basis.z.normalized().z).is_equal_approx(-1.0, 0.001)
	assert_vector(transform.basis.get_scale()).is_equal_approx(
		Vector3(1.2, 0.9, 1.2), Vector3.ONE * 0.001
	)


func test_far_layers_wear_hazed_copies_of_the_models_colours() -> void:
	var node := _fitted()
	var raw: Node3D = auto_free(BackdropNode.MODELS["mountain"].instantiate())
	var source: MeshInstance3D = raw.find_child("MountainA", true, false)
	var instance: MultiMeshInstance3D = node.get_node("MountainsMountainA")
	var shown: StandardMaterial3D = instance.multimesh.mesh.surface_get_material(0)
	var original: StandardMaterial3D = source.mesh.surface_get_material(0)
	assert_object(shown).is_not_same(original)
	var expected := BackdropNode.hazed(original.albedo_color, 700.0)
	assert_bool(shown.albedo_color.is_equal_approx(expected)).is_true()
	assert_bool(shown.albedo_color.is_equal_approx(original.albedo_color)).is_false()


func test_the_ground_sheet_spans_the_plan_and_casts_no_shadow() -> void:
	var node := _fitted()
	var ground: MeshInstance3D = node.get_node("Ground")
	var aabb := ground.mesh.get_aabb()
	assert_float(aabb.position.x).is_equal_approx(node.plan.ground_span.x, 0.001)
	assert_float(aabb.end.x).is_equal_approx(node.plan.ground_span.y, 0.001)
	assert_float(aabb.position.z).is_equal_approx(-BackdropPlan.GROUND_DEPTH, 0.001)
	assert_float(aabb.end.z).is_equal_approx(0.0, 0.001)
	assert_int(ground.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	# Godot's front faces are wound clockwise, so seen from above the geometric normal of
	# every triangle points down; wound the other way the sheet is culled and the sky shows.
	var vertices: PackedVector3Array = ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0, vertices.size(), 3):
		var geometric := (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i])
		assert_float(geometric.y).is_less(0.0)


func test_refitting_replaces_what_was_there() -> void:
	var node := _fitted()
	var before := node.get_child_count()
	node.seed_value = 5
	node.fit(WorldBounds.create(960.0, 160.0), 205.0, Vector2(80.8, 45.4))
	await get_tree().process_frame
	assert_int(node.get_child_count()).is_equal(before)


func test_a_mission_scene_fits_its_backdrop_to_the_world_map() -> void:
	var runner := scene_runner(SCENE)
	var world: WorldNode = runner.scene()
	var backdrop: BackdropNode = world.get_node("Backdrop")
	assert_object(backdrop.plan).is_not_null()
	var near := backdrop.plan.layers[1]
	assert_float(near.required.position.x).is_less(0.0)
	assert_float(near.required.end.x).is_greater(world.world.map.bounds.width)
	assert_int(_instance_counts(backdrop, "Near")).is_equal(near.placements.size())
	# The slab's trees stand on the mission's terrain, not on the ground sheet.
	var slab := backdrop.plan.layers[0]
	var terrain := world.world.map.terrain
	var on_a_hill := 0
	for placement in slab.placements:
		assert_float(placement.position.y).is_equal_approx(
			terrain.height_at(placement.position.x) - BackdropPlan.SINK, 0.001
		)
		if placement.position.y > 20.0:
			on_a_hill += 1
	assert_int(on_a_hill).is_greater(0)


func test_a_frame_drifts_the_clouds_through_the_plan() -> void:
	var node := _fitted()
	var cloud := node.plan.layers[3].placements[0]
	var before := cloud.position.x
	node._process(2.0)
	assert_float(cloud.position.x).is_equal_approx(before + cloud.drift * 2.0, 0.001)
	assert_int(node._drifting.size()).is_equal(node.plan.layers[3].placements.size())


func test_smoke_and_flashes_have_their_slots_and_fill_as_the_plan_plays() -> void:
	var node := _fitted()
	var smoke: MultiMeshInstance3D = node.get_node("Smoke")
	var flashes: MultiMeshInstance3D = node.get_node("Flashes")
	assert_int(smoke.multimesh.instance_count).is_equal(BackdropPlan.MAX_PUFFS)
	assert_int(flashes.multimesh.instance_count).is_equal(BackdropPlan.MAX_FLASHES)
	assert_bool(smoke.multimesh.use_colors).is_true()
	assert_int(smoke.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var material: StandardMaterial3D = smoke.multimesh.mesh.surface_get_material(0)
	assert_int(material.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
	var glow: StandardMaterial3D = flashes.multimesh.mesh.surface_get_material(0)
	assert_bool(glow.emission_enabled).is_true()
	for i in 30:
		node._process(0.1)
	assert_int(node.plan.puffs.size()).is_greater(0)


func test_the_front_line_toggle_reaches_the_plan() -> void:
	var node: BackdropNode = auto_free(BACKDROP.instantiate())
	node.front_line = false
	add_child(node)
	node.fit(WorldBounds.create(960.0, 160.0), 205.0, Vector2(80.8, 45.4))
	assert_bool(node.plan.front_line).is_false()
	var runner := scene_runner(SCENE)  # Strike the Depot is behind the lines
	var world: WorldNode = runner.scene()
	assert_bool(world.get_node("Backdrop").plan.front_line).is_false()


func test_the_windmills_and_factory_are_placed_hazed_and_the_sails_turn() -> void:
	var node := _fitted()
	assert_int(node.features_of("windmill")).is_equal(2)
	assert_int(node.features_of("factory")).is_equal(1)
	var mill: Node3D = node.get_node("Windmill1")
	var feature := node.plan.features[0]
	assert_vector(mill.position).is_equal_approx(
		Vector3(feature.position.x, feature.position.y, -feature.depth), Vector3.ONE * 0.001
	)
	var raw: Node3D = auto_free(BackdropNode.MODELS["windmill"].instantiate())
	var tower: MeshInstance3D = mill.find_child("Tower", true, false)
	var original: MeshInstance3D = raw.find_child("Tower", true, false)
	var shown: StandardMaterial3D = tower.mesh.surface_get_material(0)
	(
		assert_bool(
			shown.albedo_color.is_equal_approx(
				BackdropNode.hazed(
					original.mesh.surface_get_material(0).albedo_color, feature.depth
				)
			)
		)
		. is_true()
	)
	assert_int(tower.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var sails: Node3D = mill.find_child("Sails", true, false)
	var before := sails.rotation.z
	node._process(1.0)
	assert_float(angle_difference(before, sails.rotation.z)).is_equal_approx(
		BackdropPlan.SAIL_RATE, 0.001
	)


func test_the_trees_wear_the_sway_shader_and_are_told_the_time() -> void:
	var node := _fitted()
	for layer_name in ["Slab", "Near"]:
		for instance in node.layer_instances(layer_name):
			var mesh := instance.multimesh.mesh
			for surface in mesh.get_surface_count():
				var material := mesh.surface_get_material(surface) as ShaderMaterial
				assert_object(material).is_not_null()
				assert_object(material.shader).is_same(BackdropNode.SWAY_SHADER)
	for instance in node.layer_instances("Hills"):
		assert_bool(instance.multimesh.mesh.surface_get_material(0) is StandardMaterial3D).is_true()
	assert_int(node._sway_materials.size()).is_greater(0)
	node._process(0.5)
	node._process(0.25)
	assert_float(node.sway_time).is_equal_approx(0.75, 0.001)
