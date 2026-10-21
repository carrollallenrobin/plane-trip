class_name Picture
extends RefCounted
## How the World's happenings are felt (ADR 0007): the one place that turns the WorldEvents
## and the stepped World into everything shown and heard beyond the objects themselves. It
## keeps the effects pools (EffectsPlan) and the camera shake, decides whose shots and hits
## shake the view, and how loud each sound is from the player's Plane, at what pitch and
## where. What only the scene can do, play a sound or flash a Plane's body, comes back as
## Cues. Pure: no nodes. WorldNode feeds it from step() and plays the Cues (the sounds on a
## SoundStage); EffectsNode draws the plan on the render clock and FollowCamera applies the
## shake. Nothing here flows back into the World.


## Something the scene plays for a happening.
class Cue:
	enum Kind {
		BLAST,
		COLLAPSE,
		SHELL,
		GUN,
		HIT_FLASH,
		## An Anti-Aircraft Gun's shot, and a Flak Gun's.
		GROUND_GUN,
		FLAK_FIRE,
		## A round striking a Plane: the player's own, or another's.
		HIT,
		## A round ending on the ground, the Water or a Ground Target (see surface).
		IMPACT,
		## A Bomb leaving its rack.
		RELEASE,
		## A Plane into the Water.
		SPLASH,
		## Wheels meeting the runway.
		TOUCHDOWN,
	}

	var kind: Kind
	## How loud, for the sounds, from the player's Plane.
	var volume_db := 0.0
	## Where, for the sounds, so the scene can place the voice.
	var position := Vector2.ZERO
	## A little off its built pitch, so a burst of six is six sounds.
	var pitch := 1.0
	## Whose gun fired, or whose body was hit, for GUN, HIT and HIT_FLASH.
	var plane: WorldPlane
	## For HIT: the player's own Plane was struck.
	var own := false
	## For IMPACT: what the round ended on.
	var surface := BulletHit.Surface.GROUND

	static func sound(
		cue_kind: Kind, db: float, where: Vector2, source: WorldPlane = null, at_pitch := 1.0
	) -> Cue:
		var cue := Cue.new()
		cue.kind = cue_kind
		cue.volume_db = db
		cue.position = where
		cue.plane = source
		cue.pitch = at_pitch
		return cue

	static func hit_flash(struck: WorldPlane) -> Cue:
		var cue := Cue.new()
		cue.kind = Kind.HIT_FLASH
		cue.plane = struck
		return cue


## A falling Bomb's whistle: where it is, how loud and at what pitch, this step.
class Whistle:
	var bomb: Bomb
	var position := Vector2.ZERO
	var volume_db := 0.0
	var pitch := 1.0


## Sounds fade to nothing over this distance from the player's Plane.
const HEARING_RANGE := 300.0
## A Bomb's whistle: quiet, and pitched up from its resting pitch as the Bomb gathers speed.
const WHISTLE_VOLUME_DB := -22.0
const WHISTLE_PITCH_AT_REST := 0.8
const WHISTLE_PITCH_PER_SPEED := 0.012
## A touchdown is a modest thump: it also sounds on every hop of a pull held before rotation
## speed, which the runway rule lets happen, so it must not be loud (-2 dB until 2026-10-19).
const TOUCHDOWN_VOLUME_DB := -10.0
## A Shell bursts quieter than a Bomb.
const SHELL_VOLUME_DB := -6.0
## An Anti-Aircraft Gun's shot is lighter than a Machine Gun's; a Flak Gun's is as loud.
const GROUND_GUN_VOLUME_DB := -4.0
## Another Plane being struck is quieter than one's own.
const HIT_VOLUME_DB := -4.0
## A round ending on something: quiet, there are many.
const IMPACT_VOLUME_DB := -10.0
const TARGET_IMPACT_VOLUME_DB := -6.0
const RELEASE_VOLUME_DB := -6.0
## Shots, hits and impacts are pitched this far either side of their built pitch.
const PITCH_JITTER := 0.06
## Quiet enough to be nothing; the floor of every volume.
const SILENT_DB := -80.0

var plan: EffectsPlan
var shake := CameraShake.new()
## The Bombs in the air after the last step, as heard.
var whistles: Array[Whistle] = []
## The player's Plane: everything is heard from it, and only its own shots and hits shake the
## view. Null in a World without a player; nothing is heard then.
var player: WorldPlane
## Where the sounds are heard from: the player's Plane while it is in the World, and where
## it last was while it is dead, so its own end and the fight going on over the wreck are
## heard, under the Band and the Debrief, until the next Plane appears.
var listener := Vector2.ZERO

## The pitch jitter's source, seeded so a run sounds the same twice.
var _rng := RandomNumberGenerator.new()
## Whether each Plane was on an Airfield after the last step, to hear a touchdown.
var _on_airfield: Dictionary = {}  # WorldPlane -> bool


func _init(seed_value := 1, player_plane: WorldPlane = null) -> void:
	plan = EffectsPlan.new(seed_value)
	player = player_plane
	_rng.seed = seed_value
	_follow_player()


## The World stepped by dt and these events happened: the shake decays, the hurt Planes and
## the Shells in flight leave their trails, the Bombs in the air whistle, a Plane back on
## an Airfield touches down, and each event is reacted to, in that order, so a fresh jolt is
## at full strength when the camera reads it. Returns what the scene must play.
func step(
	events: Array[WorldEvent],
	planes: Array[WorldPlane],
	shells: Array[Shell],
	dt: float,
	bombs: Array[Bomb] = []
) -> Array[Cue]:
	shake.advance(dt)
	_follow_player()
	var states: Array[PlaneState] = []
	for plane in planes:
		if plane.state != null:
			states.append(plane.state)
	plan.trail_damage_smoke(states, dt)
	plan.trail_shells(shells, dt)
	_hear_bombs(bombs)
	var cues: Array[Cue] = []
	_hear_touchdowns(cues, planes)
	for event in events:
		cues.append_array(react(event))
	return cues


## A Plane that was off the ground and is on an Airfield now has touched down. The first
## sight of a Plane sets its baseline, so spawning on the runway is silent.
func _hear_touchdowns(cues: Array[Cue], planes: Array[WorldPlane]) -> void:
	for plane in planes:
		var on := plane.is_alive() and plane.state.on_airfield
		if _on_airfield.has(plane) and on and not _on_airfield[plane]:
			_sound(cues, Cue.Kind.TOUCHDOWN, plane.state.position, TOUCHDOWN_VOLUME_DB, plane)
		_on_airfield[plane] = on


## Every Bomb in the air whistles from where it is, higher the faster it falls.
func _hear_bombs(bombs: Array[Bomb]) -> void:
	whistles.clear()
	if not hears():
		return
	for bomb in bombs:
		var whistle := Whistle.new()
		whistle.bomb = bomb
		whistle.position = bomb.position
		whistle.volume_db = WHISTLE_VOLUME_DB + volume_from(bomb.position)
		whistle.pitch = WHISTLE_PITCH_AT_REST + WHISTLE_PITCH_PER_SPEED * bomb.velocity.length()
		whistles.append(whistle)


## One happening: what it leaves in the plan, what it does to the view, and the Cues for the
## scene. Planes appearing and going, and the Mission ending, are not felt; WorldNode keeps
## its nodes by those itself.
func react(event: WorldEvent) -> Array[Cue]:
	var cues: Array[Cue] = []
	match event.kind:
		WorldEvent.Kind.GUN_FIRED:
			var state := event.plane.state if event.plane != null else null
			plan.gun_fired(event.position, event.direction, state)
			if event.plane != null:
				_sound(cues, Cue.Kind.GUN, event.position, 0.0, event.plane)
			elif event.target != null and event.target.kind == GroundTarget.Kind.FLAK_GUN:
				_sound(cues, Cue.Kind.FLAK_FIRE, event.position)
			elif event.target != null:
				_sound(cues, Cue.Kind.GROUND_GUN, event.position, GROUND_GUN_VOLUME_DB)
			if _is_player(event.plane):
				shake.add(CameraShake.GUN_TRAUMA)
				shake.recoil(event.direction)
		WorldEvent.Kind.BULLET_IMPACT:
			plan.bullet_landed(event.position, event.surface)
			var base := IMPACT_VOLUME_DB
			if event.surface == BulletHit.Surface.TARGET:
				base = TARGET_IMPACT_VOLUME_DB
			var impact := _sound(cues, Cue.Kind.IMPACT, event.position, base)
			if impact != null:
				impact.surface = event.surface
		WorldEvent.Kind.PLANE_HIT:
			plan.plane_struck(event.position, event.direction)
			cues.append(Cue.hit_flash(event.plane))
			var own := _is_player(event.plane)
			var hit := _sound(
				cues, Cue.Kind.HIT, event.position, 0.0 if own else HIT_VOLUME_DB, event.plane
			)
			if hit != null:
				hit.own = own
			if own:
				shake.hit(event.direction, event.plane.state.in_spin)
		WorldEvent.Kind.BOMB_RELEASED:
			_sound(cues, Cue.Kind.RELEASE, event.position, RELEASE_VOLUME_DB, event.plane)
		WorldEvent.Kind.BOMB_DETONATED:
			plan.bomb_burst(event.position)
			_blast(cues, Cue.Kind.BLAST, event.position)
		WorldEvent.Kind.SHELL_BURST:
			plan.shell_burst(event.position)
			_blast(cues, Cue.Kind.SHELL, event.position, SHELL_VOLUME_DB)
		WorldEvent.Kind.TARGET_DESTROYED:
			plan.target_burst(event.position, maxf(event.target.width, event.target.height))
			_blast(cues, Cue.Kind.COLLAPSE, event.position)
		WorldEvent.Kind.PLANE_DESTROYED:
			if event.crash == CrashRules.Outcome.WATER:
				plan.plane_splash(event.position)
				_blast(cues, Cue.Kind.SPLASH, event.position)
			else:
				plan.plane_burst(event.position)
				_blast(cues, Cue.Kind.BLAST, event.position)
	return cues


## True while there is a player to hear for: a Plane in the World, or the place its last one
## was lost.
func hears() -> bool:
	return player != null


## How loud something at `where` is from the listener; silent when nobody hears.
func volume_from(where: Vector2) -> float:
	if not hears():
		return SILENT_DB
	return volume_db_at(where.distance_to(listener))


## The listener rides with the player's Plane while it is in the World.
func _follow_player() -> void:
	if player != null and player.is_alive():
		listener = player.state.position


## Full volume at the listener, fading to silence over HEARING_RANGE.
static func volume_db_at(distance: float) -> float:
	var share := clampf(1.0 - distance / HEARING_RANGE, 0.0, 1.0)
	return maxf(SILENT_DB, linear_to_db(share)) if share > 0.0 else SILENT_DB


## A pitch a little off the built one, from the seeded source.
func jitter() -> float:
	return _rng.randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)


## A sound at `where`, heard by how far it is from the player's Plane; nothing when nobody
## hears. Returns the Cue, so a caller can say more about it.
func _sound(
	cues: Array[Cue], kind: Cue.Kind, where: Vector2, base_db := 0.0, source: WorldPlane = null
) -> Cue:
	if not hears():
		return null
	var cue := Cue.sound(kind, base_db + volume_from(where), where, source, jitter())
	cues.append(cue)
	return cue


## Something burst at `where`: heard by how far it was and felt as a shake by how near.
func _blast(cues: Array[Cue], kind: Cue.Kind, where: Vector2, base_db := 0.0) -> void:
	if not hears():
		return
	var distance := where.distance_to(listener)
	cues.append(Cue.sound(kind, base_db + volume_db_at(distance), where, null, jitter()))
	shake.blast_at(distance)


func _is_player(plane: WorldPlane) -> bool:
	return plane != null and plane == player
