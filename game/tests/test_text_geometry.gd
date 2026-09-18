extends SceneTree

## Manual headless smoke test for TextGeometry (TASK-014.05), runnable via:
##   godot --headless --path game --script res://tests/test_text_geometry.gd
## Stopgap until TASK-014.07 bootstraps gdUnit4, matching
## tests/test_sprite_geometry.gd's convention. Exits 0 on success, 1 on the
## first failed assertion (printed to stderr).

var _failures := 0
var _main_instance: Node


func _initialize() -> void:
	_test_char_to_font_index_matches_put_text_ranges()
	_test_text_width_against_real_font_atlas()
	_test_build_text_draw_commands_align_modes()
	_test_score_digits()
	_test_build_score_draw_commands_against_real_numbers_atlas()

	var packed: PackedScene = load("res://main.tscn")
	_main_instance = packed.instantiate()
	get_root().add_child(_main_instance)
	process_frame.connect(_run_scoreboard_scene_test_once, CONNECT_ONE_SHOT)


func _run_scoreboard_scene_test_once() -> void:
	_test_scoreboard_renderer_wired_above_foreground()

	if _failures > 0:
		push_error("%d test_text_geometry assertion(s) failed" % _failures)
		quit(1)
	else:
		print("test_text_geometry: OK")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: %s" % message)


func _load_frames(path: String) -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data["frames"]


## sdl/gfx.c put_text()'s char->image ranges, spot-checked at each range's
## boundaries plus a handful of the special single-char cases.
func _test_char_to_font_index_matches_put_text_ranges() -> void:
	_assert(TextGeometry.char_to_font_index(33) == 0, "'!' (33) should map to font index 0")
	_assert(TextGeometry.char_to_font_index(34) == 1, "'\"' (34) should map to font index 1")
	_assert(TextGeometry.char_to_font_index(39) == 2, "39 should map to font index 2")
	_assert(TextGeometry.char_to_font_index(41) == 4, "41 should map to font index 4")
	_assert(TextGeometry.char_to_font_index(44) == 5, "44 should map to font index 5")
	_assert(TextGeometry.char_to_font_index(59) == 20, "59 should map to font index 20")
	_assert(TextGeometry.char_to_font_index(65) == 22, "'A' (65) should map to font index 22")
	_assert(TextGeometry.char_to_font_index(90) == 47, "'Z' (90) should map to font index 47")
	_assert(TextGeometry.char_to_font_index(97) == 48, "'a' (97) should map to font index 48")
	_assert(TextGeometry.char_to_font_index(122) == 73, "'z' (122) should map to font index 73")
	_assert(TextGeometry.char_to_font_index(0x7e) == 74, "'~' should map to font index 74")
	_assert(TextGeometry.char_to_font_index(0x99) == 80, "0x99 should map to font index 80")
	_assert(TextGeometry.char_to_font_index(35) == -1, "'#' (35, outside every range) should be unsupported")
	_assert(TextGeometry.char_to_font_index(32) == -1, "space is handled separately, not via char_to_font_index")


## Cross-checks against the real, committed font_atlas.json (TASK-013.01) --
## the atlas geometry is the ground truth for glyph widths, not a formula
## reproduced independently here.
func _test_text_width_against_real_font_atlas() -> void:
	var font_frames := _load_frames("res://content/sprites/font_atlas.json")

	# 'A' -> font index 22.
	var frame_a := SpriteGeometry.frame_rect(font_frames, 22)
	_assert(not frame_a.is_empty(), "font_atlas.json must have frame 22 ('A') to test against")
	var expected_width_a := int(frame_a["width"]) + 1
	_assert(TextGeometry.text_width("A", font_frames) == expected_width_a, "single-char width should be glyph width + 1, got %d expected %d" % [TextGeometry.text_width("A", font_frames), expected_width_a])

	# A leading/trailing space always costs a flat 5px, independent of the atlas.
	_assert(TextGeometry.text_width(" A", font_frames) == TextGeometry.SPACE_WIDTH + expected_width_a, "space should add a flat 5px")


func _test_build_text_draw_commands_align_modes() -> void:
	var font_frames := _load_frames("res://content/sprites/font_atlas.json")
	var width := TextGeometry.text_width("AB", font_frames)

	var left := TextGeometry.build_text_draw_commands("AB", 100, 20, TextGeometry.ALIGN_LEFT, font_frames)
	_assert(left.size() == 2, "two glyphs should produce two draw commands, got %d" % left.size())
	_assert(left[0]["position"] == Vector2i(100, 20), "left-aligned first glyph should start exactly at x, got %s" % left[0]["position"])

	var right := TextGeometry.build_text_draw_commands("AB", 100, 20, TextGeometry.ALIGN_RIGHT, font_frames)
	_assert(right[0]["position"].x == 100 - width, "right-aligned first glyph should start at x - width, got %d expected %d" % [right[0]["position"].x, 100 - width])

	var center := TextGeometry.build_text_draw_commands("AB", 100, 20, TextGeometry.ALIGN_CENTER, font_frames)
	_assert(center[0]["position"].x == 100 - width / 2, "center-aligned first glyph should start at x - width/2, got %d expected %d" % [center[0]["position"].x, 100 - width / 2])

	var unsupported := TextGeometry.build_text_draw_commands("#", 0, 0, TextGeometry.ALIGN_LEFT, font_frames)
	_assert(unsupported.is_empty(), "an unsupported char should be skipped like put_text()'s own `continue`, not crash")


## main.c:591 -- s1 = player[c1].bumps % 100, tens = s1/10, units = s1 - tens*10.
func _test_score_digits() -> void:
	_assert(TextGeometry.score_digits(0) == Vector2i(0, 0), "0 bumps should be digits (0, 0)")
	_assert(TextGeometry.score_digits(7) == Vector2i(0, 7), "7 bumps should be digits (0, 7)")
	_assert(TextGeometry.score_digits(42) == Vector2i(4, 2), "42 bumps should be digits (4, 2)")
	_assert(TextGeometry.score_digits(100) == Vector2i(0, 0), "100 bumps should wrap to (0, 0) via %% 100, matching main.c")
	_assert(TextGeometry.score_digits(199) == Vector2i(9, 9), "199 bumps should wrap to (9, 9) via %% 100")


## Cross-checks against the real, committed numbers_atlas.json (TASK-013.01)
## and main.c:594-597's fixed column/row layout.
func _test_build_score_draw_commands_against_real_numbers_atlas() -> void:
	var numbers_frames := _load_frames("res://content/sprites/numbers_atlas.json")
	var frame_4 := SpriteGeometry.frame_rect(numbers_frames, 4)
	var frame_2 := SpriteGeometry.frame_rect(numbers_frames, 2)
	_assert(not frame_4.is_empty() and not frame_2.is_empty(), "numbers_atlas.json must have frames 2 and 4 to test against")

	var commands := TextGeometry.build_score_draw_commands(42, 1, numbers_frames)
	_assert(commands.size() == 2, "score draw should produce exactly two digit commands, got %d" % commands.size())

	var tens: Dictionary = commands[0]
	_assert(tens["frame_index"] == 4, "tens digit of 42 should be frame index 4, got %d" % tens["frame_index"])
	_assert(tens["position"] == Vector2i(TextGeometry.SCORE_TENS_X, TextGeometry.SCORE_Y_BASE + TextGeometry.SCORE_ROW_HEIGHT), "tens digit position should match main.c's row layout for player slot 1")

	var units: Dictionary = commands[1]
	_assert(units["frame_index"] == 2, "units digit of 42 should be frame index 2, got %d" % units["frame_index"])
	_assert(units["position"] == Vector2i(TextGeometry.SCORE_UNITS_X, TextGeometry.SCORE_Y_BASE + TextGeometry.SCORE_ROW_HEIGHT), "units digit position should match main.c's row layout for player slot 1")


## TASK-014.05's scoreboard should be present in the scene and draw on top
## of the masked foreground (it's HUD content, not part of level layering).
func _test_scoreboard_renderer_wired_above_foreground() -> void:
	var foreground_index := _main_instance.get_node("Foreground").get_index()
	var scoreboard_index := _main_instance.get_node("ScoreboardRenderer").get_index()
	_assert(foreground_index < scoreboard_index, "ScoreboardRenderer must draw after (be a later sibling than) Foreground")

	_main_instance.queue_free()
