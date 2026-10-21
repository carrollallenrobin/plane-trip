class_name AiPilot
extends Pilot
## The AI pilot: a port of the original Triplane Classic state machine (src/world/tripai.cpp,
## do_ai) in this project's units. Take off, patrol, turn around before the Borders with a
## split-S or an Immelmann, climb away from terrain seen a second ahead, chase enemies in
## range, fire inside a cone unless a friend is in the way, and come home to land on a 1:3
## glide slope when out of ammunition or low on fuel. Pure: no nodes, no randomness.
##
## Deliberate deviations, all because this project's flight model keeps speed through climbs
## and turns wide at speed, unlike the original's energy model the AI was written for:
## - A pilot that wants home steers for the approach point on the slope instead of waiting
##   for a patrol pass to cross it by luck (_head_for_home).
## - The original's Immelmann and split-S are replaced by one turn-around: slow down with the
##   engine off and the air brake until the full pitch rate is available, then pull through a
##   half loop upward if there is room, downward after a half-roll otherwise (_turnaround).
## - The ceiling guard pushes the nose down early enough to level off at the current turn
##   radius, not only within the original's 20 px.
## - The landing approach steers for the touchdown point and holds speed with the brake and
##   the throttle, instead of the original's nose-down limit and speed thresholds, which
##   cannot lose height fast enough when speed lingers (_land).
##
## Pitch helpers come in two frames, as in the original: "raw" pull/push is in the body frame
## (what the stick does), "screen" up/down is in the world frame, and ccw/cw is a rotation
## direction. The original mixes them freely; the port keeps each call as it was.

enum Mission { NOMISSION, TAKEOFF, LAND, TURNAROUND, CHASE_PLANE, EVADE_TERRAIN }

## Original: AI_ATTACK_DISTANCE 200 px.
const ATTACK_DISTANCE := 200.0 * SimUnits.PIXEL
## Original: AIM_GIVEUPFIGHT_DISTANCE 350 px.
const GIVE_UP_DISTANCE := 350.0 * SimUnits.PIXEL
## Original: SHOT_AT_RANGE 200 px, SHOT_AT_ANGLE 30 degrees.
const SHOT_RANGE := 200.0 * SimUnits.PIXEL
const SHOT_ANGLE := 30.0
## Original: a friend within SHOT_AT_RANGE - 20 px and 8 degrees blocks the shot.
const FRIENDLY_RANGE := 180.0 * SimUnits.PIXEL
const FRIENDLY_ANGLE := 8.0
## Original: leads the target by its velocity over 2 ticks.
const LEAD_TIME := 2.0 * SimUnits.TICK
## Speed thresholds are fractions of the plane's top speed; the fractions are the original's
## absolute values over the original German plane's top speed of about 3833 units.
## Original: pulling up below 1800 units with the nose up is a stall risk.
const STALL_WARNING := 0.47
## Original: below 2350 + bombs * 64 units, only pull up while already climbing.
const STALL_WARNING_BASE := 0.61
const STALL_WARNING_PER_BOMB := 0.017
## Original: take-off lasts until 40 px above the terrain.
const TAKEOFF_CLEARANCE := 40.0 * SimUnits.PIXEL
## Original: looks AVOID_TERRAIN_FRAMES (24) ahead at a point 10 px below the plane.
const LOOKAHEAD_TIME := 24.0 * SimUnits.TICK
const LOOKAHEAD_DROP := 10.0 * SimUnits.PIXEL
## Original: the terrain profile is widened by 25 px to each side.
const WIDE_TERRAIN_RADIUS := 25.0 * SimUnits.PIXEL
## Original: climbs away from terrain at 15 to 25 degrees.
const CLIMB_LIMIT := 25.0
const CLIMB_MARGIN := 10.0
## Original: evasion lasts 24 frames.
const EVADE_DURATION := 24.0 * SimUnits.TICK
## Original: turns around within 120 px + speed / 40 px of a Border. Here the distance is
## the room the turn-around needs: braking to the turn speed, the loop, and this margin.
const EDGE_MARGIN := 120.0 * SimUnits.PIXEL
## Original: split-S when there is 15 px more room below than above, else Immelmann.
const ROOM_BELOW_MARGIN := 15.0 * SimUnits.PIXEL
## Turn-around: slow to this fraction of top speed before pulling. Below the corner speed the
## turn radius is constant, so the corner is the fastest speed that still gives the tightest
## loop, and the energy to climb through it; needs twice the loop radius plus this margin.
const TURNAROUND_SPEED := 0.7
const TURNAROUND_ROOM_MARGIN := 10.0
## A full pull below this multiple of stall speed stalls the wing; the AI eases off instead.
const STALL_EASE_SPEED := 1.05
const STALL_EASE_ANGLE := 2.0
const SPLIT_S_DONE_CLIMB := 750.0 / 256.0
## Original: pushes the nose down within 20 px of the top.
const CEILING_MARGIN := 20.0 * SimUnits.PIXEL
## Original: go around when 9 px past the aiming point.
const LANDING_OVERSHOOT := 9.0 * SimUnits.PIXEL
## Approach: aim this far past the runway threshold, descend no steeper than this, keep the
## speed between these fractions of top speed, flatten to the landing cone below this height.
const TOUCHDOWN_OFFSET := 15.0
const APPROACH_MAX_DESCENT := 25.0
const APPROACH_MAX_CLIMB := 5.0
const APPROACH_SLOW := 0.3
const APPROACH_FAST := 0.45
const APPROACH_FLARE_HEIGHT := 6.0
const APPROACH_STEER_TOLERANCE := 3.0
## Original approach: between 100 and 600 px short of the runway centre, within 5 px of the
## 1:3 slope, and slower than 2000 units, or higher than 130 px, or high for its speed.
const APPROACH_MIN := 100.0 * SimUnits.PIXEL
const APPROACH_MAX := 600.0 * SimUnits.PIXEL
const APPROACH_SLOPE_TOLERANCE := 5.0 * SimUnits.PIXEL
const APPROACH_SPEED := 0.52
const APPROACH_HIGH := 130.0 * SimUnits.PIXEL
const APPROACH_HEIGHT_PER_TOP := 3833.0 / 64.0 * SimUnits.PIXEL
## Original: heads home below 500 ticks of fuel.
const HOME_FUEL := 500.0 * SimUnits.TICK
## Bombs are released only when roughly level: climbing less than this, diving less than this.
const BOMBING_MAX_CLIMB := 20.0
const BOMBING_MAX_DIVE := 45.0
## Addition: the approach point lies this far out on the 1:3 slope, and a pilot flying away
## from it by more than this distance turns around.
const APPROACH_POINT_DISTANCE := 180.0
const HOMING_STEER_TOLERANCE := 2.0
## When heading away from the approach point, its height is held over this distance.
const HOMING_LEVEL_DISTANCE := 100.0

var map: WorldMap
var home: Airfield
## The flight model, for its speeds and turn rates.
var model := FlightModel.new()

var mission := Mission.TAKEOFF
var phase := 0
var target_id := -1
## For turn-arounds: true when the turn started heading left.
var _turn_started_left := false
var _turn_rolled := false
var _evade_elapsed := 0.0

var _input: FlightInput
var _going_left := false
var _going_up := 0.0
## What the Pilot saw this step: the other Planes in play and the Ground Targets.
var _others: Array[PlaneState] = []
var _targets: Array[GroundTarget] = []
## Targets this Pilot has a Bomb falling toward, by name: seconds until it lands. Original:
## a structure already targeted by a falling bomb is skipped.
var _bombs_falling: Dictionary = {}


static func create(
	world_map: WorldMap, home_airfield: Airfield, flight_model: FlightModel = null
) -> AiPilot:
	var pilot := AiPilot.new()
	pilot.map = world_map
	pilot.home = home_airfield
	if flight_model != null:
		pilot.model = flight_model
	return pilot


## A fresh Plane on the runway: back to the take-off, with nothing chased or remembered.
func start_life() -> void:
	mission = Mission.TAKEOFF
	phase = 0
	target_id = -1
	_turn_started_left = false
	_turn_rolled = false
	_evade_elapsed = 0.0
	_bombs_falling = {}


## The plane's speed as a fraction of its top speed at its current weight.
func _top_fraction(s: PlaneState) -> float:
	return s.speed / model.top_speed_of(s)


func decide(
	s: PlaneState, others: Array[PlaneState], targets: Array[GroundTarget], dt: float
) -> FlightInput:
	_others = others
	_targets = targets
	_input = FlightInput.new()
	var flight := s.flight_angle()  # the nose's angle, or the velocity's under the Newtonian model
	_going_left = flight > 90.0 and flight <= 270.0
	_going_up = _climb_angle(flight)
	# Original: engine off in a steep dive, on otherwise.
	_input.thrust = not (flight >= 225.0 and flight <= 315.0)

	match mission:
		Mission.TAKEOFF:
			if s.position.y - map.terrain.height_at(s.position.x) < TAKEOFF_CLEARANCE:
				phase = 0
			else:
				mission = Mission.NOMISSION
			if s.on_airfield:
				_takeoff_roll(s)
			elif _near_border(s, _turnaround_distance(s)):
				_start_turnaround(s)
			_evade_terrain(s)
		Mission.LAND:
			_land(s)
		Mission.TURNAROUND:
			_turnaround(s)
		Mission.CHASE_PLANE:
			_chase(s)
			_patrol(s)
		Mission.NOMISSION:
			_patrol(s)
		Mission.EVADE_TERRAIN:
			_evade_mission(s, dt)

	_consider_landing(s)
	_consider_bombing(s, dt)
	_rearm_and_relaunch(s)
	if (
		_going_up > 0.0
		and map.bounds.ceiling_y - s.position.y <= CEILING_MARGIN + _level_off_height(s)
	):
		_turn_screen_down(s)
	_gunnery(s)
	return _input


## Addition for this project's ground rules: level the tail to accelerate, pull at
## rotation speed.
func _takeoff_roll(s: PlaneState) -> void:
	_input.thrust = true
	if s.speed >= model.rotation_speed():
		_pull_only()
	elif s.pitch_in_body_frame() > 1.0:
		_push_only()
	elif s.pitch_in_body_frame() < -1.0:
		_pull_only()


func _patrol(s: PlaneState) -> void:
	if mission != Mission.CHASE_PLANE and s.rounds > 0:
		for other in _others:
			if other.side != s.side and _distance(s, other) < ATTACK_DISTANCE:
				mission = Mission.CHASE_PLANE
				target_id = other.id
	if _near_border(s, _turnaround_distance(s)):
		_start_turnaround(s)
	elif not s.wheels_down() and s.roll_remaining == 0.0:
		_input.roll = true
	if mission == Mission.NOMISSION and _wants_home(s):
		_head_for_home(s)
	_evade_terrain(s)


## Addition to the original: fly to the approach point on the home airfield's slope. Heading
## the landing direction, steer for the point and start the approach on reaching it. Heading
## the other way, keep the point's height and turn around once past it with room to loop.
func _head_for_home(s: PlaneState) -> void:
	var direction := 1.0 if home.heading_right else -1.0
	var point := Vector2(
		home.centre_x() - direction * APPROACH_POINT_DISTANCE,
		home.surface_y + APPROACH_POINT_DISTANCE / 3.0
	)
	var to_point := (point.x - s.position.x) * direction  # positive: point still ahead
	var heading_landing_direction := _going_left != home.heading_right
	if heading_landing_direction and to_point <= 0.0:
		mission = Mission.LAND
		phase = 0
		return
	if not heading_landing_direction and to_point >= _turnaround_distance(s) - EDGE_MARGIN:
		_start_turnaround(s)
		return
	var horizontal := maxf(absf(point.x - s.position.x), HOMING_LEVEL_DISTANCE)
	var wanted_climb := clampf(
		rad_to_deg(atan2(point.y - s.position.y, horizontal)), -CLIMB_LIMIT, CLIMB_LIMIT
	)
	var climb := _signed_climb_angle(s.flight_angle())
	if climb < wanted_climb - HOMING_STEER_TOLERANCE:
		if _top_fraction(s) >= STALL_WARNING or wanted_climb <= 0.0:
			_turn_screen_up(s)
	elif climb > wanted_climb + HOMING_STEER_TOLERANCE:
		_turn_screen_down(s)


func _wants_home(s: PlaneState) -> bool:
	return (s.bombs == 0 and s.rounds == 0) or s.fuel < HOME_FUEL


func _chase(s: PlaneState) -> void:
	var target := _find(target_id)
	if s.rounds <= 0 or target == null or _distance(s, target) > GIVE_UP_DISTANCE:
		mission = Mission.NOMISSION
	else:
		var error := wrapf(s.angle - _bearing(s, target), -180.0, 180.0)
		if error > 0.0:
			_turn_cw(s)
		elif error < 0.0:
			_turn_ccw(s)
	# Stall guards, as in the original: do not pull up slowly into a climb.
	var fraction := _top_fraction(s)
	if _input.pitch_up and fraction < STALL_WARNING:
		if _going_up > 0.0 and (s.angle > 125.0 or s.angle < 55.0):
			_turn_screen_down(s)
	elif _input.pitch_up:
		var limit := STALL_WARNING_BASE + s.bombs * STALL_WARNING_PER_BOMB
		if fraction < limit and _going_up <= 0.0:
			_input.pitch_up = false
			_input.pitch_down = false


func _evade_mission(s: PlaneState, dt: float) -> void:
	if _near_border(s, _turnaround_distance(s)):
		_start_turnaround(s)
		return
	if not s.wheels_down() and s.roll_remaining == 0.0:
		_input.roll = true
	_evade_terrain(s)
	_evade_elapsed += dt
	if _evade_elapsed >= EVADE_DURATION:
		mission = Mission.NOMISSION


## Look a second ahead along the velocity, a little below the plane; climb if that point is
## under the widened terrain. Never while on an airfield.
func _evade_terrain(s: PlaneState) -> void:
	var ahead := s.position + s.velocity() * LOOKAHEAD_TIME
	var x := clampf(ahead.x, 0.0, map.bounds.width)
	var point_y := ahead.y - LOOKAHEAD_DROP
	if map.terrain.highest_within(x, WIDE_TERRAIN_RADIUS) > point_y and not s.on_airfield:
		if _going_up > CLIMB_LIMIT - CLIMB_MARGIN:
			_turn_screen_down(s)
		if _going_up < CLIMB_LIMIT:
			_turn_screen_up(s)
		if mission != Mission.EVADE_TERRAIN:
			mission = Mission.EVADE_TERRAIN
			_evade_elapsed = 0.0


func _start_turnaround(_s: PlaneState) -> void:
	mission = Mission.TURNAROUND
	phase = 0
	_turn_started_left = _going_left
	_turn_rolled = false


## Distance from a Border at which the turn-around must start: braking from the current
## speed to the turn speed with the engine off and the air brake on, plus the loop's
## diameter at the turn speed, plus the original's margin.
func _turnaround_distance(s: PlaneState) -> float:
	var top := model.top_speed_of(s)
	var turn_speed := TURNAROUND_SPEED * top
	var braking := 0.0
	if s.speed > turn_speed:
		var mean := (s.speed + turn_speed) / 2.0
		var deceleration := model.tuning.air_brake_deceleration
		deceleration += model.coasting_drag(mean)
		braking = (s.speed - turn_speed) * mean / deceleration
	var radius := turn_speed / deg_to_rad(model.max_turn_rate(turn_speed))
	return EDGE_MARGIN + braking + 2.0 * radius


## Radius of a loop at the current speed and pitch rate.
func _loop_radius(s: PlaneState) -> float:
	return s.speed / deg_to_rad(maxf(model.max_turn_rate(s.speed), 1.0))


## Height needed to level off from the current climb at the current loop radius.
func _level_off_height(s: PlaneState) -> float:
	return _loop_radius(s) * (1.0 - cos(deg_to_rad(_going_up)))


func _turnaround(s: PlaneState) -> void:
	match phase:
		0:
			# Slow down: engine off, air brake, keep level.
			_input.thrust = false
			_input.pitch_up = true
			_input.pitch_down = true
			if _top_fraction(s) <= TURNAROUND_SPEED:
				var room_needed := 2.0 * _loop_radius(s) + TURNAROUND_ROOM_MARGIN
				var above := map.bounds.ceiling_y - s.position.y
				var below := (
					s.position.y - map.terrain.highest_within(s.position.x, WIDE_TERRAIN_RADIUS)
				)
				phase = 1 if above >= room_needed or above >= below else 2
		1:
			# Half loop upward with the engine on: pull through without rolling; the patrol
			# rolls wheels-down afterwards.
			_input.thrust = true
			_pull_without_stalling(s)
			if _going_left != _turn_started_left and _going_up <= 0.0:
				mission = Mission.NOMISSION
		2:
			# Half loop downward: roll inverted once, then pull toward the canopy (now down).
			_input.thrust = false
			if not _turn_rolled:
				_input.roll = true
				_turn_rolled = true
				return
			if s.roll_remaining > 0.0:
				return
			_pull_without_stalling(s)
			if _going_left != _turn_started_left and _signed_climb_angle(s.flight_angle()) >= 0.0:
				mission = Mission.NOMISSION


func _land(s: PlaneState) -> void:
	if phase == 1:
		_input.pitch_up = true
		_input.pitch_down = true
		_input.thrust = false
		return
	if not s.wheels_down() and s.roll_remaining == 0.0:
		_input.roll = true
	var direction := 1.0 if home.heading_right else -1.0
	var threshold := home.start_x if home.heading_right else home.end_x
	var touchdown := Vector2(
		threshold + direction * TOUCHDOWN_OFFSET,
		home.surface_y + FlightModel.WHEEL_OFFSET + FlightModel.TYRE_OFFSET
	)
	var ahead := (touchdown.x - s.position.x) * direction
	if s.on_airfield:
		phase = 1
		return
	var far_end := home.end_x if home.heading_right else home.start_x
	if (far_end - s.position.x) * direction < -LANDING_OVERSHOOT:
		# Overshot: go around and come back for another approach.
		mission = Mission.TAKEOFF
		phase = 0
		_input.thrust = true
		return
	var height := s.position.y - touchdown.y
	var wanted := rad_to_deg(atan2(-height, maxf(ahead, 1.0)))
	wanted = clampf(wanted, -APPROACH_MAX_DESCENT, APPROACH_MAX_CLIMB)
	if height < APPROACH_FLARE_HEIGHT:
		wanted = maxf(wanted, -FlightModel.LANDING_PITCH_DOWN_MAX + 1.0)
	var error := wanted - _signed_climb_angle(s.flight_angle())
	var fraction := _top_fraction(s)
	_input.thrust = fraction < APPROACH_SLOW
	if error > APPROACH_STEER_TOLERANCE:
		_turn_screen_up(s)
	elif error < -APPROACH_STEER_TOLERANCE:
		_turn_screen_down(s)
	elif fraction > APPROACH_FAST:
		_input.pitch_up = true
		_input.pitch_down = true


## Switch to landing when wanting home and crossing the 1:3 approach slope to the home
## airfield in its landing direction.
func _consider_landing(s: PlaneState) -> void:
	if mission == Mission.LAND or mission == Mission.TAKEOFF:
		return
	if not _wants_home(s):
		return
	if _going_left == home.heading_right:
		return
	var ahead := home.centre_x() - s.position.x
	if _going_left:
		ahead = -ahead
	var height := s.position.y - home.surface_y
	if ahead < APPROACH_MIN or ahead > APPROACH_MAX:
		return
	if absf(height - ahead / 3.0) > APPROACH_SLOPE_TOLERANCE:
		return
	if (
		_top_fraction(s) < APPROACH_SPEED
		or height > APPROACH_HIGH
		or height > APPROACH_HEIGHT_PER_TOP * _top_fraction(s)
	):
		mission = Mission.LAND
		phase = 0


## Stopped on the home airfield: wait for the rearm (done by the world), then take off again.
func _rearm_and_relaunch(s: PlaneState) -> void:
	if not s.on_airfield or s.speed > 0.0 or home == null or not home.contains_x(s.position.x):
		return
	if Rearm.is_complete(s):
		mission = Mission.TAKEOFF
		phase = 0
		_input.thrust = true
		_input.pitch_up = false
		_input.pitch_down = false
	else:
		_input.thrust = false


## Original ai_do_bombing: whenever roughly level and carrying bombs, work out where a bomb
## released now would land, and release it if that is on an enemy Ground Target.
func _consider_bombing(s: PlaneState, dt: float) -> void:
	for name in _bombs_falling.keys():
		_bombs_falling[name] -= dt
		if _bombs_falling[name] <= 0.0:
			_bombs_falling.erase(name)
	if s.bombs <= 0 or s.bomb_cooldown > 0.0 or s.on_airfield or _going_up > BOMBING_MAX_CLIMB:
		return
	if s.flight_angle() > 180.0 and _signed_climb_angle(s.flight_angle()) < -BOMBING_MAX_DIVE:
		return
	var velocity := s.velocity()
	for target in _targets:
		if target.side == s.side or not target.is_alive() or _bombs_falling.has(target.name):
			continue
		# The Bomb leaves below the belly and stops at the top of the footprint.
		var height := s.position.y - AirCombat.BOMB_RELEASE_OFFSET - (target.base.y + target.height)
		if height <= 0.0:
			continue
		var g := model.tuning.gravity
		# h = -vy t + g t^2 / 2  ->  t from the quadratic, positive root.
		var fall_time := (velocity.y + sqrt(velocity.y * velocity.y + 2.0 * g * height)) / g
		var impact_x := s.position.x + velocity.x * fall_time
		if absf(impact_x - target.base.x) <= target.width / 2.0:
			_input.bomb = true
			_bombs_falling[target.name] = fall_time
			return


func _gunnery(s: PlaneState) -> void:
	if s.rounds <= 0 or s.gun_cooldown > 0.0:
		return
	for other in _others:
		if other.side == s.side and _distance(s, other) < FRIENDLY_RANGE:
			if _aim_error(s, other) < FRIENDLY_ANGLE:
				return
	for other in _others:
		if other.side != s.side and _distance(s, other) < SHOT_RANGE:
			if _aim_error(s, other) < SHOT_ANGLE:
				_input.fire = true
				return


func _near_border(s: PlaneState, margin: float) -> bool:
	if _going_left:
		return s.position.x < margin
	return s.position.x > map.bounds.width - margin


func _find(id: int) -> PlaneState:
	for other in _others:
		if other.id == id:
			return other
	return null


func _distance(s: PlaneState, other: PlaneState) -> float:
	return s.position.distance_to(_lead_point(other))


## Direction to the other plane's led position, degrees in [0, 360).
func _bearing(s: PlaneState, other: PlaneState) -> float:
	return wrapf(rad_to_deg((_lead_point(other) - s.position).angle()), 0.0, 360.0)


func _aim_error(s: PlaneState, other: PlaneState) -> float:
	return absf(wrapf(s.angle - _bearing(s, other), -180.0, 180.0))


static func _lead_point(other: PlaneState) -> Vector2:
	return other.position + other.velocity() * LEAD_TIME


## Degrees of nose above the horizon, 0 when level or diving. Original: going_up.
static func _climb_angle(angle: float) -> float:
	if angle <= 90.0:
		return angle
	if angle < 180.0:
		return 180.0 - angle
	return 0.0


## Degrees of nose above (positive) or below (negative) the horizon for either heading.
static func _signed_climb_angle(angle: float) -> float:
	if angle <= 90.0:
		return angle
	if angle <= 270.0:
		return 180.0 - angle
	return angle - 360.0


func _pull_only() -> void:
	_input.pitch_up = true
	_input.pitch_down = false


## Pull, but when slow keep the angle of attack just under the stall angle: a full pull
## below stall speed collapses the lift, a slightly smaller one keeps most of it.
func _pull_without_stalling(s: PlaneState) -> void:
	var stall_speed := model.tuning.stall_speed
	var near_limit := absf(s.angle_of_attack) >= model.tuning.stall_angle - STALL_EASE_ANGLE
	if s.speed < stall_speed * STALL_EASE_SPEED and near_limit:
		_input.pitch_up = false
		_input.pitch_down = false
	else:
		_pull_only()


func _push_only() -> void:
	_input.pitch_up = false
	_input.pitch_down = true


## Rotate the nose counter-clockwise (toward increasing angle). Original: ai_turnplus.
func _turn_ccw(s: PlaneState) -> void:
	if s.upside_down:
		_push_only()
	else:
		_pull_only()


## Rotate the nose clockwise. Original: ai_turnminus.
func _turn_cw(s: PlaneState) -> void:
	if s.upside_down:
		_pull_only()
	else:
		_push_only()


## Move the nose toward the top of the screen. Original: ai_turn_up.
func _turn_screen_up(s: PlaneState) -> void:
	if _going_left:
		_turn_cw(s)
	else:
		_turn_ccw(s)


## Move the nose toward the ground. Original: ai_turn_down.
func _turn_screen_down(s: PlaneState) -> void:
	if _going_left:
		_turn_ccw(s)
	else:
		_turn_cw(s)
