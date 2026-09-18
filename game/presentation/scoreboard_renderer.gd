class_name ScoreboardRenderer
extends Node2D

## Draws each enabled player's live bump count as two digit sprites from
## numbers_atlas.png (main.c:594-597's add_leftovers() stamps, TASK-014.05)
## plus a font-atlas player-name label per row, off the per-frame
## JumpnbumpWorld state (TASK-014.02's SimWorld). All position/index math is
## pure and lives in text_geometry.gd; this file only reads world state,
## loads the atlas resources, and issues the actual draw calls -- the same
## split sprite_renderer.gd established in TASK-014.03.

const MAX_PLAYERS := 4

## main.c:1651-1658's post-match scoreboard names, reused here as the
## in-game per-row player label (AC#2's "in-game text" example) since
## gameplay itself never shows a player-name string anywhere else in main.c.
const PLAYER_LABELS := ["DOTT", "JIFFY", "FIZZ", "MIJJI"]
const LABEL_X := 40

var world: SimWorld

var _numbers_texture: Texture2D
var _font_texture: Texture2D
var _numbers_frames: Array = []
var _font_frames: Array = []

func setup(p_world: SimWorld) -> void:
	world = p_world
	_numbers_texture = load("res://content/sprites/numbers_atlas.png")
	_font_texture = load("res://content/sprites/font_atlas.png")
	_numbers_frames = _load_frames("res://content/sprites/numbers_atlas.json")
	_font_frames = _load_frames("res://content/sprites/font_atlas.json")

func _load_frames(path: String) -> Array:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return []
	var data = JSON.parse_string(text)
	if data == null:
		return []
	return data.get("frames", [])

func _process(_delta: float) -> void:
	if world != null:
		queue_redraw()

func _draw() -> void:
	if world == null:
		return

	for slot in range(MAX_PLAYERS):
		var view: Dictionary = world.player_view_get(slot)
		if int(view.get("result", -1)) != SimWorld.OK or not view.get("enabled", false):
			continue

		var label_y := TextGeometry.SCORE_Y_BASE + slot * TextGeometry.SCORE_ROW_HEIGHT
		var label_commands := TextGeometry.build_text_draw_commands(
			PLAYER_LABELS[slot], LABEL_X, label_y, TextGeometry.ALIGN_LEFT, _font_frames
		)
		_draw_commands(label_commands, _font_texture)

		var score_commands := TextGeometry.build_score_draw_commands(int(view["bumps"]), slot, _numbers_frames)
		_draw_commands(score_commands, _numbers_texture)

func _draw_commands(commands: Array, texture: Texture2D) -> void:
	if texture == null:
		return
	for command in commands:
		var size := Vector2(command["width"], command["height"])
		var src_rect := Rect2(command["src_x"], command["src_y"], size.x, size.y)
		var dst_rect := Rect2(command["position"], size)
		draw_texture_rect_region(texture, dst_rect, src_rect)
