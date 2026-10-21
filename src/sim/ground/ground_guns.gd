class_name GroundGuns
extends RefCounted
## The defenders: Anti-Aircraft Guns firing bursts of bullets with lead, and Flak Guns firing
## shells that burst on a fuse. A port of the original's do_kkbase and do_it_shots
## (docs/research/triplane-classic-mechanics.md, section 6). Pure: no nodes.

## Original: guns engage planes within 150 px horizontally.
const ENGAGE_RANGE := 150.0 * SimUnits.PIXEL
## Original: only when the target is between 45 and 135 degrees, i.e. roughly above.
const CONE_MIN := 45.0
const CONE_MAX := 135.0
## Original: a burst of 6 rounds on consecutive ticks, then a pause of 8 ticks.
const BURST_ROUNDS := 6
const BURST_INTERVAL := SimUnits.TICK
const BURST_PAUSE := 8.0 * SimUnits.TICK
## Original: AA_MG_SHOT_SPEED 4800 units.
const AA_MUZZLE_SPEED := 4800.0 * SimUnits.SPEED_UNIT
## Original: one flak shell every 15 + 6 ticks.
const FLAK_INTERVAL := 21.0 * SimUnits.TICK
## Original: ITGUN_SHOT_SPEED 8000 units, gravity 500 (in 64ths) per half-tick step.
const SHELL_SPEED := 8000.0 * SimUnits.SPEED_UNIT
const SHELL_GRAVITY := 500.0 / 64.0 * 2.0 * SimUnits.SPEED_UNIT / SimUnits.TICK
## Original: fuse of 32 to 41 ticks.
const FUSE_MIN := 32.0 * SimUnits.TICK
const FUSE_MAX := 42.0 * SimUnits.TICK
## Original: the barrel sits 13 px across and 10 px up from the gun's corner.
const BARREL_HEIGHT := 10.0 * SimUnits.PIXEL
## Original aim jitter for infantry; a little for the guns too so bursts spread.
const AIM_JITTER := 3.0

var shells: Array[Shell] = []
## The rounds and shells that left a barrel in the last step, for the picture.
var shots: Array[GunShot] = []

var _rng := RandomNumberGenerator.new()
## Per gun name: seconds until it may fire again, and rounds left in the current burst.
var _cooldown: Dictionary = {}
var _burst_left: Dictionary = {}


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


## Let every live gun look for a target and fire; move the shells. Returns the bursts; the
## shots are left in `shots`.
func step(
	dt: float,
	map: WorldMap,
	planes: Array[PlaneState],
	targets: Array[GroundTarget],
	combat: AirCombat
) -> Array[ShellBurst]:
	shots = []
	for target in targets:
		if target.is_alive() and target.is_gun():
			_run_gun(target, dt, planes, combat)
	return _step_shells(dt, map, planes)


func _run_gun(gun: GroundTarget, dt: float, planes: Array[PlaneState], combat: AirCombat) -> void:
	var cooldown: float = _cooldown.get(gun.name, 0.0) - dt
	_cooldown[gun.name] = cooldown
	if cooldown > 0.0:
		return
	var barrel := gun.base + Vector2(0.0, BARREL_HEIGHT)
	var speed := SHELL_SPEED if gun.kind == GroundTarget.Kind.FLAK_GUN else AA_MUZZLE_SPEED
	var aim := _aim(barrel, speed, gun.side, planes)
	if aim == Vector2.INF:
		_burst_left[gun.name] = 0
		return
	var direction := (
		Vector2
		. from_angle(deg_to_rad(_rng.randf_range(-AIM_JITTER, AIM_JITTER)))
		. rotated(aim.angle())
	)
	var shot := GunShot.new()
	shot.gun = gun
	shot.position = barrel
	shot.direction = direction
	shots.append(shot)
	if gun.kind == GroundTarget.Kind.FLAK_GUN:
		var shell := Shell.new()
		shell.position = barrel
		shell.velocity = direction * SHELL_SPEED
		shell.fuse = _rng.randf_range(FUSE_MIN, FUSE_MAX)
		shell.side = gun.side
		shells.append(shell)
		_cooldown[gun.name] = FLAK_INTERVAL
		return
	combat.fire_from_ground(barrel, direction * AA_MUZZLE_SPEED, gun.side)
	var left: int = _burst_left.get(gun.name, BURST_ROUNDS) - 1
	if left <= 0:
		_burst_left[gun.name] = BURST_ROUNDS
		_cooldown[gun.name] = BURST_PAUSE
	else:
		_burst_left[gun.name] = left
		_cooldown[gun.name] = BURST_INTERVAL


## Direction to the nearest enemy plane in range and in the cone, led by its velocity over
## the flight time of the round, or INF when there is nothing to shoot at.
func _aim(barrel: Vector2, round_speed: float, side: int, planes: Array[PlaneState]) -> Vector2:
	var best := Vector2.INF
	var best_distance := INF
	for plane in planes:
		if plane.side == side or not plane.can_fight():
			continue
		if absf(plane.position.x - barrel.x) > ENGAGE_RANGE:
			continue
		var distance := barrel.distance_to(plane.position)
		var led := plane.position + plane.velocity() * (distance / round_speed)
		var to_target := led - barrel
		var angle := wrapf(rad_to_deg(to_target.angle()), 0.0, 360.0)
		if angle < CONE_MIN or angle > CONE_MAX:
			continue
		if distance < best_distance:
			best_distance = distance
			best = to_target.normalized()
	return best


func _step_shells(dt: float, map: WorldMap, planes: Array[PlaneState]) -> Array[ShellBurst]:
	var bursts: Array[ShellBurst] = []
	var survivors: Array[Shell] = []
	for shell in shells:
		shell.advance(dt, SHELL_GRAVITY)
		shell.fuse -= dt
		if map.bounds.is_outside(shell.position.x) or map.terrain.is_below_surface(shell.position):
			continue
		var touched := false
		for plane in planes:
			if plane.in_play() and plane.contains_point(shell.position):
				touched = true
				break
		if touched or shell.fuse <= 0.0:
			var burst := ShellBurst.new()
			burst.position = shell.position
			burst.side = shell.side
			bursts.append(burst)
			continue
		survivors.append(shell)
	shells = survivors
	return bursts
