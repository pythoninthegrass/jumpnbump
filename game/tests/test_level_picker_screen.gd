extends GdUnitTestSuite

## TASK-016.02: LevelPickerScreen's built-in/browse/drag-and-drop selection,
## validation-driven error reporting, and recent-levels persistence.
## Real drag-and-drop can't be synthesized in a headless test run (there is
## no OS window to drop onto), so these call the drop handler directly with
## the paths the OS would have reported -- the same seam MenuScreen's own
## rebind tests use for physical key presses via _unhandled_input.


func _temp_dir(prefix: String) -> String:
	return "user://%s_%d" % [prefix, Time.get_ticks_usec()]


func _cleanup(dir: String) -> void:
	DirAccess.remove_absolute(dir.path_join(CustomLevels.FILE_NAME))
	DirAccess.remove_absolute(dir)


func _jumpbump_dat_path() -> String:
	var game_dir: String = ProjectSettings.globalize_path("res://").rstrip("/")
	return game_dir.get_base_dir().path_join("data/jumpbump.dat")


func _corrupt_dat_path(dir: String) -> String:
	var path := dir.path_join("corrupt.dat")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_32(1) # claims 1 entry, but the file ends here -- see test_asset_loader.gd
	file.close()
	return path


func test_built_in_button_emits_level_selected_with_an_empty_payload() -> void:
	var dir := _temp_dir("lp_builtin")
	var picker: LevelPickerScreen = auto_free(LevelPickerScreen.new(dir))
	add_child(picker)
	await get_tree().process_frame

	var emitted := []
	picker.level_selected.connect(func(payload: Dictionary, name: String) -> void: emitted.append([payload, name]))
	var built_in_button: Button = picker.get_node("Rows/BuiltInButton")
	built_in_button.pressed.emit()

	assert_int(emitted.size()).is_equal(1)
	assert_dict(emitted[0][0]).is_empty()
	assert_str(emitted[0][1]).is_equal(LevelPickerScreen.BUILT_IN_LABEL)
	_cleanup(dir)


func test_dropping_a_valid_dat_selects_it_and_records_it_as_recent() -> void:
	var dir := _temp_dir("lp_drop_valid")
	var picker: LevelPickerScreen = auto_free(LevelPickerScreen.new(dir))
	add_child(picker)
	await get_tree().process_frame

	var emitted := []
	picker.level_selected.connect(func(payload: Dictionary, name: String) -> void: emitted.append([payload, name]))
	var dat_path := _jumpbump_dat_path()
	picker._on_files_dropped(PackedStringArray([dat_path]))

	assert_int(emitted.size()).is_equal(1)
	assert_int(emitted[0][0]["result"]).is_equal(LevelValidator.JNB_OK)
	assert_str(emitted[0][1]).is_equal(dat_path.get_file())

	var error_label: Label = picker.get_node("Rows/ErrorLabel")
	assert_bool(error_label.visible).is_false()

	assert_int(CustomLevels.new(dir).list().size()).is_equal(1)
	_cleanup(dir)


func test_dropping_a_non_dat_file_shows_an_error_and_selects_nothing() -> void:
	var dir := _temp_dir("lp_drop_wrong_ext")
	var picker: LevelPickerScreen = auto_free(LevelPickerScreen.new(dir))
	add_child(picker)
	await get_tree().process_frame

	var emitted := []
	picker.level_selected.connect(func(_payload: Dictionary, _name: String) -> void: emitted.append(true))
	picker._on_files_dropped(PackedStringArray(["not_a_level.txt"]))

	assert_int(emitted.size()).is_equal(0)
	var error_label: Label = picker.get_node("Rows/ErrorLabel")
	assert_bool(error_label.visible).is_true()
	_cleanup(dir)


func test_selecting_a_corrupt_dat_shows_a_clear_error_and_does_not_crash() -> void:
	var dir := _temp_dir("lp_corrupt")
	DirAccess.make_dir_recursive_absolute(dir)
	var picker: LevelPickerScreen = auto_free(LevelPickerScreen.new(dir))
	add_child(picker)
	await get_tree().process_frame

	var emitted := []
	picker.level_selected.connect(func(_payload: Dictionary, _name: String) -> void: emitted.append(true))
	var corrupt_path := _corrupt_dat_path(dir)
	picker._try_select(corrupt_path)

	assert_int(emitted.size()).is_equal(0)
	var error_label: Label = picker.get_node("Rows/ErrorLabel")
	assert_bool(error_label.visible).is_true()
	assert_str(error_label.text).is_equal(LevelValidator.MISSING_LEVELMAP_MESSAGE)
	assert_int(CustomLevels.new(dir).list().size()).is_equal(0)

	DirAccess.remove_absolute(corrupt_path)
	_cleanup(dir)


func test_recent_levels_are_listed_as_rows_on_ready() -> void:
	var dir := _temp_dir("lp_recent_rows")
	DirAccess.make_dir_recursive_absolute(dir)
	var dat_path := _jumpbump_dat_path()
	CustomLevels.new(dir).add_recent(dat_path, "My Level")

	var picker: LevelPickerScreen = auto_free(LevelPickerScreen.new(dir))
	add_child(picker)
	await get_tree().process_frame

	var recent_rows: VBoxContainer = picker.get_node("Rows/RecentRows")
	assert_int(recent_rows.get_child_count()).is_equal(1)
	var recent_button: Button = recent_rows.get_child(0)
	assert_str(recent_button.text).is_equal("My Level")

	var emitted := []
	picker.level_selected.connect(func(payload: Dictionary, name: String) -> void: emitted.append([payload, name]))
	recent_button.pressed.emit()
	assert_int(emitted.size()).is_equal(1)
	assert_str(emitted[0][1]).is_equal(dat_path.get_file())
	_cleanup(dir)


func test_back_button_emits_closed() -> void:
	var dir := _temp_dir("lp_back")
	var picker: LevelPickerScreen = auto_free(LevelPickerScreen.new(dir))
	add_child(picker)
	await get_tree().process_frame

	var emitted := []
	picker.closed.connect(func() -> void: emitted.append(true))
	var back_button: Button = picker.get_node("Rows/BackButton")
	back_button.pressed.emit()

	assert_int(emitted.size()).is_equal(1)
	_cleanup(dir)
