class_name FlightTuning
extends Resource
## The numbers behind the flight model (docs/design.md, Flight; ADR 0004). Feel targets in,
## coefficients derived; see FlightModel for the derivations. The game loads
## data/flight_tuning.tres; tests build their own.

## Level top speed under full power, metres per second, with nothing in the Slots.
@export var top_speed := 72.0
## A full-throttle vertical dive tops out at this multiple of top speed. Sets the drag.
@export_range(1.05, 3.0, 0.05) var dive_terminal_factor := 1.5
## Static thrust cap: acceleration at a standstill. Propeller thrust is power over speed,
## capped here at low speed.
@export var static_acceleration := 40.0
## Gravity, metres per second squared. Playtest window 7 to 10.
@export_range(5.0, 12.0, 0.1) var gravity := 9.0
## Slowest speed at which maximum lift holds the plane level. Sets the lift slope, and with
## it the turn rate at every speed below the corner.
@export var stall_speed := 18.0
## Above this fraction of top speed lift is capped (the G limit), so the turn radius grows.
@export_range(0.2, 1.0, 0.05) var corner_speed_fraction := 0.7
## Angle of attack, degrees, beyond which the wing stalls.
@export var stall_angle := 18.0
## Fraction of maximum lift left when stalled.
@export_range(0.0, 1.0, 0.05) var stall_lift_fraction := 0.4
## Induced drag per lift squared over speed squared: how much hard pulls bleed speed.
@export var induced_drag_factor := 8.0
## Nose rotation rate under the stick, degrees per second.
@export var pitch_rate := 122.0
## Weathervane: the nose settles toward the trim attitude at this rate, degrees per second,
## and toward the velocity itself at the stalled rate.
@export var weathervane_rate := 10.0
@export var weathervane_rate_stalled := 60.0
## Weight: top speed and thrust scale by one minus this times the Loadout's weight over the
## empty mass, so a mixed full load is about 10 percent slower and six Armour Plates about
## 25 percent (docs/design.md, Planes and Loadouts). Lift and drag are untouched, so the turn
## rate stays.
@export_range(0.0, 1.0, 0.01) var load_speed_penalty := 0.2
## Deceleration while holding up and down together.
@export var air_brake_deceleration := 12.0
## Below this fraction of top speed the runway keeps hold of the wheels.
@export_range(0.05, 1.0, 0.05) var rotation_speed_fraction := 0.4
## Fraction of level acceleration left with the tail fully down on the runway.
@export_range(0.0, 1.0, 0.05) var tail_down_acceleration := 0.4
## Rolling friction on the runway, metres per second squared.
@export var rolling_deceleration := 2.0
## Deceleration the wheel brakes add on the runway while the throttle is closed, so a landed
## plane stops on the airfield. Asked for in play on 2026-10-18.
@export var wheel_brake_deceleration := 6.0
