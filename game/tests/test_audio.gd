extends SceneTree

## Manual headless smoke test for the audio wiring (TASK-014.06), runnable
## via: godot --headless --path game --script res://tests/test_audio.gd
## Stopgap until TASK-014.07 bootstraps gdUnit4, matching
## tests/test_level_layers.gd's convention. Exits 0 on success, 1 on the
## first failed assertion (printed to stderr).

var _failures := 0
var _sfx_player: SfxPlayer
var _music_player: MusicPlayer


func _initialize() -> void:
	_test_jump_and_splash_are_unambiguous()
	_test_id_2_without_a_death_is_spring()
	_test_id_2_followed_by_player_death_is_death()
	_test_six_ticks_of_the_same_cue_in_one_frame_coalesce_to_one()
	_test_a_spring_tick_followed_by_a_death_tick_classifies_each_correctly()
	_test_fly_volume_events_in_returns_only_the_fly_channel()
	_test_music_player_track_map_matches_committed_assets()
	_test_audio_settings_round_trips_through_a_temp_dir()
	_test_audio_settings_fills_in_missing_buses_with_defaults()
	_test_app_lifecycle_calls_on_quit_and_sets_quit_requested()
	_test_project_uses_the_committed_bus_layout()

	# AudioStreamPlayer.play() requires the node to actually be inside the
	# live tree (Node._ready() itself is deferred to the next idle frame,
	# same as test_level_layers.gd's _main_instance) -- add it now, run the
	# one test that calls play() once _ready() has actually fired.
	_sfx_player = SfxPlayer.new()
	get_root().add_child(_sfx_player)
	_music_player = MusicPlayer.new()
	get_root().add_child(_music_player)
	process_frame.connect(_run_deferred_checks_once, CONNECT_ONE_SHOT)


func _run_deferred_checks_once() -> void:
	_test_sfx_player_loads_every_cue_including_fly()
	_test_music_player_play_custom_plays_a_runtime_stream()

	if _failures > 0:
		push_error("%d test_audio assertion(s) failed" % _failures)
		quit(1)
	else:
		print("test_audio: OK")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: %s" % message)


func _sfx_event(id: int) -> Dictionary:
	return {"kind": 1, "a": id, "b": 0, "c": 0, "d": 0}  # SimWorld.EVENT_SFX


func _death_event() -> Dictionary:
	return {"kind": 3, "a": 0, "b": -1, "c": 0, "d": 0}  # SimWorld.EVENT_PLAYER_DEATH


func _volume_event(volume: int) -> Dictionary:
	return {"kind": 6, "a": 4, "b": volume, "c": 0, "d": 0}  # SimWorld.EVENT_SFX_VOLUME, channel 4


## AC#1: jump (id 1) and splash (id 3) never need disambiguation.
func _test_jump_and_splash_are_unambiguous() -> void:
	var cues := SfxEventCoalescer.cues_for([_sfx_event(1)])
	_assert(cues == ["jump"], "id 1 should resolve to jump, got %s" % [cues])
	cues = SfxEventCoalescer.cues_for([_sfx_event(3)])
	_assert(cues == ["splash"], "id 3 should resolve to splash, got %s" % [cues])


## core/steer.zig's sfx_spring shares id 2 with core/collision.zig's
## sfx_death; with no player_death event following, it's a spring.
func _test_id_2_without_a_death_is_spring() -> void:
	var cues := SfxEventCoalescer.cues_for([_sfx_event(2)])
	_assert(cues == ["spring"], "id 2 with no death should resolve to spring, got %s" % [cues])


## core/game_loop.zig's step() pushes a tick's sfx events before that same
## tick's player_death event -- a player_death right after an id-2 sfx
## event means it's the death cue, not a spring.
func _test_id_2_followed_by_player_death_is_death() -> void:
	var cues := SfxEventCoalescer.cues_for([_sfx_event(2), _death_event()])
	_assert(cues == ["death"], "id 2 followed by a death event should resolve to death, got %s" % [cues])


## AC#3: a frame that advances multiple ticks after a hitch must play at
## most one cue per event kind, not one per tick.
func _test_six_ticks_of_the_same_cue_in_one_frame_coalesce_to_one() -> void:
	var events := []
	for i in range(6):
		events.append(_sfx_event(1))
	var cues := SfxEventCoalescer.cues_for(events)
	_assert(cues == ["jump"], "six jump ticks in one frame should coalesce to one jump cue, got %s" % [cues])


## Two ticks in one drain: first a spring (no death that tick), then a
## death (id 2 immediately followed by its own player_death) -- both must
## resolve correctly, not just whichever the algorithm sees first.
func _test_a_spring_tick_followed_by_a_death_tick_classifies_each_correctly() -> void:
	var events := [_sfx_event(2), _sfx_event(2), _death_event()]
	var cues := SfxEventCoalescer.cues_for(events)
	cues.sort()
	_assert(cues == ["death", "spring"], "expected both spring and death, got %s" % [cues])


func _test_fly_volume_events_in_returns_only_the_fly_channel() -> void:
	var events := [_sfx_event(1), _volume_event(32), _sfx_event(3), _volume_event(48)]
	var fly_events := SfxEventCoalescer.fly_volume_events_in(events)
	_assert(fly_events.size() == 2, "expected 2 fly-channel volume events, got %d" % fly_events.size())
	_assert(fly_events[-1]["volume"] == 48, "expected the last fly volume to be 48, got %s" % fly_events[-1])


func _test_sfx_player_loads_every_cue_including_fly() -> void:
	var player := _sfx_player
	for cue in SfxPlayer.ONE_SHOT_CUES:
		_assert(ResourceLoader.exists("%s%s.wav" % [SfxPlayer.SFX_DIR, cue]), "missing committed asset for cue %s" % cue)
	_assert(ResourceLoader.exists("%s%s.wav" % [SfxPlayer.SFX_DIR, SfxPlayer.FLY_CUE]), "missing committed fly.wav asset")
	# apply_fly_volume(0) must stop rather than play at silence.
	player.apply_fly_volume(32)
	_assert(player._fly_player.playing, "apply_fly_volume(32) should start the fly loop")
	player.apply_fly_volume(0)
	_assert(not player._fly_player.playing, "apply_fly_volume(0) should stop the fly loop")


func _test_music_player_track_map_matches_committed_assets() -> void:
	for track: String in MusicPlayer.TRACKS:
		var path: String = MusicPlayer.TRACKS[track]
		_assert(ResourceLoader.exists(path), "MusicPlayer track %s points at missing asset %s" % [track, path])


## TASK-016.03: play_custom() plays a runtime-rendered stream (a custom
## level's own decoded .mod, via JumpnbumpAssetLoader.render_mod()) directly,
## bypassing the TRACKS name lookup, and a later play(track) call for a
## still-tracked name isn't mistaken for a no-op just because something is
## already playing.
func _test_music_player_play_custom_plays_a_runtime_stream() -> void:
	var player := _music_player
	# A tiny silent stream stands in for a real render_mod() result here --
	# this test is about play_custom()'s wiring (which stream plays, that
	# _current_track resets), not about mod_player.zig's decode correctness
	# (covered by test_asset_loader.gd's real-bump.mod render_mod test).
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = true
	stream.mix_rate = 44100
	stream.data = PackedByteArray([0, 0, 0, 0])

	player.play_custom(stream)
	_assert(player.is_playing(), "play_custom() should start playback")
	_assert(player._player.stream == stream, "play_custom() should set the player's stream to the given one")

	# play("game") must not no-op just because something (the custom stream)
	# happens to already be playing -- _current_track was cleared.
	player.play("game")
	_assert(player._player.stream != stream, "play(\"game\") after play_custom() should switch away from the custom stream")


func _test_audio_settings_round_trips_through_a_temp_dir() -> void:
	var dir := "user://test_audio_settings_%d" % Time.get_ticks_usec()
	var settings := AudioSettings.new(dir)
	var written := {"Master": -3.0, "Music": -6.0, "SFX": 0.0, "UI": -12.0}
	var err := settings.save(written)
	_assert(err == OK, "save() should succeed, got error %d" % err)
	var loaded := settings.load_or_default()
	_assert(loaded == written, "loaded volume-db map should match what was saved, got %s" % loaded)
	DirAccess.remove_absolute(dir.path_join(AudioSettings.FILE_NAME))
	DirAccess.remove_absolute(dir)


func _test_audio_settings_fills_in_missing_buses_with_defaults() -> void:
	var dir := "user://test_audio_settings_partial_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	var settings := AudioSettings.new(dir)
	var file := FileAccess.open(dir.path_join(AudioSettings.FILE_NAME), FileAccess.WRITE)
	file.store_string(JSON.stringify({"Master": -5.0}))
	file.close()
	var loaded := settings.load_or_default()
	_assert(loaded["Master"] == -5.0, "explicit Master value should survive, got %s" % loaded["Master"])
	_assert(loaded["Music"] == 0.0, "missing Music bus should default to 0.0 dB, got %s" % loaded["Music"])
	DirAccess.remove_absolute(dir.path_join(AudioSettings.FILE_NAME))
	DirAccess.remove_absolute(dir)


## AC#4: quitting the app stops music before the app actually quits. Called
## directly rather than through a real WM close (headless has no window
## manager to send one) -- the same convention neo_snake's
## test_app_lifecycle.gd uses for AppLifecycle's other notifications.
func _test_app_lifecycle_calls_on_quit_and_sets_quit_requested() -> void:
	# A one-element Array, not a bare bool: GDScript lambdas capture outer
	# locals by value, so a captured bool mutated inside the closure would
	# never be visible here -- an Array is a reference type instead.
	var called := [false]
	var lifecycle := AppLifecycle.new(func() -> void: called[0] = true)
	lifecycle._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_assert(called[0], "on_quit callback should have been invoked")
	_assert(lifecycle.quit_requested, "quit_requested should be true after NOTIFICATION_WM_CLOSE_REQUEST")


func _test_project_uses_the_committed_bus_layout() -> void:
	var path: String = ProjectSettings.get_setting("audio/buses/default_bus_layout")
	_assert(path == "res://default_bus_layout.tres", "expected the committed bus layout, got %s" % path)
	for bus_name in ["Master", "Music", "SFX", "UI"]:
		_assert(AudioServer.get_bus_index(bus_name) != -1, "missing audio bus %s" % bus_name)
