extends GdUnitTestSuite

var _house: GroundTarget
var _depot: GroundTarget
var _targets: Array[GroundTarget]


func before_test() -> void:
	_house = GroundTarget.create(
		"house", Side.RED, GroundTarget.Kind.BUILDING, Vector2(300.0, 10.0), 10.0, 6.0
	)
	_depot = GroundTarget.create(
		"depot", Side.BLUE, GroundTarget.Kind.BUILDING, Vector2(100.0, 10.0), 10.0, 6.0
	)
	_targets = [_house, _depot]


func _facts(returned := false, kills := 0, enemy_grounded := false) -> MissionFacts:
	return MissionFacts.create(_targets, returned, kills, enemy_grounded)


func _mission(objectives: Array[Objective], planes := 3) -> MissionRules:
	var definition := MissionDefinition.new()
	definition.objectives = objectives
	definition.player_planes = planes
	return MissionRules.new(definition)


func test_won_when_every_required_objective_is_complete() -> void:
	var rules := _mission(
		[
			Objective.create(Objective.Kind.DESTROY, "house"),
			Objective.create(Objective.Kind.DESTROY, "depot", false),
		]
	)
	assert_int(rules.outcome(_facts(false), 0)).is_equal(MissionRules.Outcome.ONGOING)
	_house.damage(GroundTarget.BOMB_DAMAGE)
	assert_int(rules.outcome(_facts(false), 0)).is_equal(MissionRules.Outcome.WON)
	assert_int(rules.status_of(rules.definition.objectives[1], _facts())).is_equal(
		MissionRules.Status.OPEN
	)


func test_lost_when_a_protected_target_dies_or_the_stock_runs_out() -> void:
	var rules := _mission(
		[
			Objective.create(Objective.Kind.DESTROY, "house"),
			Objective.create(Objective.Kind.PROTECT, "depot"),
		],
		2
	)
	assert_int(rules.outcome(_facts(false), 1)).is_equal(MissionRules.Outcome.ONGOING)
	assert_int(rules.planes_left(1)).is_equal(1)
	assert_int(rules.outcome(_facts(false), 2)).is_equal(MissionRules.Outcome.LOST)
	assert_int(rules.status_of(rules.definition.objectives[1], _facts())).is_equal(
		MissionRules.Status.COMPLETE
	)
	_house.damage(GroundTarget.BOMB_DAMAGE)
	assert_int(rules.outcome(_facts(false), 0)).is_equal(MissionRules.Outcome.WON)
	_depot.damage(GroundTarget.BOMB_DAMAGE)
	assert_int(rules.outcome(_facts(false), 0)).is_equal(MissionRules.Outcome.LOST)


func test_return_completes_only_after_the_other_required_objectives() -> void:
	var rules := _mission(
		[
			Objective.create(Objective.Kind.DESTROY, "house"),
			Objective.create(Objective.Kind.RETURN),
		]
	)
	assert_int(rules.outcome(_facts(true), 0)).is_equal(MissionRules.Outcome.ONGOING)
	_house.damage(GroundTarget.BOMB_DAMAGE)
	assert_int(rules.outcome(_facts(false), 0)).is_equal(MissionRules.Outcome.ONGOING)
	assert_int(rules.outcome(_facts(true), 0)).is_equal(MissionRules.Outcome.WON)


func test_a_mission_without_objectives_never_ends_by_itself() -> void:
	var rules := _mission([])
	assert_int(rules.outcome(_facts(true), 0)).is_equal(MissionRules.Outcome.ONGOING)


func test_statuses_list_every_objective_in_order() -> void:
	var depot := GroundTarget.create(
		"depot", Side.RED, GroundTarget.Kind.BUILDING, Vector2(300.0, 10.0), 10.0, 6.0
	)
	var store := GroundTarget.create(
		"store", Side.BLUE, GroundTarget.Kind.BUILDING, Vector2(100.0, 10.0), 10.0, 6.0
	)
	var mission := MissionDefinition.new()
	mission.objectives = [
		Objective.create(Objective.Kind.DESTROY, "depot"),
		Objective.create(Objective.Kind.PROTECT, "store", false),
		Objective.create(Objective.Kind.RETURN),
	]
	var rules := MissionRules.new(mission)
	var targets: Array[GroundTarget] = [depot, store]
	var statuses := rules.statuses(MissionFacts.create(targets, false))
	assert_int(statuses.size()).is_equal(3)
	assert_object(statuses[0].objective).is_same(mission.objectives[0])
	assert_int(statuses[0].status).is_equal(MissionRules.Status.OPEN)
	assert_int(statuses[1].status).is_equal(MissionRules.Status.COMPLETE)
	assert_int(statuses[2].status).is_equal(MissionRules.Status.OPEN)
	assert_str(statuses[0].objective.display_title()).is_equal("Destroy depot")
	assert_str(statuses[2].objective.display_title()).is_equal("Return home")
	depot.damage(GroundTarget.BOMB_DAMAGE)
	store.damage(GroundTarget.BOMB_DAMAGE)
	statuses = rules.statuses(MissionFacts.create(targets, true))
	assert_int(statuses[0].status).is_equal(MissionRules.Status.COMPLETE)
	assert_int(statuses[1].status).is_equal(MissionRules.Status.FAILED)
	assert_int(statuses[2].status).is_equal(MissionRules.Status.COMPLETE)


func test_shoot_down_completes_at_the_count_or_once_the_enemy_is_grounded() -> void:
	var rules := _mission([Objective.shoot_down(3)])
	var objective := rules.definition.objectives[0]
	assert_str(objective.display_title()).is_equal("Shoot down 3 planes")
	assert_str(Objective.shoot_down(1).display_title()).is_equal("Shoot down 1 plane")
	assert_int(rules.status_of(objective, _facts(false, 2))).is_equal(MissionRules.Status.OPEN)
	assert_int(rules.outcome(_facts(false, 2), 0)).is_equal(MissionRules.Outcome.ONGOING)
	assert_int(rules.status_of(objective, _facts(false, 3))).is_equal(MissionRules.Status.COMPLETE)
	assert_int(rules.outcome(_facts(false, 3), 0)).is_equal(MissionRules.Outcome.WON)
	# Nothing left to shoot at counts as done, however few were the player's.
	assert_int(rules.status_of(objective, _facts(false, 0, true))).is_equal(
		MissionRules.Status.COMPLETE
	)
	# The statuses carry the tally so far.
	var statuses := rules.statuses(_facts(false, 2))
	assert_int(statuses[0].tally).is_equal(2)
	assert_int(statuses[0].status).is_equal(MissionRules.Status.OPEN)
	# A Shoot Down names no target, so it is never an unresolved name.
	assert_array(rules.unresolved_target_names(_targets)).is_empty()


func test_objectives_naming_unknown_targets_are_reported() -> void:
	var depot := GroundTarget.create(
		"depot", Side.RED, GroundTarget.Kind.BUILDING, Vector2(300.0, 10.0), 10.0, 6.0
	)
	var mission := MissionDefinition.new()
	mission.objectives = [
		Objective.create(Objective.Kind.DESTROY, "depot"),
		Objective.create(Objective.Kind.DESTROY, "Depo"),
		Objective.create(Objective.Kind.PROTECT, "Depo"),
		Objective.create(Objective.Kind.RETURN),
	]
	var rules := MissionRules.new(mission)
	var targets: Array[GroundTarget] = [depot]
	assert_array(rules.unresolved_target_names(targets)).contains_exactly(["Depo"])
	var sound := _mission([Objective.create(Objective.Kind.DESTROY, "depot")])
	assert_array(sound.unresolved_target_names(targets)).is_empty()
