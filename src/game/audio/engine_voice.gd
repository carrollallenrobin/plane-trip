class_name EngineVoice
extends RefCounted
## What a Plane sounds like from its state: the engine's pitch and loudness, the air over
## the airframe and the wheels on the runway. The engine spools toward what the throttle
## asks rather than jumping, idles with the throttle closed, coughs on the last of the fuel,
## sputters in a Spin and stops when the Plane is gone; the airflow buffets in a stall and
## howls in a Spin. Pure: state and a time step in, pitches and volumes out, so the
## rules are tested without a node; PlaneNode applies them to its players.

## The engine loop is built at its resting pitch; these scale it.
const IDLE_PITCH := 0.62
const RUN_PITCH := 0.95
const TOP_PITCH := 1.45
## Seconds for the engine to close most of the gap to the pitch asked for.
const SPOOL_SECONDS := 0.45
const RUN_DB := -8.0
const IDLE_DB := -17.0
## In a Spin the engine cuts in and out this many times a second, this much quieter when out.
const SPUTTER_RATE := 6.0
const SPUTTER_DB := -16.0
const SPUTTER_ON_SHARE := 0.55
## With this much fuel left the engine coughs: a cut this long out of every COUGH_PERIOD.
const LOW_FUEL_SECONDS := 6.0
const COUGH_PERIOD := 0.9
const COUGH_SHARE := 0.14
## Stalled, the airflow buffets: at least this loud, shaking this many times a second.
const BUFFET_FLOOR_DB := -18.0
const BUFFET_RATE := 9.0
const BUFFET_DB := -7.0
## In a Spin the airflow howls this much louder.
const SPIN_HOWL_DB := 5.0
## Airflow: nothing at rest, loud at top speed, pitched up with it.
const AIRFLOW_QUIET_DB := -36.0
const AIRFLOW_LOUD_DB := -9.0
const AIRFLOW_LOW_PITCH := 0.7
const AIRFLOW_HIGH_PITCH := 1.5
## The wheels on the runway, from the speed they start to be heard to where they are loudest.
const ROLLING_START_SPEED := 0.5
const ROLLING_LOUD_SPEED := 30.0
const ROLLING_QUIET_DB := -30.0
const ROLLING_LOUD_DB := -11.0
const ROLLING_LOW_PITCH := 0.8
const ROLLING_HIGH_PITCH := 1.3
## Quiet enough to be nothing.
const SILENT_DB := -80.0

var engine_pitch := IDLE_PITCH
var engine_db := SILENT_DB
var airflow_pitch := AIRFLOW_LOW_PITCH
var airflow_db := SILENT_DB
var rolling_pitch := ROLLING_LOW_PITCH
var rolling_db := SILENT_DB
## Whether the engine loop should be playing at all.
var running := false

var _time := 0.0


## Advance by dt with the Plane in this state. `alive` is whether it is in the World at all;
## `top_speed` is the airframe's, so the airflow reads the same for every Loadout.
func update(state: PlaneState, alive: bool, top_speed: float, dt: float) -> void:
	_time += dt
	running = alive
	if not alive:
		engine_db = SILENT_DB
		airflow_db = SILENT_DB
		rolling_db = SILENT_DB
		return
	var share := clampf(state.speed / maxf(top_speed, 1.0), 0.0, 1.0)
	var wanted := IDLE_PITCH
	if state.thrust_on:
		wanted = lerpf(RUN_PITCH, TOP_PITCH, share)
	engine_pitch += (wanted - engine_pitch) * (1.0 - exp(-dt / SPOOL_SECONDS))
	engine_db = RUN_DB if state.thrust_on else IDLE_DB
	if state.in_spin and fmod(_time * SPUTTER_RATE, 1.0) > SPUTTER_ON_SHARE:
		engine_db += SPUTTER_DB
	elif state.thrust_on and state.fuel < LOW_FUEL_SECONDS and coughing(_time):
		engine_db += SPUTTER_DB
	airflow_pitch = lerpf(AIRFLOW_LOW_PITCH, AIRFLOW_HIGH_PITCH, share)
	airflow_db = lerpf(AIRFLOW_QUIET_DB, AIRFLOW_LOUD_DB, pow(share, 1.5))
	if state.stalled and not state.on_airfield:
		airflow_db = maxf(airflow_db, BUFFET_FLOOR_DB)
		if fmod(_time * BUFFET_RATE, 1.0) > 0.5:
			airflow_db += BUFFET_DB
	if state.in_spin:
		airflow_db += SPIN_HOWL_DB
	if state.on_airfield and state.speed > ROLLING_START_SPEED:
		var roll := clampf(state.speed / ROLLING_LOUD_SPEED, 0.0, 1.0)
		rolling_pitch = lerpf(ROLLING_LOW_PITCH, ROLLING_HIGH_PITCH, roll)
		rolling_db = lerpf(ROLLING_QUIET_DB, ROLLING_LOUD_DB, roll)
	else:
		rolling_db = SILENT_DB


## Whether the engine is in a cough at this moment of the low-fuel cycle.
static func coughing(time: float) -> bool:
	return fmod(time, COUGH_PERIOD) < COUGH_PERIOD * COUGH_SHARE
