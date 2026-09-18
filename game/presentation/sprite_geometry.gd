class_name SpriteGeometry
extends RefCounted

## Pure static math with no Node/viewport dependency (TASK-014.03 AC#3),
## mirroring neo_snake's board_geometry.gd precedent: every number here is
## directly pinned by a headless test without instantiating a scene. All
## actual draw_texture_rect_region() calls live in sprite_renderer.gd
## instead.
##
## Deliberately duplicates a couple of jnb_* constants (OK, the OBJ_*
## values) rather than importing SimWorld/JumpnbumpWorld: this file has no
## simulation dependency at all, matching board_geometry.gd's own
## STATUS_MENU-style duplication of a value it isn't allowed to reach for
## directly.

const OK := 0 ## jnb_result JNB_OK (include/jumpnbump.h)

## core/objects.zig's obj_* constants (mirrors main.c's OBJ_* enum).
const OBJ_SPRING := 0
const OBJ_SPLASH := 1
const OBJ_SMOKE := 2
const OBJ_YEL_BUTFLY := 3
const OBJ_PINK_BUTFLY := 4
const OBJ_FUR := 5
const OBJ_FLESH := 6
const OBJ_FLESH_TRACE := 7

const CATEGORY_PLAYER := "player"
const CATEGORY_OBJECT := "object"
const CATEGORY_FLY := "fly"
const CATEGORY_GORE := "gore"

## Which of the four presentation categories (TASK-014.03's own list:
## players, particles/objects, flies, gore/leftovers) a jnb_object_view's
## `type` belongs to.
static func object_category(type: int) -> String:
	match type:
		OBJ_YEL_BUTFLY, OBJ_PINK_BUTFLY:
			return CATEGORY_FLY
		OBJ_FUR, OBJ_FLESH, OBJ_FLESH_TRACE:
			return CATEGORY_GORE
		_:
			return CATEGORY_OBJECT

## main.c:1413 -- `pobs[c2].image = player[i].image + i * 18` -- selects a
## player's colour slot within rabbit_atlas.png; player[i].image already has
## direction*9 folded in by core/steer.zig's playerImage() (main.c's own
## `player[c1].image = player_anims[...].image + direction * 9`).
static func rabbit_frame_index(image: int, player_slot: int) -> int:
	return image + player_slot * 18

## core/fixed16.zig's shr16 (`v >> 16`): jnb_player_view.x/y and
## jnb_object_view.x/y are raw 16.16 fixed-point, never pre-shifted by the
## ABI.
static func pixel_from_fixed(value: int) -> int:
	return value >> 16

## core/gob.zig:124 -- "a sprite at (x, y) blits at (x - hs_x, y - hs_y)".
static func draw_origin(x_fixed: int, y_fixed: int, hotspot_x: int, hotspot_y: int) -> Vector2i:
	return Vector2i(
		pixel_from_fixed(x_fixed) - hotspot_x,
		pixel_from_fixed(y_fixed) - hotspot_y,
	)

## Linear scan, not a lookup table: `frames` is the atlas JSON's own
## "frames" array (at most ~80 entries), passed in by the caller so this
## function stays free of any FileAccess/JSON parsing of its own.
static func frame_rect(frames: Array, index: int) -> Dictionary:
	for frame in frames:
		if int(frame["index"]) == index:
			return frame
	return {}

## One draw command per enabled player, in `player_views` order (player
## slot == array index, matching main.c's per-player colour i*18 slot).
## `player_views` holds jnb_player_view_get() results (Dictionaries with a
## "result" field), `rabbit_frames` is rabbit_atlas.json's "frames" array.
static func build_player_draw_commands(player_views: Array, rabbit_frames: Array) -> Array:
	var commands := []
	for slot in range(player_views.size()):
		var view: Dictionary = player_views[slot]
		if int(view.get("result", -1)) != OK or not view.get("enabled", false):
			continue
		var frame_index := rabbit_frame_index(int(view["image"]), slot)
		var frame := frame_rect(rabbit_frames, frame_index)
		if frame.is_empty():
			continue
		commands.append({
			"category": CATEGORY_PLAYER,
			"player": slot,
			"frame_index": frame_index,
			"position": draw_origin(int(view["x"]), int(view["y"]), int(frame["hotspot_x"]), int(frame["hotspot_y"])),
			"src_x": int(frame["x"]),
			"src_y": int(frame["y"]),
			"width": int(frame["width"]),
			"height": int(frame["height"]),
		})
	return commands

## One draw command per used object slot (particles, flies, and
## gore/leftovers all share objects.gob/objects_atlas.png -- see
## tools/build_sprite_atlas.py). `objects` holds jnb_objects_copy() view
## Dictionaries, `objects_frames` is objects_atlas.json's "frames" array.
static func build_object_draw_commands(objects: Array, objects_frames: Array) -> Array:
	var commands := []
	for obj in objects:
		if int(obj.get("used", 0)) != 1:
			continue
		var image := int(obj["image"])
		var frame := frame_rect(objects_frames, image)
		if frame.is_empty():
			continue
		commands.append({
			"category": object_category(int(obj["type"])),
			"frame_index": image,
			"position": draw_origin(int(obj["x"]), int(obj["y"]), int(frame["hotspot_x"]), int(frame["hotspot_y"])),
			"src_x": int(frame["x"]),
			"src_y": int(frame["y"]),
			"width": int(frame["width"]),
			"height": int(frame["height"]),
		})
	return commands
