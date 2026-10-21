class_name AirCombat
extends RefCounted
## Machine Gun fire, bombs, and the bullets and bombs in the air, re-expressed from the
## original (docs/research/triplane-classic-mechanics.md, section 4, and src/world/fobjects.cpp
## do_shots / start_shot / drop_bomb / do_bombs). Pure: no nodes.

## Muzzle speed added to the plane's own. Original: SHOTS_SPEED 4000 units.
const MUZZLE_SPEED := 4000.0 * SimUnits.SPEED_UNIT
## Gravity on bullets. Original: 400 per half-tick step in units 64 times the speed unit,
## i.e. 12.5 speed units per tick.
const BULLET_GRAVITY := 12.5 * SimUnits.SPEED_UNIT / SimUnits.TICK
## Bullets vanish after this long. Original: SHOTS_RANGE 55 half-tick steps, 1.15 s; ours is
## half again as long, for the longer reach asked for in play on 2026-10-18.
const BULLET_LIFETIME := 55.0 / 2.0 * SimUnits.TICK * 1.5
## Bullets start this far ahead of the plane centre. Original: 12 px.
const MUZZLE_OFFSET := 12.0 * SimUnits.PIXEL
## Bombs leave this far below the fuselage on the wheels side: where the Bomb hangs under
## the model, between the wheels. Original: 9 px (3.6 m), past the wheels; ours since
## 2026-10-18, so the falling Bomb starts where the hanging one was.
const BOMB_RELEASE_OFFSET := 1.4
## Seconds between Bombs while the key is held, so a stick is spaced. Ours: the original let
## one go every tick; 0.5 s felt slow in play on 2026-10-18.
const BOMB_INTERVAL := 0.1

var bullets: Array[Bullet] = []
var bombs: Array[Bomb] = []
## Gravity on bombs, metres per second squared; the world sets it from the flight tuning.
var gravity := 9.0


## Fire the plane's gun if it can: has rounds, cooled down, and the trigger is held.
## Returns the round that left the barrel, or null.
func try_fire(s: PlaneState, input: FlightInput) -> Bullet:
	if not input.fire or s.rounds <= 0 or s.gun_cooldown > 0.0:
		return null
	s.rounds -= 1
	s.gun_cooldown = FlightModel.GUN_INTERVAL
	var bullet := Bullet.new()
	bullet.position = s.position + s.nose() * MUZZLE_OFFSET
	bullet.velocity = s.nose() * (s.speed + MUZZLE_SPEED)
	bullet.owner_id = s.id
	bullet.side = s.side
	bullets.append(bullet)
	return bullet


## A ground gun fires a round from a point at a velocity.
func fire_from_ground(origin: Vector2, velocity: Vector2, side: int) -> void:
	var bullet := Bullet.new()
	bullet.position = origin
	bullet.velocity = velocity
	bullet.owner_id = -1
	bullet.side = side
	bullets.append(bullet)


## Drop a bomb if the plane has one, is in the air, the last one left BOMB_INTERVAL ago, and
## the pilot asks. Original: no bombs while on an airfield. Returns the Bomb released, or null.
func try_drop(s: PlaneState, input: FlightInput) -> Bomb:
	if not input.bomb or s.bombs <= 0 or s.on_airfield or s.bomb_cooldown > 0.0:
		return null
	s.bombs -= 1
	s.bomb_cooldown = BOMB_INTERVAL
	var bomb := Bomb.new()
	var n := s.nose()
	var belly := Vector2(n.y, -n.x)
	if s.upside_down:
		belly = -belly
	bomb.position = s.position + belly * BOMB_RELEASE_OFFSET
	bomb.velocity = s.velocity()
	bomb.owner_id = s.id
	bomb.side = s.side
	bombs.append(bomb)
	return bomb


## Move every bullet, drop the ones that left the world or expired, and report every one that
## ended on something: a plane, a Ground Target (any structure stops a round, as in the
## original; only guns are wounded), the ground or Water. Ended bullets are removed.
func step(
	dt: float, map: WorldMap, planes: Array[PlaneState], targets: Array[GroundTarget] = []
) -> Array[BulletHit]:
	var hits: Array[BulletHit] = []
	var survivors: Array[Bullet] = []
	for bullet in bullets:
		bullet.advance(dt, BULLET_GRAVITY)
		bullet.age += dt
		if bullet.age > BULLET_LIFETIME or map.bounds.is_outside(bullet.position.x):
			continue
		if map.terrain.is_below_surface(bullet.position):
			var ground_hit := _hit(bullet, BulletHit.Surface.GROUND)
			ground_hit.position.y = map.terrain.height_at(bullet.position.x)
			if map.terrain.is_water_at(bullet.position.x):
				ground_hit.surface = BulletHit.Surface.WATER
			hits.append(ground_hit)
			continue
		var plane := _struck_plane(bullet, planes)
		if plane != null:
			var hit := _hit(bullet, BulletHit.Surface.PLANE)
			hit.target = plane
			hits.append(hit)
			continue
		# A gun's own rounds start inside its footprint: ground fire ignores its own side.
		var ignore_side := bullet.side if bullet.owner_id < 0 else -1
		var ground := _struck_target(bullet.position, targets, ignore_side)
		if ground != null:
			var hit := _hit(bullet, BulletHit.Surface.TARGET)
			hit.ground_target = ground
			hits.append(hit)
			continue
		survivors.append(bullet)
	bullets = survivors
	return hits


static func _hit(bullet: Bullet, surface: BulletHit.Surface) -> BulletHit:
	var hit := BulletHit.new()
	hit.bullet = bullet
	hit.surface = surface
	hit.position = bullet.position
	return hit


## Move every bomb and report the ones that went off: on a plane (the plane is named), on a
## Ground Target (named), or on the ground.
func step_bombs(
	dt: float, map: WorldMap, planes: Array[PlaneState], targets: Array[GroundTarget]
) -> Array[BombImpact]:
	var impacts: Array[BombImpact] = []
	var survivors: Array[Bomb] = []
	for bomb in bombs:
		bomb.advance(dt, gravity)
		if map.bounds.is_outside(bomb.position.x):
			continue
		var impact := BombImpact.new()
		impact.bomb = bomb
		impact.position = bomb.position
		impact.plane = _struck_plane_by(bomb.position, bomb.owner_id, planes)
		if impact.plane == null:
			impact.ground_target = _struck_target(bomb.position, targets)
		if impact.plane != null or impact.ground_target != null:
			impacts.append(impact)
			continue
		if map.terrain.is_below_surface(bomb.position):
			impact.position.y = map.terrain.height_at(bomb.position.x)
			impacts.append(impact)
			continue
		survivors.append(bomb)
	bombs = survivors
	return impacts


## Bullets stop at any Plane in play, a Spin included: small arms do nothing to a spinning
## Plane (DamageRules), but the strike is still felt and seen. Until 2026-10-18 they flew
## through it.
static func _struck_plane(bullet: Bullet, planes: Array[PlaneState]) -> PlaneState:
	return _struck_plane_by(bullet.position, bullet.owner_id, planes)


## The Plane at the point, other than the owner, in play: a Spin included.
static func _struck_plane_by(
	point: Vector2, owner_id: int, planes: Array[PlaneState]
) -> PlaneState:
	for plane in planes:
		if plane.id == owner_id or not plane.in_play():
			continue
		if plane.contains_point(point):
			return plane
	return null


static func _struck_target(
	point: Vector2, targets: Array[GroundTarget], ignore_side := -1
) -> GroundTarget:
	for target in targets:
		if target.side == ignore_side:
			continue
		if target.is_alive() and target.contains(point):
			return target
	return null
