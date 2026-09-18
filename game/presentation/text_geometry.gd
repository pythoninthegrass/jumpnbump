class_name TextGeometry
extends RefCounted

## Pure static math with no Node/viewport dependency (mirrors
## sprite_geometry.gd's TASK-014.03 precedent): every number here is
## directly pinned by a headless test without instantiating a scene. All
## actual draw_texture_rect_region() calls live in scoreboard_renderer.gd
## instead.
##
## char_to_font_index()/build_text_draw_commands() are a line-for-line port
## of sdl/gfx.c's put_text() char->image ranges and align modes (0=left,
## 1=right, 2=center); build_score_draw_commands() ports main.c:594-597's
## add_leftovers() calls that stamp a player's `bumps % 100` as two digit
## sprites from numbers.gob at fixed screen columns.

const SPACE_WIDTH := 5
const ALIGN_LEFT := 0
const ALIGN_RIGHT := 1
const ALIGN_CENTER := 2

## Fixed layout from main.c:594-597: tens digit at x=360, units digit at
## x=376, row y = 34 + player_slot * 64.
const SCORE_TENS_X := 360
const SCORE_UNITS_X := 376
const SCORE_Y_BASE := 34
const SCORE_ROW_HEIGHT := 64

## sdl/gfx.c put_text(): char code -> font_atlas frame index, or -1 if the
## original's char loop would `continue` (glyph not present in font.gob).
static func char_to_font_index(code: int) -> int:
	if code >= 33 and code <= 34:
		return code - 33
	if code >= 39 and code <= 41:
		return code - 37
	if code >= 44 and code <= 59:
		return code - 39
	if code >= 64 and code <= 90:
		return code - 43
	if code >= 97 and code <= 122:
		return code - 49
	if code == 0x7e: # '~'
		return 74
	if code == 0x84:
		return 75
	if code == 0x86:
		return 76
	if code == 0x8e:
		return 77
	if code == 0x8f:
		return 78
	if code == 0x94:
		return 79
	if code == 0x99:
		return 80
	return -1

## sdl/gfx.c put_text()'s first pass: total pixel width of `text`, used to
## resolve align modes 1 (right) and 2 (center). `frames` is font_atlas.json's
## "frames" array; SpriteGeometry.frame_rect() does the lookup.
static func text_width(text: String, frames: Array) -> int:
	var width := 0
	for code in text.to_ascii_buffer():
		if code == 32: # ' '
			width += SPACE_WIDTH
			continue
		var index := char_to_font_index(code)
		if index < 0:
			continue
		var frame := SpriteGeometry.frame_rect(frames, index)
		if frame.is_empty():
			continue
		width += int(frame["width"]) + 1
	return width

## sdl/gfx.c put_text()'s second pass: one draw command per glyph, in string
## order, with `cur_x` advancing exactly as the original's align/width math
## does. Returns [{"frame_index": int, "position": Vector2i}, ...].
static func build_text_draw_commands(text: String, x: int, y: int, align: int, frames: Array) -> Array:
	var commands := []
	var width := text_width(text, frames)
	var cur_x := x
	match align:
		ALIGN_RIGHT:
			cur_x = x - width
		ALIGN_CENTER:
			cur_x = x - width / 2
		_:
			cur_x = x

	for code in text.to_ascii_buffer():
		if code == 32: # ' '
			cur_x += SPACE_WIDTH
			continue
		var index := char_to_font_index(code)
		if index < 0:
			continue
		var frame := SpriteGeometry.frame_rect(frames, index)
		if frame.is_empty():
			continue
		commands.append({
			"frame_index": index,
			"position": Vector2i(cur_x, y),
			"src_x": int(frame["x"]),
			"src_y": int(frame["y"]),
			"width": int(frame["width"]),
			"height": int(frame["height"]),
		})
		cur_x += int(frame["width"]) + 1
	return commands

## main.c:591's `s1 = player[c1].bumps % 100` decomposed into tens/units
## digits, each a direct 0-9 index into numbers_atlas.png (numbers.gob has
## exactly one frame per digit, no char-code remapping like the font).
static func score_digits(bumps: int) -> Vector2i:
	var s1 := bumps % 100
	var tens := s1 / 10
	var units := s1 - tens * 10
	return Vector2i(tens, units)

## One draw command per digit (tens, units) for a single player row.
## `numbers_frames` is numbers_atlas.json's "frames" array.
static func build_score_draw_commands(bumps: int, player_slot: int, numbers_frames: Array) -> Array:
	var digits := score_digits(bumps)
	var y := SCORE_Y_BASE + player_slot * SCORE_ROW_HEIGHT
	var commands := []
	for entry in [[digits.x, SCORE_TENS_X], [digits.y, SCORE_UNITS_X]]:
		var digit: int = entry[0]
		var x: int = entry[1]
		var frame := SpriteGeometry.frame_rect(numbers_frames, digit)
		if frame.is_empty():
			continue
		commands.append({
			"frame_index": digit,
			"position": Vector2i(x, y),
			"src_x": int(frame["x"]),
			"src_y": int(frame["y"]),
			"width": int(frame["width"]),
			"height": int(frame["height"]),
		})
	return commands
