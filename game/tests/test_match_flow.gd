extends GdUnitTestSuite

## TASK-015.04: title/scores screens and GameplayScreen's pause/resume/
## end-match flow. Pause is exercised by calling GameplayScreen.pause()/
## resume()/end_match() directly rather than synthesizing key events --
## headless test runs can't deliver real InputEvents at all.


func _start_gameplay(player_count: int, ai_mask: int) -> GameplayScreen:
	var gameplay: GameplayScreen = auto_free(GameplayScreen.new())
	add_child(gameplay)
	var input_router: InputRouter = auto_free(InputRouter.new())
	add_child(input_router)
	gameplay.start(
		{
			"seed": 1,
			"flies_enabled": false,
			"level_bytes": Main.SAMPLE_LEVEL_TEXT.to_utf8_buffer(),
			"player_count": player_count,
			"ai_mask": ai_mask,
			"no_gore": false,
		},
		auto_free(SfxPlayer.new()),
		input_router,
	)
	return gameplay


func test_title_screen_start_button_emits_start_requested() -> void:
	var title: TitleScreen = auto_free(TitleScreen.new())
	add_child(title)
	await get_tree().process_frame

	var emitted := []
	title.start_requested.connect(func() -> void: emitted.append(true))
	var start_button: Button = title.get_node("Rows/StartButton")
	start_button.pressed.emit()

	assert_int(emitted.size()).is_equal(1)


func test_scores_screen_shows_only_enabled_slots_with_their_bumps() -> void:
	var scores: ScoresScreen = auto_free(ScoresScreen.new([3, 0, 7, 0], [true, false, true, false]))
	add_child(scores)
	await get_tree().process_frame

	var rows: Node = scores.get_node("Rows")
	var slot0_label: Label = rows.get_node("Slot0Label")
	var slot2_label: Label = rows.get_node("Slot2Label")
	assert_str(slot0_label.text).is_equal("DOTT: 3")
	assert_str(slot2_label.text).is_equal("FIZZ: 7")
	assert_bool(rows.has_node("Slot1Label")).is_false()
	assert_bool(rows.has_node("Slot3Label")).is_false()


func test_scores_screen_continue_button_emits_continue_requested() -> void:
	var scores: ScoresScreen = auto_free(ScoresScreen.new([0, 0, 0, 0], [false, false, false, false]))
	add_child(scores)
	await get_tree().process_frame

	var emitted := []
	scores.continue_requested.connect(func() -> void: emitted.append(true))
	var continue_button: Button = scores.get_node("Rows/ContinueButton")
	continue_button.pressed.emit()

	assert_int(emitted.size()).is_equal(1)


func test_gameplay_screen_builds_level_and_scoreboard() -> void:
	var gameplay := _start_gameplay(2, 0b10)
	assert_bool(gameplay.has_node("LevelLayers/Background")).is_true()
	assert_bool(gameplay.has_node("LevelLayers/SpriteRenderer")).is_true()
	assert_bool(gameplay.has_node("LevelLayers/Foreground")).is_true()
	assert_bool(gameplay.has_node("ScoreboardRenderer")).is_true()
	assert_bool(gameplay.is_paused()).is_false()


func test_pause_then_resume_restores_ticking() -> void:
	var gameplay := _start_gameplay(1, 0)
	gameplay.pause()
	assert_bool(gameplay.is_paused()).is_true()
	assert_bool(gameplay.has_node("PauseOverlay")).is_true()

	gameplay.resume()
	assert_bool(gameplay.is_paused()).is_false()
	assert_bool(gameplay.has_node("PauseOverlay")).is_false()
	await get_tree().process_frame


func test_pause_overlay_resume_button_calls_back_into_gameplay_screen() -> void:
	var gameplay := _start_gameplay(1, 0)
	gameplay.pause()
	var overlay: PauseOverlay = gameplay.get_node("PauseOverlay")
	var resume_button: Button = overlay.get_node("Rows/ResumeButton")
	resume_button.pressed.emit()
	assert_bool(gameplay.is_paused()).is_false()
	await get_tree().process_frame


func test_gameplay_screen_uses_a_custom_levels_art_and_layout_when_provided() -> void:
	var game_dir: String = ProjectSettings.globalize_path("res://").rstrip("/")
	var dat_path := game_dir.get_base_dir().path_join("data/jumpbump.dat")
	var custom_level: Dictionary = JumpnbumpAssetLoader.load_dat(dat_path)
	assert_int(custom_level["result"]).is_equal(LevelValidator.JNB_OK)

	var gameplay: GameplayScreen = auto_free(GameplayScreen.new())
	add_child(gameplay)
	var input_router: InputRouter = auto_free(InputRouter.new())
	add_child(input_router)
	gameplay.start(
		{
			"seed": 1,
			"flies_enabled": false,
			"player_count": 1,
			"ai_mask": 0,
			"no_gore": false,
			"custom_level": custom_level,
		},
		auto_free(SfxPlayer.new()),
		input_router,
	)

	var background: Sprite2D = gameplay.get_node("LevelLayers/Background")
	assert_object(background.texture).is_not_null()
	assert_vector(background.texture.get_size()).is_equal(Vector2(custom_level["level"]["background"].get_size()))


func test_end_match_emits_match_ended_with_only_enabled_slots_scored() -> void:
	var gameplay := _start_gameplay(2, 0)
	var emitted := []
	gameplay.match_ended.connect(func(bumps: Array, enabled: Array) -> void: emitted.append([bumps, enabled]))

	gameplay.end_match()

	assert_int(emitted.size()).is_equal(1)
	var enabled: Array = emitted[0][1]
	assert_bool(enabled[0]).is_true()
	assert_bool(enabled[1]).is_true()
	assert_bool(enabled[2]).is_false()
	assert_bool(enabled[3]).is_false()
