class_name PlaneState
extends RefCounted
## The complete simulation state of one Plane. Pure data, 2D only, metres, seconds, degrees.
## Angle convention: 0 = nose right, 90 = nose up, counter-clockwise positive, kept in [0, 360).

## Identifies the plane among all planes in a World; set by whoever creates it.
var id := 0
var side: int = Side.BLUE
## The airframe every Plane shares and what this one carries; together they set its
## capacities and its weight.
var airframe: Airframe
var loadout: Loadout

var position := Vector2.ZERO
var angle := 0.0
## Velocity vector, metres per second.
var vel := Vector2.ZERO
## Its length, kept up to date by the flight model. Never negative.
var speed := 0.0
## True when the plane has half-rolled: wheels point the other way and pitch is mirrored.
var upside_down := false
## Seconds left in the current half-roll; 0 when not rolling.
var roll_remaining := 0.0
## Seconds of dead controls left once the plane is back under the Ceiling. Held at the full
## duration while it is still above.
var ceiling_spin_remaining := 0.0
## Seconds the plane has been tumbling since it crossed the Ceiling; drives the tumble.
var ceiling_spin_elapsed := 0.0
## True once bullets or Debris have brought the plane to zero hit points: it falls with
## greatly reduced control until it hits something (see CONTEXT.md, Spin).
var in_spin := false
## True once the Plane is gone: it hit the ground, Water or a Border, or a Blast destroyed it.
## Set by whoever ends the Plane's life; nothing in the World touches a destroyed Plane again.
var destroyed := false
## Seconds until the Machine Gun can fire again.
var gun_cooldown := 0.0
## Seconds until the next Bomb can be released.
var bomb_cooldown := 0.0

var fuel := 0.0
var rounds := 0
var bombs := 0
var hit_points := 0

## Outputs of the last step, for rendering and rules.
var thrust_on := false
var stalled := false
var on_airfield := false
## Angle of attack in degrees and lift in multiples of gravity.
var angle_of_attack := 0.0
var g_load := 0.0


## A fresh Plane on this airframe with this Loadout, full to its capacities.
static func create(
	plane_airframe: Airframe, plane_loadout: Loadout, plane_side: int = Side.BLUE, plane_id := 0
) -> PlaneState:
	var state := PlaneState.new()
	state.airframe = plane_airframe
	state.loadout = plane_loadout
	state.side = plane_side
	state.id = plane_id
	state.fuel = state.max_fuel()
	state.rounds = state.max_rounds()
	state.bombs = state.max_bombs()
	state.hit_points = state.max_hit_points()
	return state


# --- Capacities, from the airframe's base and the Loadout's Fittings ---


func max_fuel() -> float:
	return loadout.fuel_seconds(airframe)


func max_rounds() -> int:
	return loadout.rounds(airframe)


func max_bombs() -> int:
	return loadout.bombs()


func max_hit_points() -> int:
	return loadout.hit_points(airframe)


## Current mass in the airframe's units: the empty plane, the Fittings, and the bombs still
## hanging. Only bombs lighten in flight; fuel, rounds and shredded Armour keep their weight
## (docs/design.md, Planes and Loadouts).
func mass() -> float:
	return airframe.empty_mass + loadout.fixed_mass() + bombs * airframe.bomb_mass


func heading_right() -> bool:
	return angle < 90.0 or angle > 270.0


## True when the wheels point toward the ground for the current heading.
func wheels_down() -> bool:
	return heading_right() != upside_down


## Unit vector along the nose.
func nose() -> Vector2:
	return Vector2.from_angle(deg_to_rad(angle))


## Nose pitch in the plane's own frame: positive when the nose points toward the canopy
## side (away from the wheels), in degrees, in (-180, 180].
func pitch_in_body_frame() -> float:
	var screen_pitch := angle if heading_right() else 180.0 - angle
	if not wheels_down():
		screen_pitch = -screen_pitch
	return wrapf(screen_pitch, -180.0, 180.0)


## World position of the wheels: below the fuselage on the wheels side.
func wheel_point() -> Vector2:
	var n := nose()
	var belly := Vector2(n.y, -n.x)  # 90 degrees clockwise from the nose
	if upside_down:
		belly = -belly
	return position + belly * FlightModel.WHEEL_OFFSET


## World position of the nose tip.
func nose_point() -> Vector2:
	return position + nose() * FlightModel.NOSE_OFFSET


## Velocity vector, metres per second.
func velocity() -> Vector2:
	return vel


## Set the velocity along the nose at this speed.
func set_speed_along_nose(new_speed: float) -> void:
	speed = new_speed
	vel = nose() * new_speed


## Direction of flight in degrees, [0, 360): the velocity's when moving, else the nose's.
func flight_angle() -> float:
	if speed > 1.0:
		return wrapf(rad_to_deg(vel.angle()), 0.0, 360.0)
	return angle


## True when the point lies inside the plane's hit box: a box along the fuselage,
## HIT_BOX_LENGTH by HIT_BOX_HEIGHT metres, like the original's 20 by 12 pixel sprite.
func contains_point(point: Vector2) -> bool:
	var local := (point - position).rotated(-deg_to_rad(angle))
	return (
		absf(local.x) <= FlightModel.HIT_BOX_LENGTH / 2.0
		and absf(local.y) <= FlightModel.HIT_BOX_HEIGHT / 2.0
	)


## True while the Plane is still in the World: flying, parked, or falling in a Spin. Bombs,
## Shells and Debris strike anything in play.
func in_play() -> bool:
	return not destroyed


## True while the Plane has hit points left: in play and not in a Spin. Guns aim at and
## bullets strike only Planes that can fight; small arms do nothing to a Spin, so bullets
## fly through it.
func can_fight() -> bool:
	return not destroyed and hit_points > 0
