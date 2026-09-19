extends GdUnitTestSuite

## TASK-015.03: GameSettings persistence and the settings UI's toggle/stepper.


func _temp_dir(prefix: String) -> String:
	return "user://%s_%d" % [prefix, Time.get_ticks_usec()]


func _cleanup(dir: String) -> void:
	DirAccess.remove_absolute(dir.path_join(GameSettings.FILE_NAME))
	DirAccess.remove_absolute(dir)


func test_load_or_default_returns_defaults_when_no_file_exists() -> void:
	var store := GameSettings.new(_temp_dir("gs_missing"))
	assert_dict(store.load_or_default()).is_equal(GameSettings.DEFAULTS)


func test_settings_round_trip_through_a_temp_dir() -> void:
	var dir := _temp_dir("gs_roundtrip")
	var store := GameSettings.new(dir)
	var written := {
		"sound_enabled": false,
		"music_enabled": true,
		"gore_enabled": false,
		"flies_enabled": false,
		"mirror_enabled": true,
		"player_count": 2,
	}
	var err := store.save(written)
	assert_int(err).is_equal(OK)
	assert_dict(store.load_or_default()).is_equal(written)
	_cleanup(dir)


func test_player_count_is_clamped_to_valid_range() -> void:
	var dir := _temp_dir("gs_clamp")
	DirAccess.make_dir_recursive_absolute(dir)
	var store := GameSettings.new(dir)
	var file := FileAccess.open(dir.path_join(GameSettings.FILE_NAME), FileAccess.WRITE)
	file.store_string(JSON.stringify({"player_count": 99}))
	file.close()
	assert_int(store.load_or_default()["player_count"]).is_equal(GameSettings.MAX_PLAYER_COUNT)
	_cleanup(dir)


func test_no_gore_is_the_inverse_of_gore_enabled() -> void:
	assert_bool(GameSettings.no_gore({"gore_enabled": true})).is_false()
	assert_bool(GameSettings.no_gore({"gore_enabled": false})).is_true()


func test_mirror_transform_is_identity_when_disabled() -> void:
	assert_that(GameSettings.mirror_transform(false, 400)).is_equal(Transform2D.IDENTITY)


func test_mirror_transform_flips_and_offsets_by_design_width() -> void:
	var transform := GameSettings.mirror_transform(true, 400)
	assert_that(transform * Vector2(0, 10)).is_equal(Vector2(400, 10))
	assert_that(transform * Vector2(400, 10)).is_equal(Vector2(0, 10))


func test_settings_screen_toggle_flips_text_and_persists() -> void:
	var dir := _temp_dir("gs_screen_toggle")
	var screen: SettingsScreen = auto_free(SettingsScreen.new(dir))
	add_child(screen)
	await get_tree().process_frame

	var row: Node = screen.get_node("Rows/sound_enabled")
	var button: Button = row.get_node("ToggleButton")
	assert_str(button.text).is_equal("ON")

	button.pressed.emit()
	assert_str(button.text).is_equal("OFF")

	var reloaded := GameSettings.new(dir).load_or_default()
	assert_bool(reloaded["sound_enabled"]).is_false()
	_cleanup(dir)


func test_settings_screen_player_count_stepper_clamps_and_persists() -> void:
	var dir := _temp_dir("gs_screen_count")
	var screen: SettingsScreen = auto_free(SettingsScreen.new(dir))
	add_child(screen)
	await get_tree().process_frame

	var row: Node = screen.get_node("Rows/player_count")
	var inc: Button = row.get_node("IncrementButton")
	var count_label: Label = row.get_node("PlayerCountLabel")
	assert_str(count_label.text).is_equal("4")

	inc.pressed.emit()
	assert_str(count_label.text).is_equal("4")  # already at MAX_PLAYER_COUNT

	var reloaded := GameSettings.new(dir).load_or_default()
	assert_int(reloaded["player_count"]).is_equal(4)
	_cleanup(dir)


func test_back_button_emits_closed_with_current_settings() -> void:
	var dir := _temp_dir("gs_screen_close")
	var screen: SettingsScreen = auto_free(SettingsScreen.new(dir))
	add_child(screen)
	await get_tree().process_frame

	var emitted := []
	screen.closed.connect(func(settings: Dictionary) -> void: emitted.append(settings))
	var back_button: Button = screen.get_node("Rows/BackButton")
	back_button.pressed.emit()

	assert_int(emitted.size()).is_equal(1)
	assert_dict(emitted[0]).is_equal(GameSettings.DEFAULTS)
	_cleanup(dir)
