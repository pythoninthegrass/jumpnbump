extends GdUnitTestSuite

## TASK-015.01: InputRouter bitmask math and InputBindings persistence.


func test_default_bindings_match_globals_pre_scheme() -> void:
	var defaults := InputBindings.DEFAULT_BINDINGS
	assert_int(defaults.size()).is_equal(4)
	assert_dict(defaults[0]).is_equal({"left": KEY_LEFT, "right": KEY_RIGHT, "jump": KEY_UP})
	assert_dict(defaults[1]).is_equal({"left": KEY_A, "right": KEY_D, "jump": KEY_W})
	assert_dict(defaults[2]).is_equal({"left": KEY_J, "right": KEY_L, "jump": KEY_I})
	assert_dict(defaults[3]).is_equal({"left": KEY_KP_4, "right": KEY_KP_6, "jump": KEY_KP_8})


func test_compute_masks_sets_one_bit_per_pressed_player() -> void:
	# Player 0 holds left, player 2 holds jump; nobody holds right.
	var pressed := func(player: int, action: String) -> bool:
		return (player == 0 and action == "left") or (player == 2 and action == "jump")
	var masks := InputRouter.compute_masks(4, pressed)
	assert_int(masks["left"]).is_equal(1)  # bit 0
	assert_int(masks["right"]).is_equal(0)
	assert_int(masks["jump"]).is_equal(4)  # bit 2


func test_compute_masks_ignores_players_past_max_players() -> void:
	var pressed := func(_player: int, _action: String) -> bool:
		return true
	var masks := InputRouter.compute_masks(6, pressed)
	assert_int(masks["left"]).is_equal(0b1111)


func test_input_bindings_round_trips_through_a_temp_dir() -> void:
	var dir := "user://test_input_bindings_%d" % Time.get_ticks_usec()
	var store := InputBindings.new(dir)
	var written: Array = InputBindings.DEFAULT_BINDINGS.duplicate(true)
	written[0]["jump"] = KEY_SPACE
	var err := store.save(written)
	assert_int(err).is_equal(OK)
	var loaded := store.load_or_default()
	assert_array(loaded).is_equal(written)
	DirAccess.remove_absolute(dir.path_join(InputBindings.FILE_NAME))
	DirAccess.remove_absolute(dir)


func test_input_bindings_fills_in_missing_player_with_defaults() -> void:
	var dir := "user://test_input_bindings_partial_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	var store := InputBindings.new(dir)
	var file := FileAccess.open(dir.path_join(InputBindings.FILE_NAME), FileAccess.WRITE)
	file.store_string(JSON.stringify([{"left": KEY_LEFT, "right": KEY_RIGHT, "jump": KEY_SPACE}]))
	file.close()
	var loaded := store.load_or_default()
	assert_int(loaded[0]["jump"]).is_equal(KEY_SPACE)
	assert_dict(loaded[1]).is_equal(InputBindings.DEFAULT_BINDINGS[1])
	DirAccess.remove_absolute(dir.path_join(InputBindings.FILE_NAME))
	DirAccess.remove_absolute(dir)
