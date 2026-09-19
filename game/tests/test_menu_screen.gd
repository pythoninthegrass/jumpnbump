extends GdUnitTestSuite

## TASK-015.02: menu slot bitmask math and the built Control tree's shape.


func test_toggle_ai_flips_only_the_given_slot() -> void:
	var mask := MenuSlots.toggle_ai(0, 1)
	assert_int(mask).is_equal(0b0010)
	assert_bool(MenuSlots.is_ai(mask, 0)).is_false()
	assert_bool(MenuSlots.is_ai(mask, 1)).is_true()
	assert_bool(MenuSlots.is_ai(mask, 2)).is_false()


func test_toggle_ai_is_its_own_inverse() -> void:
	var mask := MenuSlots.toggle_ai(0, 3)
	mask = MenuSlots.toggle_ai(mask, 3)
	assert_int(mask).is_equal(0)


func test_player_labels_and_colors_have_four_distinct_entries() -> void:
	assert_int(MenuSlots.PLAYER_LABELS.size()).is_equal(4)
	assert_int(MenuSlots.PLAYER_COLORS.size()).is_equal(4)
	assert_array(MenuSlots.PLAYER_LABELS).contains(["DOTT", "JIFFY", "FIZZ", "MIJJI"])


func test_menu_screen_builds_one_row_per_player_slot() -> void:
	var screen: MenuScreen = auto_free(MenuScreen.new())
	add_child(screen)
	await get_tree().process_frame

	var rows: Node = screen.get_node("Rows")
	assert_int(rows.get_child_count()).is_equal(MenuSlots.MAX_PLAYERS + 1)  # 4 slots + Start button
	for slot in MenuSlots.MAX_PLAYERS:
		var row: Node = rows.get_node("Slot%d" % slot)
		assert_object(row).is_not_null()
		var label: Label = row.get_node("Label")
		var mode_button: Button = row.get_node("ModeButton")
		assert_str(label.text).is_equal(MenuSlots.PLAYER_LABELS[slot])
		assert_str(mode_button.text).is_equal("HUMAN")


func test_toggling_a_slot_to_ai_disables_its_key_button() -> void:
	var screen: MenuScreen = auto_free(MenuScreen.new())
	add_child(screen)
	await get_tree().process_frame

	var row: Node = screen.get_node("Rows/Slot0")
	var mode_button: Button = row.get_node("ModeButton")
	var key_button: Button = row.get_node("KeyButton")
	assert_bool(key_button.disabled).is_false()

	mode_button.pressed.emit()
	assert_str(mode_button.text).is_equal("AI")
	assert_bool(key_button.disabled).is_true()


func test_start_pressed_emits_start_requested_with_current_ai_mask() -> void:
	var screen: MenuScreen = auto_free(MenuScreen.new())
	add_child(screen)
	await get_tree().process_frame

	screen.get_node("Rows/Slot1/ModeButton").pressed.emit()

	var emitted := []
	screen.start_requested.connect(func(ai_mask: int) -> void: emitted.append(ai_mask))
	screen.get_node("Rows/StartButton").pressed.emit()

	assert_array(emitted).is_equal([0b0010])
