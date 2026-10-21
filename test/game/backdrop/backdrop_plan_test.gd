extends GdUnitTestSuite
## The Backdrop's layout covers whatever the camera can see at every layer's depth, for any
## World size and camera, and the same seed lays the same Backdrop out. Pure: no scene.

const DISTANCE := 205.0
## What a 25 degree camera 205 m out shows of the action plane at 16:9.
const VIEW_HALF := Vector2(80.8, 45.4)


func _plan(width := 960.0, ceiling := 160.0, seed_value := 1) -> BackdropPlan:
	return BackdropPlan.create(WorldBounds.create(width, ceiling), DISTANCE, VIEW_HALF, seed_value)


func _layer(plan: BackdropPlan, layer_name: String) -> BackdropPlan.Layer:
	for layer in plan.layers:
		if layer.name == layer_name:
			return layer
	return null


func _sorted_rects(layer: BackdropPlan.Layer) -> Array[Rect2]:
	var piece: Dictionary = BackdropPlan.PIECES[layer.piece]
	var rects: Array[Rect2] = []
	for placement in layer.placements:
		rects.append(placement.rect(piece))
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	return rects


func test_a_layer_needs_more_than_the_world_the_deeper_it_sits() -> void:
	var bounds := WorldBounds.create(960.0, 160.0)
	var at_action := BackdropPlan.required_rect(bounds, DISTANCE, VIEW_HALF, 0.0)
	assert_vector(at_action.position).is_equal(Vector2.ZERO)
	assert_vector(at_action.end).is_equal(Vector2(960.0, 160.0))
	# At the camera's own distance behind the action the view is twice as wide and tall, so
	# the layer grows by the wider of a 16:9 and a 21:9 view on each side.
	var one_distance := BackdropPlan.required_rect(bounds, DISTANCE, VIEW_HALF, DISTANCE)
	var half_x := VIEW_HALF.y * BackdropPlan.WIDEST_ASPECT
	assert_float(one_distance.position.x).is_equal_approx(-half_x, 0.01)
	assert_float(one_distance.end.x).is_equal_approx(960.0 + half_x, 0.01)
	assert_float(one_distance.position.y).is_equal_approx(-VIEW_HALF.y, 0.01)
	assert_float(one_distance.end.y).is_equal_approx(160.0 + VIEW_HALF.y, 0.01)


func test_the_six_layers_sit_in_depth_order_and_fade_with_it() -> void:
	var plan := _plan()
	var names: Array[String] = []
	var last_depth := 0.0
	var last_haze := 0.0
	for layer in plan.layers:
		names.append(layer.name)
		assert_float(layer.depth).is_greater(last_depth)
		assert_float(layer.haze()).is_greater(last_haze)
		assert_float(layer.haze()).is_less(1.0)
		last_depth = layer.depth
		last_haze = layer.haze()
	assert_array(names).contains_exactly(["Slab", "Near", "Hills", "Clouds", "Mountains", "Far"])


func test_every_layer_spans_what_the_camera_can_see_at_its_depth() -> void:
	for size in [Vector2(960.0, 160.0), Vector2(400.0, 100.0), Vector2(2400.0, 300.0)]:
		var plan := _plan(size.x, size.y)
		for layer in plan.layers:
			assert_float(layer.extent.position.x).is_less_equal(layer.required.position.x)
			assert_float(layer.extent.end.x).is_greater_equal(layer.required.end.x)
			assert_bool(layer.placements.is_empty()).is_false()


func test_ridges_stand_on_the_ground_and_leave_no_gap_in_the_skyline() -> void:
	var plan := _plan()
	for layer_name in ["Hills", "Mountains", "Far"]:
		var rects := _sorted_rects(_layer(plan, layer_name))
		for i in rects.size():
			assert_float(rects[i].position.y).is_equal_approx(
				BackdropPlan.GROUND_Y - BackdropPlan.SINK, 0.001
			)
			if i > 0:
				assert_float(rects[i].position.x).is_less(rects[i - 1].end.x)


func test_slab_trees_follow_the_terrain_behind_the_action_and_keep_off_the_water() -> void:
	var terrain := Terrain.from_points(
		PackedVector2Array([Vector2(0.0, 10.0), Vector2(300.0, 60.0), Vector2(960.0, 10.0)])
	)
	terrain.add_water(400.0, 500.0)
	var plan := BackdropPlan.create(
		WorldBounds.create(960.0, 160.0), DISTANCE, VIEW_HALF, 3, terrain
	)
	var slab := _layer(plan, "Slab")
	assert_int(slab.placements.size()).is_greater(40)
	var sorted := slab.placements.duplicate()
	sorted.sort_custom(
		func(a: BackdropPlan.Placement, b: BackdropPlan.Placement) -> bool:
			return a.position.x < b.position.x
	)
	for i in sorted.size():
		var p: BackdropPlan.Placement = sorted[i]
		assert_float(p.position.x).is_between(0.0, 960.0)
		assert_float(p.position.y).is_equal_approx(
			terrain.height_at(p.position.x) - BackdropPlan.SINK, 0.001
		)
		assert_float(p.depth).is_between(BackdropPlan.SLAB_DEPTH_MIN, BackdropPlan.SLAB_DEPTH_MAX)
		(
			assert_bool(
				(
					p.position.x > 400.0 - BackdropPlan.SLAB_WATER_MARGIN
					and p.position.x < 500.0 + BackdropPlan.SLAB_WATER_MARGIN
				)
			)
			. is_false()
		)
		if i > 0:  # at most the Water, its margins and one spacing apart
			assert_float(p.position.x - sorted[i - 1].position.x).is_less_equal(140.0)


func test_without_terrain_the_slab_trees_stand_on_the_ground_sheet() -> void:
	var slab := _layer(_plan(), "Slab")
	for placement in slab.placements:
		assert_float(placement.position.y).is_equal_approx(
			BackdropPlan.GROUND_Y - BackdropPlan.SINK, 0.001
		)
	for layer in _plan().layers:
		for placement in layer.placements:
			if layer.name != "Slab":
				assert_float(placement.depth).is_equal_approx(layer.depth, 0.001)


func test_the_tree_line_is_dense_and_the_mountains_top_the_ceiling() -> void:
	var plan := _plan()
	var trees := _sorted_rects(_layer(plan, "Near"))
	for i in range(1, trees.size()):
		assert_float(trees[i].position.x - trees[i - 1].position.x).is_less_equal(6.0)
	var mountains := _layer(plan, "Mountains")
	assert_float(mountains.extent.end.y).is_greater_equal(mountains.required.end.y)


func test_clouds_fill_the_sky_up_to_what_the_camera_sees_at_the_ceiling() -> void:
	var clouds := _layer(_plan(), "Clouds")
	assert_float(clouds.extent.position.y).is_greater(0.0)
	assert_float(clouds.extent.end.y).is_greater_equal(clouds.required.end.y)
	var top_half := 0
	for rect in _sorted_rects(clouds):
		if rect.get_center().y > clouds.required.end.y / 2.0:
			top_half += 1
	assert_int(top_half).is_greater(clouds.placements.size() / 4)


func test_the_ground_sheet_reaches_past_the_deepest_layer_at_its_far_edge() -> void:
	var plan := _plan()
	var far := BackdropPlan.required_rect(
		WorldBounds.create(960.0, 160.0), DISTANCE, VIEW_HALF, BackdropPlan.GROUND_DEPTH
	)
	assert_float(plan.ground_span.x).is_equal_approx(far.position.x, 0.001)
	assert_float(plan.ground_span.y).is_equal_approx(far.end.x, 0.001)
	assert_float(plan.ground_span.x).is_less(_layer(plan, "Mountains").extent.position.x)


func test_the_same_seed_lays_the_same_backdrop_and_another_seed_differs() -> void:
	var a := _layer(_plan(960.0, 160.0, 7), "Hills")
	var b := _layer(_plan(960.0, 160.0, 7), "Hills")
	var c := _layer(_plan(960.0, 160.0, 8), "Hills")
	assert_int(a.placements.size()).is_equal(b.placements.size())
	for i in a.placements.size():
		assert_vector(a.placements[i].position).is_equal(b.placements[i].position)
		assert_int(a.placements[i].variant).is_equal(b.placements[i].variant)
	var same := a.placements.size() == c.placements.size()
	if same:
		for i in a.placements.size():
			same = same and a.placements[i].position == c.placements[i].position
	assert_bool(same).is_false()


func test_a_placement_rect_follows_the_pieces_origin() -> void:
	var tree := BackdropPlan.Placement.new()
	tree.variant = 0
	tree.position = Vector2(10.0, 2.0)
	tree.scale = Vector2(2.0, 2.0)
	var rect := tree.rect(BackdropPlan.PIECES["tree"])  # TreeA is 5.2 by 8.5, standing
	assert_vector(rect.position).is_equal_approx(Vector2(10.0 - 5.2, 2.0), Vector2.ONE * 0.001)
	assert_vector(rect.size).is_equal_approx(Vector2(10.4, 17.0), Vector2.ONE * 0.001)
	var cloud := BackdropPlan.Placement.new()
	cloud.variant = 1
	cloud.position = Vector2(0.0, 100.0)
	cloud.scale = Vector2.ONE
	rect = cloud.rect(BackdropPlan.PIECES["cloud"])  # CloudB is 44 by 22, centred
	assert_vector(rect.position).is_equal_approx(Vector2(-22.0, 89.0), Vector2.ONE * 0.001)


func test_only_the_clouds_drift_each_at_its_own_pace() -> void:
	var plan := _plan()
	for layer in plan.layers:
		for placement in layer.placements:
			if layer.name == "Clouds":
				assert_float(placement.drift).is_between(1.5, 4.0)
			else:
				assert_float(placement.drift).is_equal(0.0)


func test_advancing_moves_the_clouds_and_leaves_the_rest_standing() -> void:
	var plan := _plan()
	var before := {}
	for layer in plan.layers:
		for placement in layer.placements:
			before[placement] = placement.position
	var moved := plan.advance(10.0)
	assert_int(moved.size()).is_equal(_layer(plan, "Clouds").placements.size())
	for layer in plan.layers:
		for placement in layer.placements:
			var expected: Vector2 = before[placement]
			if layer.name == "Clouds" and moved.has(placement):
				expected.x += placement.drift * 10.0
			if placement.position.x < before[placement].x:
				continue  # wrapped; covered below
			assert_vector(placement.position).is_equal_approx(expected, Vector2.ONE * 0.001)


func test_a_cloud_past_the_far_end_comes_back_in_at_the_near_end() -> void:
	var plan := _plan()
	var clouds := _layer(plan, "Clouds")
	var cloud := clouds.placements[0]
	var half := cloud.rect(BackdropPlan.PIECES["cloud"]).size.x / 2.0
	cloud.position.x = clouds.required.end.x + half + 0.1
	plan.advance(1.0)
	assert_float(cloud.position.x).is_less(clouds.required.position.x)
	assert_float(cloud.position.x + half).is_greater(clouds.required.position.x)
	# Standing still at the far end, nothing wraps.
	var still := _layer(plan, "Hills").placements[0]
	still.position.x = 1.0e6
	plan.advance(1.0)
	assert_float(still.position.x).is_equal(1.0e6)


func _advance(plan: BackdropPlan, seconds: float) -> void:
	for i in int(round(seconds * 10.0)):
		plan.advance(0.1)


func test_smoke_columns_stand_on_the_hills_spread_along_the_world() -> void:
	var plan := _plan()
	var hills := _layer(plan, "Hills")
	assert_int(plan.columns.size()).is_equal(4)
	var last_x := -INF
	var thickness: float = BackdropPlan.PIECES["hill"]["thickness"]
	for i in range(1, plan.columns.size()):  # the first is the factory's chimney
		var column := plan.columns[i]
		assert_float(column.position.x).is_greater(last_x)
		last_x = column.position.x
		# In front of the hill's front face, which is its thickness times its scale forward.
		assert_float(column.depth).is_less_equal(
			hills.depth - thickness * 0.8 - BackdropPlan.SMOKE_LIFT
		)
		assert_float(column.depth).is_greater_equal(
			hills.depth - thickness * 1.3 - BackdropPlan.SMOKE_LIFT - 0.001
		)
		assert_float(column.position.y).is_greater(BackdropPlan.GROUND_Y)
		assert_float(column.position.y).is_less(hills.extent.end.y)
	assert_int(plan.columns.size()).is_equal(4)


func test_columns_puff_and_the_puffs_rise_grow_thin_and_go() -> void:
	var plan := _plan()
	plan.front_line = false
	_advance(plan, 3.0)
	assert_int(plan.puffs.size()).is_greater(4)
	var puff := plan.puffs[0]
	var start := puff.position
	var fresh_scale := puff.scale()
	_advance(plan, 5.0)
	assert_float(puff.position.y).is_greater(start.y + 5.0)
	assert_float(puff.position.x).is_greater(start.x)
	assert_float(puff.scale()).is_greater(fresh_scale)
	assert_float(puff.remaining()).is_between(0.0, 1.0)
	_advance(plan, BackdropPlan.PUFF_LIFE)
	assert_bool(plan.puffs.has(puff)).is_false()
	assert_int(plan.puffs.size()).is_less_equal(BackdropPlan.MAX_PUFFS)
	for p in plan.puffs:
		assert_float(p.age).is_less(p.life)


func test_on_the_front_line_guns_flash_on_the_hills_and_leave_smoke() -> void:
	var plan := _plan()
	var seen_flash := false
	var burst_puffs := 0
	for i in 1200:
		plan.advance(0.1)
		if not plan.flashes.is_empty():
			seen_flash = true
			var flash := plan.flashes[0]
			assert_float(flash.remaining()).is_between(0.0, 1.0)
			assert_float(flash.position.y).is_greater(BackdropPlan.GROUND_Y)
			# Clear of the thickest hill or mountain it could be on.
			var hills := _layer(plan, "Hills")
			var mountains := _layer(plan, "Mountains")
			var on_hills := flash.depth < hills.depth
			var layer := hills if on_hills else mountains
			var thickness: float = BackdropPlan.PIECES[layer.piece]["thickness"]
			assert_float(flash.depth).is_less_equal(layer.depth - thickness * 0.8)
		for puff in plan.puffs:
			if puff.life == BackdropPlan.BURST_LIFE:
				burst_puffs += 1
	assert_bool(seen_flash).is_true()
	assert_int(plan.salvos).is_between(4, 25)
	assert_int(burst_puffs).is_greater(0)
	assert_int(plan.flashes.size()).is_less_equal(BackdropPlan.MAX_FLASHES)


func test_off_the_front_line_nothing_fires() -> void:
	var plan := BackdropPlan.create(
		WorldBounds.create(960.0, 160.0), DISTANCE, VIEW_HALF, 1, null, false
	)
	_advance(plan, 120.0)
	assert_int(plan.salvos).is_equal(0)
	assert_array(plan.flashes).is_empty()
	for puff in plan.puffs:
		assert_float(puff.life).is_equal(BackdropPlan.PUFF_LIFE)


func test_the_same_seed_plays_the_same_smoke_and_salvoes() -> void:
	var a := _plan(960.0, 160.0, 11)
	var b := _plan(960.0, 160.0, 11)
	_advance(a, 60.0)
	_advance(b, 60.0)
	assert_int(a.salvos).is_equal(b.salvos)
	assert_int(a.puffs.size()).is_equal(b.puffs.size())
	for i in a.puffs.size():
		assert_vector(a.puffs[i].position).is_equal(b.puffs[i].position)


func test_windmills_and_a_factory_stand_on_the_ground_in_their_layers() -> void:
	var plan := _plan()
	var kinds: Array[String] = []
	for feature in plan.features:
		kinds.append(feature.kind)
		assert_float(feature.position.x).is_between(0.0, 960.0)
		assert_float(feature.position.y).is_equal_approx(
			BackdropPlan.GROUND_Y - BackdropPlan.SINK, 0.001
		)
		assert_float(feature.depth).is_equal_approx(
			BackdropPlan.FEATURES[feature.kind]["depth"], 0.001
		)
	assert_array(kinds).contains_exactly(["windmill", "windmill", "factory"])
	assert_int(_plan(400.0).features.size()).is_equal(2)


func test_the_factory_chimney_is_one_of_the_smoke_columns() -> void:
	var plan := _plan()
	var factory: BackdropPlan.Feature = plan.features.back()  # placed after the windmills
	var offset: Vector2 = BackdropPlan.FEATURES["factory"]["chimney"] * factory.scale
	if factory.turned:
		offset.x = -offset.x
	var chimney := plan.columns[0]
	assert_vector(chimney.position).is_equal_approx(factory.position + offset, Vector2.ONE * 0.001)
	assert_float(chimney.depth).is_equal_approx(factory.depth - BackdropPlan.SMOKE_LIFT, 0.001)
	assert_int(plan.columns.size()).is_equal(4)
	plan.front_line = false
	_advance(plan, 3.0)
	var from_chimney := plan.puffs.filter(
		func(p: BackdropPlan.Puff) -> bool: return p.depth == chimney.depth
	)
	assert_int(from_chimney.size()).is_greater(0)


## Seen from any height the camera can reach, the Far range's silhouette stays above the
## horizon everywhere, so the sky's ground colour never shows between the Mountains.
func test_the_far_range_stands_above_the_horizon_from_every_camera_height() -> void:
	var plan := _plan()
	var far := _layer(plan, "Far")
	var rects := _sorted_rects(far)
	for camera_y in [VIEW_HALF.y, 160.0 - VIEW_HALF.y]:
		# The lowest point of the silhouette is where neighbouring flanks cross; a flank is
		# taken as straight from the base corner to the peak, which is below the real one.
		for i in range(1, rects.size()):
			var a := rects[i - 1]
			var b := rects[i]
			var dip := _crossing_height(a, b)
			# The dip projects above the horizon when it is above the camera's own height.
			assert_float(dip).is_greater(camera_y)
	assert_float(rects[0].position.y).is_equal_approx(
		BackdropPlan.GROUND_Y - BackdropPlan.SINK, 0.001
	)


## Where the right flank of a and the left flank of b, straight from corner to peak, cross.
func _crossing_height(a: Rect2, b: Rect2) -> float:
	var a_peak := Vector2(a.get_center().x, a.end.y)
	var a_foot := Vector2(a.end.x, a.position.y)
	var b_peak := Vector2(b.get_center().x, b.end.y)
	var b_foot := Vector2(b.position.x, b.position.y)
	var crossing: Variant = Geometry2D.segment_intersects_segment(a_peak, a_foot, b_peak, b_foot)
	if crossing == null:
		return minf(a_peak.y, b_peak.y)  # one silhouette inside the other
	return (crossing as Vector2).y


func test_the_factory_stands_clear_in_front_of_the_hills() -> void:
	var plan := _plan()
	var factory: BackdropPlan.Feature = plan.features.back()
	var hills := _layer(plan, "Hills")
	var thickness: float = BackdropPlan.PIECES["hill"]["thickness"]
	assert_float(factory.depth).is_less(hills.depth - thickness * 1.3)
