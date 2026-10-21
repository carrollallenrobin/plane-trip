class_name World
extends RefCounted
## A World as the Mission runs: the Planes and their Pilots, the bullets, Bombs and Shells in
## the air, the Ground Targets and their guns, each Hangar's Squadron of AI Planes (the
## enemy's, and the Wingmen on the player's side), the player's stock, and the Mission's
## outcome. Pure: no nodes. step(dt) advances everything, timers
## included, and returns the events the rendering reacts to (WorldEvent); what simply is
## (positions, projectiles, kills, the outcome) is read from the fields. WorldNode builds one
## from the mission scene and renders it (docs/design.md, Engineering).

var map: WorldMap
var mission: MissionDefinition
## The airframe every Plane in the World is built on.
var airframe: Airframe
var rules: MissionRules
var targets: Array[GroundTarget] = []
var player_side: int = Side.BLUE
## Seconds between a Plane's end and the next one appearing.
var respawn_delay := 1.8
## The player's Plane; the same record across its lives. Null in a World without a player.
var player: WorldPlane
## What the player's Plane carries: set with the player and by every Refit. A Plane parked on
## its own Airfield is Rearmed to it at once; a dead or spawning one is built from it.
var player_loadout: Loadout
## Every Plane in the World, the player's first. Enemies leave the list when destroyed.
var planes: Array[WorldPlane] = []
var combat := AirCombat.new()
var guns: GroundGuns
var damage: DamageRules
## Pieces of destroyed Planes and Ground Targets in flight or lying on the ground.
var debris: Array[Debris] = []
var kills := 0
var player_losses := 0
## Seconds the World has run: the Mission's clock.
var time := 0.0
var outcome := MissionRules.Outcome.ONGOING

var _tuning: FlightTuning
var _rng := RandomNumberGenerator.new()  # Debris spread
var _next_id := 1
var _pending: Array[Dictionary] = []  # the player's next life: {side, remaining}
## The enemy's Squadron first, then the Wingmen's.
var _squadrons: Array[Squadron] = []
var _events: Array[WorldEvent] = []


## A World ready to run. Each Squadron's first launch is scheduled, at once or after the
## Mission's first-launch delay; the player is added with add_player. A null mission means
## a free-flight World; null tuning or airframe means the defaults.
static func create(
	world_map: WorldMap,
	ground_targets: Array[GroundTarget],
	mission_definition: MissionDefinition,
	tuning: FlightTuning,
	side_of_player: int,
	seed_value := 1,
	respawn := 1.8,
	plane_airframe: Airframe = null
) -> World:
	var world := World.new()
	world.map = world_map
	world.targets = ground_targets
	world.mission = mission_definition if mission_definition != null else MissionDefinition.new()
	world.airframe = plane_airframe if plane_airframe != null else Airframe.new()
	world.rules = MissionRules.new(world.mission)
	world._tuning = tuning
	world.player_side = side_of_player
	world.respawn_delay = respawn
	world.damage = DamageRules.new(seed_value)
	world.guns = GroundGuns.new(seed_value)
	world._rng.seed = seed_value
	world.combat.gravity = FlightModel.new(tuning).tuning.gravity
	var m := world.mission
	world._squadrons = [
		Squadron.create(
			world._enemy_side(), m.enemy_aloft, m.enemy_pool, m.enemy_loadouts, m.spawn_interval
		),
		Squadron.create(
			side_of_player, m.wingmen_aloft, m.wingmen_pool, m.wingmen_loadouts, m.spawn_interval
		),
	]
	for squadron in world._squadrons:
		world._fill(squadron, m.first_launch_delay)
	return world


## Give the player a Plane with this Loadout, flown by this Pilot, at rest on the Home
## Airfield.
func add_player(loadout: Loadout, pilot: Pilot) -> WorldPlane:
	player_loadout = loadout
	player = _add_plane(loadout, player_side, pilot)
	return player


## The player's Refit: their Plane carries this from now on. Parked on its own Airfield it is
## Rearmed at once and set back at the start of that runway, pointing down it, as the
## original's mechanic pushed the plane out of the hangar; so being destroyed with the
## screen open needs no special case, and the choice applies to the next Plane. Returns
## true when a parked Plane was Rearmed.
func refit(loadout: Loadout) -> bool:
	player_loadout = loadout
	if player == null:
		return false
	player.loadout = loadout
	if not player.is_alive() or not player.parked_on_own_airfield(map):
		return false
	player.state.loadout = loadout
	player.flown_since_refit = false
	Rearm.complete(player.state)
	var airfield := map.airfield_at(player.state.position.x)
	player.park_at(airfield.spawn_position(), airfield.heading_right)
	return true


## Advance the whole World by dt seconds and return what happened.
func step(dt: float) -> Array[WorldEvent]:
	time += dt
	_advance_spawns(dt)
	_step_planes(dt)
	var present := _states_in_play()
	_step_bullets(dt, present)
	_step_bombs(dt, present)
	_step_guns(dt, present)
	_step_debris(dt, present)
	_update_outcome()
	var events := _events
	_events = []
	return events


func enemies_alive() -> int:
	return _squadrons[0].aloft_count()


## Planes the enemy Hangar can still send up; -1 when it can send as many as it likes.
func enemies_left() -> int:
	return _squadrons[0].left()


func wingmen_alive() -> int:
	return _squadrons[1].aloft_count()


## True when the enemy has nothing Aloft and nothing more to send: its Hangar is gone, or
## its pool is spent.
func enemy_grounded() -> bool:
	return _squadrons[0].grounded(_hangar_stands(_enemy_side()))


func player_planes_left() -> int:
	return rules.planes_left(player_losses)


## True when the player is stopped on the Home Airfield.
func player_returned() -> bool:
	return player != null and player.is_alive() and player.parked_on_own_airfield(map)


func target_named(name: String) -> GroundTarget:
	for target in targets:
		if target.name == name:
			return target
	return null


## Every Objective with how it stands right now, for the HUD and the Debrief.
func objective_statuses() -> Array[ObjectiveStatus]:
	return rules.statuses(_facts())


## What the rules read of the World right now.
func _facts() -> MissionFacts:
	return MissionFacts.create(targets, player_returned(), kills, enemy_grounded())


# --- Planes ---


func _add_plane(loadout: Loadout, side: int, pilot: Pilot) -> WorldPlane:
	var plane := WorldPlane.create(airframe, loadout, side, pilot, FlightModel.new(_tuning))
	plane.state.id = _next_id
	_next_id += 1
	planes.append(plane)
	_spawn(plane)
	return plane


func _spawn(plane: WorldPlane) -> void:
	var airfield := map.home_airfield(plane.side)
	if airfield == null:
		push_warning(
			"No airfield for side %s; plane left where it is" % Side.display_name(plane.side)
		)
		return
	plane.place_on_runway(airfield.spawn_position(), airfield.heading_right)


## Every live Plane decides, flies, and may crash, fire or drop a Bomb. The crash rules run
## right after the flight model, on the same tick, so a Plane never fires from inside a hill.
func _step_planes(dt: float) -> void:
	var present := _states_in_play()
	for plane: WorldPlane in planes.duplicate():
		if not plane.is_alive():
			continue
		var input := plane.step(map, _others_of(plane, present), targets, dt)
		var crash := CrashRules.check(plane.state, map)
		if crash != CrashRules.Outcome.NONE:
			_destroy(plane, crash)
			continue
		if plane == player and plane.flown_since_refit and plane.parked_on_own_airfield(map):
			plane.flown_since_refit = false
			_events.append(WorldEvent.for_plane(WorldEvent.Kind.REFIT_DUE, plane))
		var bullet := combat.try_fire(plane.state, input)
		if bullet != null:
			var shot := WorldEvent.for_plane(WorldEvent.Kind.GUN_FIRED, plane)
			shot.position = bullet.position
			shot.direction = plane.state.nose()
			_events.append(shot)
		var bomb := combat.try_drop(plane.state, input)
		if bomb != null:
			var release := WorldEvent.for_plane(WorldEvent.Kind.BOMB_RELEASED, plane)
			release.position = bomb.position
			_events.append(release)


func _step_bullets(dt: float, present: Array[PlaneState]) -> void:
	for hit in combat.step(dt, map, present, targets):
		if hit.surface == BulletHit.Surface.PLANE:
			var roll := (
				damage.ground_bullet_hit(hit.target)
				if hit.bullet.owner_id < 0
				else damage.bullet_hit(hit.target)
			)
			_apply_hit(
				hit.target, roll, hit.position, hit.direction(), _is_players(hit.bullet.owner_id)
			)
			continue
		var impact := WorldEvent.at(WorldEvent.Kind.BULLET_IMPACT, hit.position)
		impact.surface = hit.surface
		impact.direction = hit.direction()
		impact.target = hit.ground_target
		_events.append(impact)
		if hit.surface == BulletHit.Surface.TARGET and hit.ground_target.is_gun():
			if damage.bullet_hit_ground_target(hit.ground_target):
				_target_destroyed(hit.ground_target)


func _step_bombs(dt: float, present: Array[PlaneState]) -> void:
	for impact in combat.step_bombs(dt, map, present, targets):
		_events.append(WorldEvent.at(WorldEvent.Kind.BOMB_DETONATED, impact.position))
		if impact.plane != null:
			var blast := damage.blast(impact.plane, GroundTarget.BOMB_DAMAGE)
			var away := _away_from(impact.position, impact.plane, impact.bomb.velocity)
			_apply_hit(
				impact.plane, blast, impact.plane.position, away, _is_players(impact.bomb.owner_id)
			)
		elif impact.ground_target != null and impact.ground_target.damage(GroundTarget.BOMB_DAMAGE):
			_target_destroyed(impact.ground_target)


func _step_guns(dt: float, present: Array[PlaneState]) -> void:
	var bursts := guns.step(dt, map, present, targets, combat)
	for shot in guns.shots:
		var fired := WorldEvent.at(WorldEvent.Kind.GUN_FIRED, shot.position)
		fired.target = shot.gun
		fired.direction = shot.direction
		_events.append(fired)
	for burst in bursts:
		_events.append(WorldEvent.at(WorldEvent.Kind.SHELL_BURST, burst.position))
		for state in present:
			var amount := ShellBurst.damage_at(state.position.distance_to(burst.position))
			if amount > 0:
				var away := _away_from(burst.position, state, Vector2(0.0, 1.0))
				_apply_hit(state, damage.blast(state, amount), state.position, away)


## Debris flies, settles on the terrain, ages out, and wounds any Plane a piece touches.
func _step_debris(dt: float, present: Array[PlaneState]) -> void:
	var survivors: Array[Debris] = []
	for piece in debris:
		piece.age += dt
		if piece.age > Debris.LIFETIME:
			continue
		if not piece.settled:
			piece.advance(dt, combat.gravity)
			piece.angle += piece.spin * dt
			if map.bounds.is_outside(piece.position.x):
				continue
			if map.terrain.is_below_surface(piece.position):
				piece.settle(map.terrain.height_at(piece.position.x))
			else:
				var struck := _plane_at(piece.position, present)
				if struck != null:
					var along := piece.velocity.normalized()
					_apply_hit(struck, damage.debris_hit(struck), piece.position, along)
					continue
		survivors.append(piece)
	debris = survivors


static func _plane_at(point: Vector2, present: Array[PlaneState]) -> PlaneState:
	for state in present:
		if state.in_play() and state.contains_point(point):
			return state
	return null


## Apply a hit. `impact` and `direction` say where the Plane was hit and which way the hit
## was going, for the picture and the knockback, which lands before the events so Debris
## from a Plane destroyed by it inherits the shove. `by_player` says the player's Machine
## Gun or Bomb did it, which is what earns a kill; ground guns, Debris and the terrain earn
## nobody anything.
func _apply_hit(
	state: PlaneState, hit: DamageRules.Hit, impact: Vector2, direction: Vector2, by_player := false
) -> void:
	var plane := _plane_of(state)
	if plane == null or not plane.is_alive():
		return
	Knockback.apply(state, direction, hit)
	var event := WorldEvent.for_plane(WorldEvent.Kind.PLANE_HIT, plane)
	event.position = impact
	event.direction = direction
	_events.append(event)
	if hit.outcome == DamageRules.Outcome.EXPLODE:
		_destroy(plane, CrashRules.Outcome.NONE, by_player)
	elif hit.outcome == DamageRules.Outcome.SPIN and by_player:
		_count_kill(plane)


## The way a Blast at `centre` pushes the Plane: away from the centre, or along `fallback`
## when the Blast is on the Plane itself.
static func _away_from(centre: Vector2, state: PlaneState, fallback: Vector2) -> Vector2:
	var away := state.position - centre
	if away.is_zero_approx():
		return fallback.normalized()
	return away.normalized()


func _is_players(owner_id: int) -> bool:
	return player != null and owner_id == player.state.id


## The Plane is gone. The player's record stays for its next life if the stock allows; an
## AI Plane's leaves the World and its Squadron is asked for the next.
func _destroy(plane: WorldPlane, crash: CrashRules.Outcome, by_player := false) -> void:
	var event := WorldEvent.for_plane(WorldEvent.Kind.PLANE_DESTROYED, plane)
	event.crash = crash
	plane.state.destroyed = true
	_events.append(event)
	debris.append_array(Debris.burst(event.position, event.velocity, _rng))
	if plane == player:
		player_losses += 1
		if rules.planes_left(player_losses) > 0:
			_pending.append({"side": player_side, "remaining": respawn_delay})
	else:
		if by_player:
			_count_kill(plane)
		planes.erase(plane)
		for squadron in _squadrons:
			if squadron.holds(plane):
				squadron.release(plane)
				_fill(squadron, respawn_delay)


## A kill is the player's when their Machine Gun or Bomb takes an enemy Plane out of the
## fight, and it counts once: at the Spin, or at the Blast that destroys it outright. A
## Wingman shot down is nobody's kill.
func _count_kill(plane: WorldPlane) -> void:
	if plane == player or plane.side == player_side or plane.kill_counted:
		return
	plane.kill_counted = true
	kills += 1


func _target_destroyed(target: GroundTarget) -> void:
	var event := WorldEvent.at(WorldEvent.Kind.TARGET_DESTROYED, target.centre())
	event.target = target
	_events.append(event)
	debris.append_array(Debris.burst(target.centre(), Vector2.ZERO, _rng))


func _states_in_play() -> Array[PlaneState]:
	var states: Array[PlaneState] = []
	for plane in planes:
		if plane.is_alive():
			states.append(plane.state)
	return states


static func _others_of(plane: WorldPlane, present: Array[PlaneState]) -> Array[PlaneState]:
	var others: Array[PlaneState] = []
	for state in present:
		if state != plane.state:
			others.append(state)
	return others


func _plane_of(state: PlaneState) -> WorldPlane:
	for plane in planes:
		if plane.state == state:
			return plane
	return null


# --- Spawning ---


func _enemy_side() -> int:
	return Side.RED if player_side == Side.BLUE else Side.BLUE


## A Side's Hangar, if the World has one. Destroying it stops that Side's Squadron.
func _hangar_of(side: int) -> GroundTarget:
	for target in targets:
		if target.kind == GroundTarget.Kind.HANGAR and target.side == side:
			return target
	return null


## True while a Side can send Planes up: its Hangar stands, or it never had one.
func _hangar_stands(side: int) -> bool:
	var hangar := _hangar_of(side)
	return hangar == null or hangar.is_alive()


## Ask the Squadron for a Plane in every empty slot, if its Hangar still stands.
func _fill(squadron: Squadron, delay: float) -> void:
	if _hangar_stands(squadron.side):
		squadron.fill(delay)


func _advance_spawns(dt: float) -> void:
	var still_pending: Array[Dictionary] = []
	for entry in _pending:
		entry["remaining"] -= dt
		if entry["remaining"] > 0.0:
			still_pending.append(entry)
		else:
			_spawn(player)
			_events.append(WorldEvent.for_plane(WorldEvent.Kind.PLANE_SPAWNED, player))
			_events.append(WorldEvent.for_plane(WorldEvent.Kind.REFIT_DUE, player))
	_pending = still_pending
	for squadron in _squadrons:
		for slot in squadron.step(dt):
			_launch(squadron, slot)


## A Squadron's Plane takes its slot: an AI Pilot from the Side's Airfield, carrying the
## slot's preset, or what the player does when the Mission gives none.
func _launch(squadron: Squadron, slot: int) -> void:
	if not _hangar_stands(squadron.side):
		return
	var home := map.home_airfield(squadron.side)
	if home == null:
		return
	var loadout := squadron.loadout_for(slot)
	if loadout == null:
		loadout = player.loadout if player != null else Loadout.new()
	var pilot := AiPilot.create(map, home, FlightModel.new(_tuning))
	var plane := _add_plane(loadout, squadron.side, pilot)
	squadron.occupy(slot, plane)
	_events.append(WorldEvent.for_plane(WorldEvent.Kind.PLANE_SPAWNED, plane))


# --- Mission ---


func _update_outcome() -> void:
	if outcome != MissionRules.Outcome.ONGOING:
		return
	var now := rules.outcome(_facts(), player_losses)
	if now != MissionRules.Outcome.ONGOING:
		outcome = now
		var event := WorldEvent.make(WorldEvent.Kind.MISSION_ENDED)
		event.outcome = now
		_events.append(event)
