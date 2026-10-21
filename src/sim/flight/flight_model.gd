class_name FlightModel
extends RefCounted
## The flight model (ADR 0004; docs/design.md, Flight). Velocity is a vector; the nose is
## only where the plane points. Forces, as accelerations: propeller thrust along the nose
## (power over speed, capped at a static value), gravity, parasitic drag against the velocity
## (quadratic), induced drag from lift, and lift perpendicular to the velocity from the angle
## of attack between nose and velocity, linear to the stall angle then collapsing. A weak
## weathervane settles the nose on the trim attitude that gives one G, or on the velocity
## when stalled. The stick cannot hold more than the stall angle.
##
## Rules kept from the original Triplane Classic (docs/research/triplane-classic-mechanics.md):
## the half-roll, the landing cone, the ground roll with the tail settling, the stop speed,
## the Spin on death, the gun's rate of fire and the hit box. Their constants are annotated
## with the original expressions. Pure: no nodes, no randomness.

## Duration of a half-roll. Original: 3 ticks.
const ROLL_DURATION := 3.0 * SimUnits.TICK
## Below this speed a plane on an airfield with the engine off stops. Original: 16.
const STOP_SPEED := 16.0 * SimUnits.SPEED_UNIT
## Below this speed on an airfield the tail settles toward the rest pitch. Original: 512.
const GROUND_SETTLE_SPEED := 512.0 * SimUnits.SPEED_UNIT
## Tail-down rest pitch of a stopped plane. Original: 20 degrees.
const REST_PITCH := 20.0
## How fast the nose settles toward the rest pitch on the ground. Original: 1 degree per tick.
const GROUND_PITCH_RATE := 1.0 / SimUnits.TICK
## Landing cone in the body frame. Original: nose up <= 20, nose down <= 10 degrees.
const LANDING_PITCH_UP_MAX := 20.0
const LANDING_PITCH_DOWN_MAX := 10.0
## In a Spin (death) the stick still works at this fraction of the normal pitch rate, and
## the nose is pulled toward straight down at this rate, degrees per second.
const SPIN_PITCH_FACTOR := 0.3
const SPIN_NOSE_RATE := 48.0
## While locked beyond the Ceiling the nose turns toward the ground at this rate.
## Original stall rate: 4 degrees per tick.
const CEILING_NOSE_RATE := 4.0 / SimUnits.TICK
## Seconds of dead controls after the plane is back under the Ceiling.
const CEILING_SPIN_DURATION := 2.0
## Tumble of the Ceiling spin: half-rolls per second. The plane comes out inverted when it
## has tumbled through an odd number of them.
const CEILING_TUMBLE_RATE := 3.0
## Keeps the lock alive while waiting for the current half-roll to complete.
const CEILING_HOLD := 0.0001
## This far above the Ceiling the plane is fully off the screen; from there on its upward
## motion is cancelled so it does not linger out of sight. Nothing visible moves unnaturally.
const CEILING_OFFSCREEN_MARGIN := 5.0
## Seconds between Machine Gun shots. Original: one shot every 4 ticks (6 rounds per second).
const GUN_INTERVAL := 4.0 * SimUnits.TICK
## Hit box of a plane in the body frame. Original sprite: 20 by about 12 px.
const HIT_BOX_LENGTH := 20.0 * SimUnits.PIXEL
const HIT_BOX_HEIGHT := 12.0 * SimUnits.PIXEL
## Wheels sit this far below the fuselage. Original: 5 px.
const WHEEL_OFFSET := 5.0 * SimUnits.PIXEL
## The tyre hangs this far below the wheel collision point. Original: 1 px. A plane rolling
## on a runway therefore keeps its wheel point this high above the surface, which is why
## running off the end of a runway over level ground skims the ground instead of crashing.
const TYRE_OFFSET := 1.0 * SimUnits.PIXEL
## Float slack when testing whether the tyre touches the runway.
const CONTACT_EPSILON := 0.001
## Nose tip this far ahead of the centre. Original sprite: 20 px, so half of it.
const NOSE_OFFSET := 10.0 * SimUnits.PIXEL
## Below this speed there is no direction of flight to speak of.
const EPSILON_SPEED := 0.5
## No Loadout, however heavy, takes more than this much of the engine away.
const MIN_WEIGHT_FACTOR := 0.3

var tuning: FlightTuning


func _init(flight_tuning: FlightTuning = null) -> void:
	tuning = flight_tuning if flight_tuning != null else FlightTuning.new()


# --- Derived numbers ---


## Level top speed under full power with nothing in the Slots. The airframe's drag, lift,
## corner and rotation speeds derive from it, whatever the Plane carries.
func top_speed() -> float:
	return tuning.top_speed


## What is left of the engine under this Plane's weight: all of it empty, less as the
## Fittings and the hanging bombs add up (docs/design.md, Planes and Loadouts). Scales the
## top speed and the thrust, not the lift or the drag, so the turn rate stays.
func weight_factor(s: PlaneState) -> float:
	var load := (s.mass() - s.airframe.empty_mass) / s.airframe.empty_mass
	return clampf(1.0 - tuning.load_speed_penalty * load, MIN_WEIGHT_FACTOR, 1.0)


## This Plane's level top speed under full power, at its current weight.
func top_speed_of(s: PlaneState) -> float:
	return top_speed() * weight_factor(s)


## Speed at which the runway lets go of the wheels.
func rotation_speed() -> float:
	return tuning.rotation_speed_fraction * top_speed()


## Parasitic drag coefficient: at top speed drag equals thrust (P / V), and in a vertical
## full-throttle dive at the terminal speed drag equals thrust plus gravity. With P = c V^3:
## c (vt^2 - V^3 / vt) = g.
func drag_coefficient() -> float:
	var top := top_speed()
	var terminal := tuning.dive_terminal_factor * top
	return tuning.gravity / (terminal * terminal - top * top * top / terminal)


## Engine power per unit mass: thrust is power / speed, and at the Plane's own top speed it
## equals drag.
func power(s: PlaneState) -> float:
	var top := top_speed_of(s)
	return drag_coefficient() * top * top * top


func thrust(s: PlaneState, speed: float) -> float:
	var static_cap := tuning.static_acceleration * weight_factor(s)
	if speed < EPSILON_SPEED:
		return static_cap
	return minf(static_cap, power(s) / speed)


## Lift per radian of angle of attack per speed squared: maximum lift at the stall speed
## holds the plane level.
func lift_slope() -> float:
	var stall := tuning.stall_speed
	return tuning.gravity / (deg_to_rad(tuning.stall_angle) * stall * stall)


## The G limit: maximum lift at the corner speed. Above it lift is capped.
func lift_cap() -> float:
	var corner := tuning.corner_speed_fraction * top_speed()
	return lift_slope() * deg_to_rad(tuning.stall_angle) * corner * corner


## Best turn rate at a speed, degrees per second: maximum lift over speed.
func max_turn_rate(speed: float) -> float:
	if speed < EPSILON_SPEED:
		return 0.0
	var lift := minf(lift_slope() * deg_to_rad(tuning.stall_angle) * speed * speed, lift_cap())
	return rad_to_deg(lift / speed)


## Deceleration from parasitic drag alone at a speed, engine off and wings unloaded.
func coasting_drag(speed: float) -> float:
	return drag_coefficient() * speed * speed


# --- Stepping ---


## Advance the plane by dt seconds under the given controls and surroundings.
func step(s: PlaneState, input: FlightInput, env: FlightEnvironment, dt: float) -> void:
	s.thrust_on = input.thrust and s.fuel > 0.0 and not s.in_spin
	s.gun_cooldown = maxf(0.0, s.gun_cooldown - dt)
	s.bomb_cooldown = maxf(0.0, s.bomb_cooldown - dt)
	if not s.in_spin:
		_update_roll(s, input, dt)
	_update_ceiling(s, env, dt)
	var dead_controls := s.ceiling_spin_remaining > 0.0

	var speed := s.vel.length()
	var direction := s.vel / speed if speed > EPSILON_SPEED else s.nose()
	_update_nose(s, input, direction, speed, dead_controls, dt)

	# Angle of attack: signed angle from the velocity to the nose. The stick cannot hold more
	# than the stall angle, so a full pull is maximum lift; the wing stalls when that maximum
	# can no longer carry the plane, i.e. below the stall speed, and lift collapses.
	var aoa := rad_to_deg(direction.angle_to(s.nose()))
	s.angle_of_attack = aoa
	var stall_angle := tuning.stall_angle
	var at_limit := absf(aoa) >= stall_angle - 0.5
	var stall_speed := tuning.stall_speed
	s.stalled = at_limit and speed < stall_speed and not s.on_airfield and speed > EPSILON_SPEED
	var effective_aoa := minf(absf(aoa), stall_angle)
	if s.stalled:
		effective_aoa = stall_angle * tuning.stall_lift_fraction
	var lift := 0.0
	if not dead_controls and not s.on_airfield and speed > EPSILON_SPEED:
		lift = minf(lift_slope() * deg_to_rad(effective_aoa) * speed * speed, lift_cap())
	s.g_load = lift / tuning.gravity
	var lift_direction := direction.rotated(PI / 2.0 if aoa >= 0.0 else -PI / 2.0)

	var acceleration := Vector2.ZERO
	if s.thrust_on:
		var factor := _tail_down_factor(s) if s.on_airfield else 1.0
		acceleration += s.nose() * thrust(s, speed) * factor
		s.fuel = maxf(0.0, s.fuel - dt)
	var drag := coasting_drag(speed)
	if speed > EPSILON_SPEED:
		drag += tuning.induced_drag_factor * lift * lift / (speed * speed)
	if input.pitch_up and input.pitch_down and not s.in_spin:
		drag += tuning.air_brake_deceleration
	if speed > EPSILON_SPEED:
		acceleration -= direction * minf(drag, speed / dt)
	acceleration += lift_direction * lift
	if not s.on_airfield:
		acceleration.y -= tuning.gravity
	s.vel += acceleration * dt

	var held := s.on_airfield and env.has_runway() and not can_lift_off(s)
	if held:
		s.vel.y = 0.0
	if s.on_airfield:
		# Rolling friction acts at any speed, the wheel brakes while the throttle is closed,
		# and the plane stops below the stop speed.
		var deceleration := tuning.rolling_deceleration
		if not s.thrust_on:
			deceleration += tuning.wheel_brake_deceleration
		s.vel = s.vel.move_toward(Vector2.ZERO, deceleration * dt)
		_settle_tail(s, input, dt)
		if s.vel.length() < STOP_SPEED and not s.thrust_on:
			s.vel = Vector2.ZERO
	if s.position.y > env.ceiling_y + CEILING_OFFSCREEN_MARGIN:
		s.vel.y = minf(s.vel.y, 0.0)  # fully off the screen: no further climb
	s.position += s.vel * dt
	if held:
		s.position.y -= s.wheel_point().y - TYRE_OFFSET - env.runway_y
	s.speed = s.vel.length()

	s.on_airfield = is_on_runway(s, env)
	if s.on_airfield and not held:
		var gap := s.wheel_point().y - TYRE_OFFSET - env.runway_y
		if gap < 0.0:
			s.position.y -= gap
			s.vel.y = maxf(s.vel.y, 0.0)


## A plane on the runway leaves it at rotation speed with the nose above level.
func can_lift_off(s: PlaneState) -> bool:
	return s.speed >= rotation_speed() and s.pitch_in_body_frame() > 0.0


## The original landing rule: wheels touching a runway under the plane, wheels pointing
## down, and the nose within the landing cone. There is no speed check. A plane already on
## the ground is not bound by the nose-down side of the cone: it rolls on its tyres until
## its nose touches the runway, which the crash rules treat as a nose-over. A plane in a
## spin cannot land: the runway is ground to it, like anything else.
static func is_on_runway(s: PlaneState, env: FlightEnvironment) -> bool:
	if not env.has_runway() or not s.wheels_down() or s.in_spin:
		return false
	if s.wheel_point().y - TYRE_OFFSET > env.runway_y + CONTACT_EPSILON:
		return false
	var pitch := s.pitch_in_body_frame()
	if pitch > LANDING_PITCH_UP_MAX:
		return false
	return s.on_airfield or pitch >= -LANDING_PITCH_DOWN_MAX


## Degrees. Named to avoid Godot's built-in rotate_toward, which works in radians.
static func turn_angle_toward(angle: float, target: float, max_step: float) -> float:
	var delta := wrapf(target - angle, -180.0, 180.0)
	return wrapf(angle + clampf(delta, -max_step, max_step), 0.0, 360.0)


func _update_nose(
	s: PlaneState, input: FlightInput, direction: Vector2, speed: float, dead: bool, dt: float
) -> void:
	if dead:
		s.angle = turn_angle_toward(s.angle, 270.0, CEILING_NOSE_RATE * dt)
		return
	var rate := tuning.pitch_rate
	if s.in_spin:
		s.angle = turn_angle_toward(s.angle, 270.0, SPIN_NOSE_RATE * dt)
		rate *= SPIN_PITCH_FACTOR
	var flying := speed > EPSILON_SPEED and not s.on_airfield
	var flight := wrapf(rad_to_deg(direction.angle()), 0.0, 360.0)
	if flying:
		# Trimmed: hands off, the nose settles on the angle of attack that gives one G, so
		# the plane holds its path. Stalled, it settles on the velocity itself: nose down.
		var target := flight if s.stalled else flight + _trim_angle(direction, speed)
		var weathervane := tuning.weathervane_rate_stalled if s.stalled else tuning.weathervane_rate
		s.angle = turn_angle_toward(s.angle, target, weathervane * dt)
	if input.any_pitch():
		var sign := -1.0 if s.upside_down else 1.0
		s.angle = wrapf(s.angle + input.pitch() * sign * rate * dt, 0.0, 360.0)
	if flying and not s.in_spin:
		# The stick cannot push the angle of attack past the stall angle. Last, so a held
		# pull sits exactly on the limit.
		var aoa := wrapf(s.angle - flight, -180.0, 180.0)
		if absf(aoa) > tuning.stall_angle:
			s.angle = wrapf(flight + signf(aoa) * tuning.stall_angle, 0.0, 360.0)


## Signed angle of attack, degrees, that holds the current flight path at this speed: lift
## equal to the component of gravity across the path, toward the sky. Capped at the stall
## angle, zero when there is no speed to make lift with.
func _trim_angle(direction: Vector2, speed: float) -> float:
	var needed := tuning.gravity * absf(direction.x)  # gravity across the path
	var slope := lift_slope() * speed * speed
	if slope <= 0.0:
		return 0.0
	var aoa := minf(rad_to_deg(needed / slope), tuning.stall_angle)
	var sky_is_left_of_path := direction.rotated(PI / 2.0).y >= 0.0
	return aoa if sky_is_left_of_path else -aoa


## Acceleration left with the tail down: 1 when level, tail_down_acceleration at rest pitch.
func _tail_down_factor(s: PlaneState) -> float:
	var tail_down := clampf(s.pitch_in_body_frame() / REST_PITCH, 0.0, 1.0)
	return 1.0 - (1.0 - tuning.tail_down_acceleration) * tail_down


## Rolling along the runway: the tail settles toward the rest pitch when slow and hands off.
## Original: target = 20 degrees - speed * 10 / 256, approached 1 degree per tick.
static func _settle_tail(s: PlaneState, input: FlightInput, dt: float) -> void:
	if s.speed < GROUND_SETTLE_SPEED and not input.any_pitch():
		var rest := REST_PITCH * (1.0 - s.speed / GROUND_SETTLE_SPEED)
		var target := rest if s.heading_right() else 180.0 - rest
		s.angle = turn_angle_toward(s.angle, target, GROUND_PITCH_RATE * dt)


func _update_roll(s: PlaneState, input: FlightInput, dt: float) -> void:
	if s.roll_remaining > 0.0:
		s.roll_remaining -= dt
		if s.roll_remaining <= 0.0:
			s.roll_remaining = 0.0
			s.upside_down = not s.upside_down
	elif input.roll and not s.on_airfield:
		s.roll_remaining = ROLL_DURATION


## Beyond the Ceiling the controls lock and lift is cut, so gravity brings the plane back;
## the plane tumbles, and that continues for CEILING_SPIN_DURATION after it is back under.
## The tumble decides the roll state it comes out in, and the lock holds until the current
## half-roll completes so the body lands exactly on that state.
static func _update_ceiling(s: PlaneState, env: FlightEnvironment, dt: float) -> void:
	var above := s.position.y > env.ceiling_y
	if above:
		s.ceiling_spin_remaining = CEILING_SPIN_DURATION
	if s.ceiling_spin_remaining <= 0.0:
		return
	s.ceiling_spin_elapsed += dt
	if above:
		return
	s.ceiling_spin_remaining = maxf(0.0, s.ceiling_spin_remaining - dt)
	if s.ceiling_spin_remaining > 0.0:
		return
	var half_rolls_now := s.ceiling_spin_elapsed * CEILING_TUMBLE_RATE
	var half_rolls_before := (s.ceiling_spin_elapsed - dt) * CEILING_TUMBLE_RATE
	if floori(half_rolls_now) == floori(half_rolls_before):
		s.ceiling_spin_remaining = CEILING_HOLD
		return
	if floori(half_rolls_now) % 2 == 1:
		s.upside_down = not s.upside_down
	s.ceiling_spin_elapsed = 0.0
