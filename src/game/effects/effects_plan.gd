class_name EffectsPlan
extends RefCounted
## The Picture's short-lived things, outside the simulation (ADR 0007): Muzzle Flashes,
## Casings, the puffs where bullets land, the sparks where they strike a Plane, the Bursts
## where things explode, with their smoke, and the smoke a damaged Plane trails. Pure: no
## nodes. Fed by World events through
## EffectsNode, advanced on the render clock, and capped, so a burst of fire reuses the oldest
## slot rather than growing.

## What a bullet raised where it landed: dust on the ground, a splash on Water, a tick on a
## Ground Target; the smoke a Burst leaves; the smoke a damaged Plane trails. Each kind has
## its colour, life, growth, shape and rise; a puff may carry its own colour over the kind's.
enum PuffKind { DUST, SPLASH, TICK, SMOKE, DAMAGE, SHELL_TRAIL }

## Seconds a Muzzle Flash shows: about four frames. 50 ms could not be seen, 80 ms was
## too much.
const FLASH_LIFE := 0.065
const MAX_FLASHES := 32
## Seconds a Casing tumbles before it is gone. It never lands.
const CASING_LIFE := 1.5
const MAX_CASINGS := 128
## The Dr.I has twin guns.
const CASINGS_PER_SHOT := 2
## Casings leave the breech, this far behind the muzzle along the barrel.
const BREECH_BEHIND_MUZZLE := 3.0
## Metres per second squared, on the Picture's clock; not the flight gravity.
const CASING_GRAVITY := 9.8
## Casings fly toward the camera (+Z), back along the barrel and up, this fast.
const CASING_TOWARD_CAMERA := Vector2(3.0, 5.0)
const CASING_BACKWARD := Vector2(2.0, 4.0)
const CASING_UPWARD := Vector2(1.0, 3.0)
## Tumble, radians per second either way.
const CASING_SPIN := 20.0
const MAX_PUFFS := 160
## Sparks where a bullet strikes a Plane: how many, how fast, how wide a fan back along the
## round's flight, and how long.
## 4 sparks of 0.3 m for 0.3 s went unnoticed next to the body's white flash.
const MAX_SPARKS := 96
const SPARKS_PER_HIT := 6
const SPARK_SPEED := Vector2(8.0, 16.0)
const SPARK_FAN := deg_to_rad(60.0)
const SPARK_LIFE := 0.5
const SPARK_GRAVITY := 9.8

const PUFF_LOOKS := {
	PuffKind.DUST:
	{
		"colour": Color(0.72, 0.64, 0.46),
		"life": 0.7,
		"scale": Vector2(0.25, 0.6),
		"aspect": Vector2(1.0, 0.8),
		"rise": 2.0,
	},
	PuffKind.SPLASH:
	{
		"colour": Color(0.88, 0.93, 1.0),
		"life": 0.5,
		"scale": Vector2(0.15, 0.35),
		"aspect": Vector2(0.5, 2.0),
		"rise": 4.0,
	},
	PuffKind.TICK:
	{
		"colour": Color(0.55, 0.55, 0.55),
		"life": 0.25,
		"scale": Vector2(0.15, 0.25),
		"aspect": Vector2(1.0, 1.0),
		"rise": 1.0,
	},
	PuffKind.SMOKE:
	{
		"colour": Color(0.42, 0.42, 0.45),
		"life": 2.0,
		"scale": Vector2(0.3, 0.9),
		"aspect": Vector2(1.0, 1.0),
		"rise": 3.0,
	},
	PuffKind.DAMAGE:
	{
		"colour": Color(0.5, 0.5, 0.5),
		"life": 1.5,
		"scale": Vector2(0.5, 1.2),
		"aspect": Vector2(1.0, 1.0),
		"rise": 1.5,
	},
	PuffKind.SHELL_TRAIL:
	{
		"colour": Color(0.8, 0.8, 0.82),
		"life": 0.7,
		"scale": Vector2(0.15, 0.35),
		"aspect": Vector2(1.0, 1.0),
		"rise": 0.5,
	},
}
## A Shell in flight leaves a puff behind it this often.
const SHELL_TRAIL_INTERVAL := 0.05
## Damage smoke: a Plane under this fraction of its hit points trails it, thicker, darker and
## more often toward zero, from its engine, carrying a little of the Plane's velocity.
const DAMAGE_SMOKE_FROM := 0.5
const DAMAGE_SMOKE_INTERVAL := Vector2(0.3, 0.06)
const DAMAGE_SMOKE_SIZE := Vector2(0.35, 0.7)
const DAMAGE_SMOKE_LIGHT := Color(0.55, 0.55, 0.55)
const DAMAGE_SMOKE_DARK := Color(0.12, 0.12, 0.12)
const DAMAGE_SMOKE_ENGINE := 2.5
const DAMAGE_SMOKE_CARRY := 0.15
## A Burst: the white flash's life, the sphere's life and growth, and its smoke. A Burst's
## radius is the sphere's full size; the smoke puffs scale with it (the Puff mesh is 4 m).
const MAX_BURSTS := 16
const BURST_FLASH_LIFE := 0.1
const BURST_FLASH_SCALE := Vector2(0.8, 1.3)
const BURST_LIFE := 0.5
const BURST_SCALE := Vector2(0.3, 1.0)
const BURST_SMOKE := Vector2i(6, 10)
const BURST_SMOKE_SPREAD := 0.4
const BURST_SMOKE_DRIFT := 1.5
const BURST_SMOKE_SIZE := Vector2(0.8, 1.2)
const BOMB_BURST_RADIUS := 6.0
const SHELL_BURST_RADIUS := 3.0
const SHELL_BURST_SMOKE := 3
const PLANE_BURST_RADIUS := 5.0
const BURST_COLOR := Color(1.0, 0.6, 0.2)
const SHELL_BURST_COLOR := Color(0.3, 0.3, 0.3)


## A Muzzle Flash at a gun. While its Plane lives it rides the muzzle, so it never lags the
## nose; a ground gun's stays where it was.
class MuzzleFlash:
	var position := Vector2.ZERO
	var direction := Vector2.RIGHT
	## Radians about the barrel, so no two look alike.
	var roll := 0.0
	var age := 0.0
	var follow: PlaneState

	func remaining() -> float:
		return clampf(1.0 - age / FLASH_LIFE, 0.0, 1.0)

	func where() -> Vector2:
		if follow != null:
			return follow.position + follow.nose() * AirCombat.MUZZLE_OFFSET
		return position

	func heading() -> Vector2:
		return follow.nose() if follow != null else direction


## A spent cartridge in flight. Picture only, so it may move in Z (ADR 0007).
class Casing:
	var position := Vector3.ZERO
	var velocity := Vector3.ZERO
	var angle := 0.0
	var spin := 0.0
	var age := 0.0

	func remaining() -> float:
		return clampf(1.0 - age / CASING_LIFE, 0.0, 1.0)


## A puff of something at an impact or a Burst: grows, rises, drifts and fades. Scale is in
## units of the Puff mesh, 4 m wide as built, times the puff's own size.
class Puff:
	var kind := PuffKind.DUST
	var origin := Vector2.ZERO
	var age := 0.0
	var size := 1.0
	var drift := Vector2.ZERO
	var colour := Color.WHITE

	static func of(puff_kind: PuffKind, at: Vector2) -> Puff:
		var puff := Puff.new()
		puff.kind = puff_kind
		puff.origin = at
		puff.colour = PUFF_LOOKS[puff_kind]["colour"]
		return puff

	func look() -> Dictionary:
		return PUFF_LOOKS[kind]

	func progress() -> float:
		return clampf(age / look()["life"], 0.0, 1.0)

	func remaining() -> float:
		return 1.0 - progress()

	func position() -> Vector2:
		return origin + (Vector2(0.0, look()["rise"]) + drift) * age

	func scale() -> float:
		var range: Vector2 = look()["scale"]
		return lerpf(range.x, range.y, progress()) * size


## Something exploding: a white flash for an instant, a sphere of the Burst's colour growing
## to its radius and fading. The smoke is Puffs; the Debris is the World's.
class Burst:
	var origin := Vector2.ZERO
	var radius := 4.0
	var colour := BURST_COLOR
	var with_flash := true
	var age := 0.0

	func progress() -> float:
		return clampf(age / BURST_LIFE, 0.0, 1.0)

	func remaining() -> float:
		return 1.0 - progress()

	func scale() -> float:
		return lerpf(BURST_SCALE.x, BURST_SCALE.y, progress()) * radius

	func flash_remaining() -> float:
		if not with_flash:
			return 0.0
		return clampf(1.0 - age / BURST_FLASH_LIFE, 0.0, 1.0)

	func flash_scale() -> float:
		return lerpf(BURST_FLASH_SCALE.x, BURST_FLASH_SCALE.y, 1.0 - flash_remaining()) * radius


## A spark thrown where a bullet struck a Plane: a hot fleck flying back off the hit.
class Spark:
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var age := 0.0

	func remaining() -> float:
		return clampf(1.0 - age / SPARK_LIFE, 0.0, 1.0)


var flashes: Array[MuzzleFlash] = []
var casings: Array[Casing] = []
var puffs: Array[Puff] = []
var sparks: Array[Spark] = []
var bursts: Array[Burst] = []

var _rng := RandomNumberGenerator.new()
## Per Plane id: seconds until its next damage smoke puff.
var _smoke_due: Dictionary = {}
## Seconds until every Shell in flight leaves its next puff.
var _shell_trail_due := 0.0


func _init(seed_value := 1) -> void:
	_rng.seed = seed_value


## A gun fired from `muzzle` along `direction`. A Plane's gun also throws Casings, from the
## breech, carrying the Plane's velocity.
func gun_fired(muzzle: Vector2, direction: Vector2, plane: PlaneState = null) -> void:
	var flash := MuzzleFlash.new()
	flash.position = muzzle
	flash.direction = direction
	flash.roll = _rng.randf_range(0.0, TAU)
	flash.follow = plane
	_push(flashes, flash, MAX_FLASHES)
	if plane == null:
		return
	var breech := muzzle - direction * BREECH_BEHIND_MUZZLE
	var carried := plane.velocity()
	for i in CASINGS_PER_SHOT:
		var casing := Casing.new()
		casing.position = Vector3(breech.x, breech.y, 0.0)
		var back := -direction * _range(CASING_BACKWARD)
		casing.velocity = Vector3(
			carried.x + back.x,
			carried.y + back.y + _range(CASING_UPWARD),
			_range(CASING_TOWARD_CAMERA)
		)
		casing.angle = _rng.randf_range(0.0, TAU)
		casing.spin = _rng.randf_range(-CASING_SPIN, CASING_SPIN)
		_push(casings, casing, MAX_CASINGS)


## A bullet landed on a surface: raise the puff that surface gives.
func bullet_landed(where: Vector2, surface: BulletHit.Surface) -> void:
	var kind := PuffKind.DUST
	match surface:
		BulletHit.Surface.WATER:
			kind = PuffKind.SPLASH
		BulletHit.Surface.TARGET:
			kind = PuffKind.TICK
	_push(puffs, Puff.of(kind, where), MAX_PUFFS)


## Something struck a Plane at `where`, flying along `direction`: sparks fly back off it.
func plane_struck(where: Vector2, direction: Vector2) -> void:
	var back := -direction.normalized() if not direction.is_zero_approx() else Vector2(0.0, 1.0)
	for i in SPARKS_PER_HIT:
		var spark := Spark.new()
		spark.position = where
		var angle := _rng.randf_range(-SPARK_FAN, SPARK_FAN)
		spark.velocity = back.rotated(angle) * _range(SPARK_SPEED)
		_push(sparks, spark, MAX_SPARKS)


## A Bomb went off.
func bomb_burst(at: Vector2) -> void:
	_burst(at, BOMB_BURST_RADIUS, BURST_COLOR, true, _rng.randi_range(BURST_SMOKE.x, BURST_SMOKE.y))


## A Shell burst: small, grey, no flash, a little smoke.
func shell_burst(at: Vector2) -> void:
	_burst(at, SHELL_BURST_RADIUS, SHELL_BURST_COLOR, false, SHELL_BURST_SMOKE)


## A Ground Target fell, sized to it.
func target_burst(at: Vector2, radius: float) -> void:
	_burst(at, radius, BURST_COLOR, true, _rng.randi_range(BURST_SMOKE.x, BURST_SMOKE.y))


## A Plane exploded.
func plane_burst(at: Vector2) -> void:
	_burst(
		at, PLANE_BURST_RADIUS, BURST_COLOR, true, _rng.randi_range(BURST_SMOKE.x, BURST_SMOKE.y)
	)


## A Plane went into the Water: one big splash, no fire.
func plane_splash(at: Vector2) -> void:
	var puff := Puff.of(PuffKind.SPLASH, at)
	puff.size = 4.0
	_push(puffs, puff, MAX_PUFFS)


## How hurt a Plane is for its smoke: nothing above DAMAGE_SMOKE_FROM of its hit points,
## 1 at zero.
static func damage_smoke_intensity(state: PlaneState) -> float:
	var fraction := float(state.hit_points) / maxf(1.0, state.max_hit_points())
	return clampf((DAMAGE_SMOKE_FROM - fraction) / DAMAGE_SMOKE_FROM, 0.0, 1.0)


## dt seconds passed for these Planes: the hurt ones trail smoke from their engines. Reads
## World state; called from the physics step, where the state is.
func trail_damage_smoke(states: Array[PlaneState], dt: float) -> void:
	for state in states:
		var intensity := damage_smoke_intensity(state)
		if not state.in_play() or intensity <= 0.0:
			_smoke_due.erase(state.id)
			continue
		var due: float = _smoke_due.get(state.id, 0.0) - dt
		if due > 0.0:
			_smoke_due[state.id] = due
			continue
		_smoke_due[state.id] = lerpf(DAMAGE_SMOKE_INTERVAL.x, DAMAGE_SMOKE_INTERVAL.y, intensity)
		var puff := Puff.of(PuffKind.DAMAGE, state.position + state.nose() * DAMAGE_SMOKE_ENGINE)
		puff.colour = DAMAGE_SMOKE_LIGHT.lerp(DAMAGE_SMOKE_DARK, intensity)
		puff.size = lerpf(DAMAGE_SMOKE_SIZE.x, DAMAGE_SMOKE_SIZE.y, intensity)
		puff.drift = state.velocity() * DAMAGE_SMOKE_CARRY
		_push(puffs, puff, MAX_PUFFS)


func _burst(at: Vector2, radius: float, colour: Color, with_flash: bool, smoke: int) -> void:
	var burst := Burst.new()
	burst.origin = at
	burst.radius = radius
	burst.colour = colour
	burst.with_flash = with_flash
	_push(bursts, burst, MAX_BURSTS)
	for i in smoke:
		var spread := radius * BURST_SMOKE_SPREAD
		var puff := Puff.of(
			PuffKind.SMOKE,
			at + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(0.0, spread))
		)
		puff.size = radius / 4.0 * _range(BURST_SMOKE_SIZE)
		puff.drift = Vector2(_rng.randf_range(-BURST_SMOKE_DRIFT, BURST_SMOKE_DRIFT), 0.0)
		_push(puffs, puff, MAX_PUFFS)


## dt seconds passed for these Shells: each leaves a trail of puffs behind it.
func trail_shells(shells: Array[Shell], dt: float) -> void:
	_shell_trail_due -= dt
	if _shell_trail_due > 0.0:
		return
	_shell_trail_due = SHELL_TRAIL_INTERVAL
	for shell in shells:
		_push(puffs, Puff.of(PuffKind.SHELL_TRAIL, shell.position), MAX_PUFFS)


## Move everything on by dt seconds and drop what has run its course.
func advance(dt: float) -> void:
	for flash in flashes:
		flash.age += dt
	flashes = flashes.filter(func(f: MuzzleFlash) -> bool: return f.age < FLASH_LIFE)
	for casing in casings:
		casing.age += dt
		casing.velocity.y -= CASING_GRAVITY * dt
		casing.position += casing.velocity * dt
		casing.angle += casing.spin * dt
	casings = casings.filter(func(c: Casing) -> bool: return c.age < CASING_LIFE)
	for puff in puffs:
		puff.age += dt
	puffs = puffs.filter(func(p: Puff) -> bool: return p.age < p.look()["life"])
	for spark in sparks:
		spark.age += dt
		spark.velocity.y -= SPARK_GRAVITY * dt
		spark.position += spark.velocity * dt
	sparks = sparks.filter(func(s: Spark) -> bool: return s.age < SPARK_LIFE)
	for burst in bursts:
		burst.age += dt
	bursts = bursts.filter(func(b: Burst) -> bool: return b.age < BURST_LIFE)


func _range(bounds: Vector2) -> float:
	return _rng.randf_range(bounds.x, bounds.y)


## Append, dropping the oldest when the pool is full.
static func _push(pool: Array, item: RefCounted, cap: int) -> void:
	if pool.size() >= cap:
		pool.pop_front()
	pool.append(item)
