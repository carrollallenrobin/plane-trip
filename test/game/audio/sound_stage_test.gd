extends GdUnitTestSuite
## The SoundStage's wiring: a pool of 3D voices on the World bus, each Cue kind mapped to its
## sound, and a Cue placed where it happened. Headless Godot plays nothing audible, but the
## players' state is kept.


func _stage() -> SoundStage:
	var stage := SoundStage.new()
	add_child(stage)
	return stage


func _cue(kind: Picture.Cue.Kind, where := Vector2(100.0, 50.0), db := -3.0) -> Picture.Cue:
	return Picture.Cue.sound(kind, db, where, null, 1.03)


func test_the_pool_is_sixteen_voices_on_the_world_bus_that_attenuate_nothing() -> void:
	var stage := _stage()
	var voices := stage.find_children("Voice*", "AudioStreamPlayer3D", false, false)
	assert_int(voices.size()).is_equal(SoundStage.VOICES)
	for voice in voices:
		assert_str(voice.bus).is_equal(UiSounds.WORLD_BUS)
		assert_int(voice.attenuation_model).is_equal(AudioStreamPlayer3D.ATTENUATION_DISABLED)
	stage.queue_free()


func test_every_sound_cue_has_a_stream_and_the_hit_and_impact_pick_by_their_facts() -> void:
	for kind in Picture.Cue.Kind.values():
		if kind == Picture.Cue.Kind.HIT_FLASH:
			assert_object(SoundStage.stream_for(_cue(kind))).is_null()
		else:
			assert_object(SoundStage.stream_for(_cue(kind))).is_not_null()
	var hit := _cue(Picture.Cue.Kind.HIT)
	assert_object(SoundStage.stream_for(hit)).is_same(SoundBank.HIT_PLANE)
	hit.own = true
	assert_object(SoundStage.stream_for(hit)).is_same(SoundBank.HIT_TAKEN)
	var impact := _cue(Picture.Cue.Kind.IMPACT)
	assert_object(SoundStage.stream_for(impact)).is_same(SoundBank.THUD)
	impact.surface = BulletHit.Surface.WATER
	assert_object(SoundStage.stream_for(impact)).is_same(SoundBank.PLINK)
	impact.surface = BulletHit.Surface.TARGET
	assert_object(SoundStage.stream_for(impact)).is_same(SoundBank.RICOCHET)


func test_a_cue_is_played_where_it_happened_at_its_volume_and_pitch() -> void:
	var stage := _stage()
	stage.play(_cue(Picture.Cue.Kind.BLAST, Vector2(120.0, 40.0), -4.0))
	var voice: AudioStreamPlayer3D = stage.get_node("Voice0")
	assert_object(voice.stream).is_same(SoundBank.BOMB_BLAST)
	assert_vector(voice.global_position).is_equal(Vector3(120.0, 40.0, 0.0))
	assert_float(voice.volume_db).is_equal(-4.0)
	assert_float(voice.pitch_scale).is_equal_approx(1.03, 0.001)
	# A silent Cue takes no voice; the next sound goes to the next voice in turn.
	stage.play(_cue(Picture.Cue.Kind.GUN, Vector2.ZERO, Picture.SILENT_DB))
	stage.play(_cue(Picture.Cue.Kind.GUN))
	assert_object(stage.get_node("Voice1").stream).is_same(SoundBank.MACHINE_GUN)
	assert_object(stage.get_node("Voice2").stream).is_null()
	stage.queue_free()


func _whistle(bomb: Bomb, where: Vector2, pitch: float) -> Picture.Whistle:
	var whistle := Picture.Whistle.new()
	whistle.bomb = bomb
	whistle.position = where
	whistle.volume_db = -10.0
	whistle.pitch = pitch
	return whistle


func test_a_whistle_voice_follows_each_bomb_and_is_freed_when_it_is_gone() -> void:
	var stage := _stage()
	var first := Bomb.new()
	var second := Bomb.new()
	var both: Array[Picture.Whistle] = [
		_whistle(first, Vector2(10.0, 50.0), 0.9), _whistle(second, Vector2(30.0, 40.0), 1.2)
	]
	stage.whistle(both)
	assert_int(stage.whistling()).is_equal(2)
	var voice: AudioStreamPlayer3D = stage.get_node("Whistle0")
	assert_bool(voice.playing).is_true()
	assert_vector(voice.global_position).is_equal(Vector3(10.0, 50.0, 0.0))
	assert_float(voice.pitch_scale).is_equal_approx(0.9, 0.001)
	assert_int(voice.stream.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	# The second Bomb falls on, moved and faster; the first is gone.
	var one: Array[Picture.Whistle] = [_whistle(second, Vector2(32.0, 30.0), 1.4)]
	stage.whistle(one)
	assert_int(stage.whistling()).is_equal(1)
	assert_bool(voice.playing).is_false()
	var other: AudioStreamPlayer3D = stage.get_node("Whistle1")
	assert_bool(other.playing).is_true()
	assert_vector(other.global_position).is_equal(Vector3(32.0, 30.0, 0.0))
	assert_float(other.pitch_scale).is_equal_approx(1.4, 0.001)
	var none: Array[Picture.Whistle] = []
	stage.whistle(none)
	assert_int(stage.whistling()).is_equal(0)
	stage.queue_free()


func test_the_loops_are_marked_to_loop_once() -> void:
	var engine := SoundBank.loop(SoundBank.ENGINE)
	assert_int(engine.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int(engine.loop_end).is_equal(44100)
	assert_object(SoundBank.loop(SoundBank.ENGINE)).is_same(engine)
