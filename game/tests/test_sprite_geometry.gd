extends SceneTree

## Manual headless smoke test for SpriteGeometry (TASK-014.03), runnable via:
##   godot --headless --path game --script res://tests/test_sprite_geometry.gd
## Stopgap until TASK-014.07 bootstraps gdUnit4, matching
## tests/test_tick_driver.gd's convention. Exits 0 on success, 1 on the
## first failed assertion (printed to stderr).

var _failures := 0
var _main_instance: Node


func _initialize() -> void:
	_test_object_category()
	_test_rabbit_frame_index()
	_test_pixel_from_fixed()
	_test_draw_origin()
	_test_frame_rect_lookup()
	_test_build_player_draw_commands_against_real_atlas()
	_test_build_object_draw_commands_against_real_atlas()
	_test_disabled_and_unused_slots_are_skipped()

	# Node._ready() is deferred to the next idle frame, not synchronous with
	# add_child() -- instantiate now, but assert on the children from
	# process_frame's one-shot callback below, once main.tscn's own
	# _ready() has actually run and populated them.
	var packed: PackedScene = load("res://main.tscn")
	_main_instance = packed.instantiate()
	get_root().add_child(_main_instance)
	process_frame.connect(_run_draw_order_test_once, CONNECT_ONE_SHOT)


func _run_draw_order_test_once() -> void:
	_test_draw_order_background_sprites_foreground()

	if _failures > 0:
		push_error("%d test_sprite_geometry assertion(s) failed" % _failures)
		quit(1)
	else:
		print("test_sprite_geometry: OK")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: %s" % message)


func _load_frames(path: String) -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data["frames"]


## main.c's OBJ_* -> category mapping: spring/splash/smoke are plain
## objects, the two butterfly types are flies, fur/flesh/flesh_trace are
## gore/leftovers.
func _test_object_category() -> void:
	_assert(SpriteGeometry.object_category(SpriteGeometry.OBJ_SPRING) == SpriteGeometry.CATEGORY_OBJECT, "spring should be category 'object'")
	_assert(SpriteGeometry.object_category(SpriteGeometry.OBJ_SPLASH) == SpriteGeometry.CATEGORY_OBJECT, "splash should be category 'object'")
	_assert(SpriteGeometry.object_category(SpriteGeometry.OBJ_SMOKE) == SpriteGeometry.CATEGORY_OBJECT, "smoke should be category 'object'")
	_assert(SpriteGeometry.object_category(SpriteGeometry.OBJ_YEL_BUTFLY) == SpriteGeometry.CATEGORY_FLY, "yellow butterfly should be category 'fly'")
	_assert(SpriteGeometry.object_category(SpriteGeometry.OBJ_PINK_BUTFLY) == SpriteGeometry.CATEGORY_FLY, "pink butterfly should be category 'fly'")
	_assert(SpriteGeometry.object_category(SpriteGeometry.OBJ_FUR) == SpriteGeometry.CATEGORY_GORE, "fur should be category 'gore'")
	_assert(SpriteGeometry.object_category(SpriteGeometry.OBJ_FLESH) == SpriteGeometry.CATEGORY_GORE, "flesh should be category 'gore'")
	_assert(SpriteGeometry.object_category(SpriteGeometry.OBJ_FLESH_TRACE) == SpriteGeometry.CATEGORY_GORE, "flesh_trace should be category 'gore'")


## main.c:1413 -- pobs[c2].image = player[i].image + i * 18.
func _test_rabbit_frame_index() -> void:
	_assert(SpriteGeometry.rabbit_frame_index(5, 0) == 5, "player slot 0 should not offset the base image")
	_assert(SpriteGeometry.rabbit_frame_index(5, 1) == 23, "player slot 1 should offset by 18")
	_assert(SpriteGeometry.rabbit_frame_index(0, 3) == 54, "player slot 3 should offset by 54")


## core/fixed16.zig's shr16: raw 16.16 fixed-point -> pixel.
func _test_pixel_from_fixed() -> void:
	_assert(SpriteGeometry.pixel_from_fixed(0) == 0, "0 fixed should be pixel 0")
	_assert(SpriteGeometry.pixel_from_fixed(1 << 16) == 1, "1<<16 fixed should be pixel 1")
	_assert(SpriteGeometry.pixel_from_fixed(100 << 16) == 100, "100<<16 fixed should be pixel 100")


## core/gob.zig:124 -- a sprite blits at (x - hs_x, y - hs_y); a negative
## hotspot (real rabbit frames have some) must still subtract correctly.
func _test_draw_origin() -> void:
	var origin := SpriteGeometry.draw_origin(10 << 16, 20 << 16, 3, 5)
	_assert(origin == Vector2i(7, 15), "positive hotspot should subtract from pixel position, got %s" % origin)

	var negative_hotspot_origin := SpriteGeometry.draw_origin(10 << 16, 20 << 16, -2, -1)
	_assert(negative_hotspot_origin == Vector2i(12, 21), "negative hotspot should add to pixel position, got %s" % negative_hotspot_origin)


func _test_frame_rect_lookup() -> void:
	var frames := [
		{"index": 0, "x": 0, "y": 0, "width": 10, "height": 10, "hotspot_x": 0, "hotspot_y": 0},
		{"index": 5, "x": 50, "y": 0, "width": 12, "height": 8, "hotspot_x": 1, "hotspot_y": 2},
	]
	_assert(SpriteGeometry.frame_rect(frames, 5)["x"] == 50, "frame_rect should find frame index 5")
	_assert(SpriteGeometry.frame_rect(frames, 99).is_empty(), "frame_rect should return an empty dict for a missing index")


## Cross-checks against the real, committed rabbit_atlas.json (TASK-013.01) --
## the atlas geometry is the ground truth for frame->rect mapping, not a
## formula reproduced independently here.
func _test_build_player_draw_commands_against_real_atlas() -> void:
	var rabbit_frames := _load_frames("res://content/sprites/rabbit_atlas.json")
	var real_frame_5 := SpriteGeometry.frame_rect(rabbit_frames, 5)
	_assert(not real_frame_5.is_empty(), "rabbit_atlas.json must have a frame 5 to test against")

	# Player slot 2's colour offset (2*18=36) lands on frame 5+36=41.
	var expected_frame_index := 5 + 2 * 18
	var real_frame_41 := SpriteGeometry.frame_rect(rabbit_frames, expected_frame_index)
	_assert(not real_frame_41.is_empty(), "rabbit_atlas.json must have frame %d to test against" % expected_frame_index)

	var player_views := [
		{"result": SpriteGeometry.OK, "enabled": false, "image": 0, "x": 0, "y": 0},
		{"result": SpriteGeometry.OK, "enabled": false, "image": 0, "x": 0, "y": 0},
		{"result": SpriteGeometry.OK, "enabled": true, "image": 5, "x": 100 << 16, "y": 50 << 16},
		{"result": SpriteGeometry.OK, "enabled": false, "image": 0, "x": 0, "y": 0},
	]
	var commands := SpriteGeometry.build_player_draw_commands(player_views, rabbit_frames)
	_assert(commands.size() == 1, "only the one enabled player should produce a draw command, got %d" % commands.size())

	var command: Dictionary = commands[0]
	_assert(command["category"] == SpriteGeometry.CATEGORY_PLAYER, "command category should be 'player'")
	_assert(command["player"] == 2, "command should be for player slot 2, got %d" % command["player"])
	_assert(command["frame_index"] == expected_frame_index, "frame_index should be %d, got %d" % [expected_frame_index, command["frame_index"]])
	_assert(command["src_x"] == int(real_frame_41["x"]), "src_x should match the real atlas frame's x")
	_assert(command["width"] == int(real_frame_41["width"]), "width should match the real atlas frame's width")
	var expected_position := SpriteGeometry.draw_origin(100 << 16, 50 << 16, int(real_frame_41["hotspot_x"]), int(real_frame_41["hotspot_y"]))
	_assert(command["position"] == expected_position, "position should account for the real atlas frame's hotspot, got %s expected %s" % [command["position"], expected_position])


func _test_build_object_draw_commands_against_real_atlas() -> void:
	var objects_frames := _load_frames("res://content/sprites/objects_atlas.json")
	var real_frame_3 := SpriteGeometry.frame_rect(objects_frames, 3)
	_assert(not real_frame_3.is_empty(), "objects_atlas.json must have a frame 3 to test against")

	var objects := [
		{"used": 0, "type": SpriteGeometry.OBJ_SPRING, "image": 3, "x": 0, "y": 0},
		{"used": 1, "type": SpriteGeometry.OBJ_YEL_BUTFLY, "image": 3, "x": 200 << 16, "y": 80 << 16},
		{"used": 1, "type": SpriteGeometry.OBJ_FLESH, "image": 3, "x": 10 << 16, "y": 10 << 16},
	]
	var commands := SpriteGeometry.build_object_draw_commands(objects, objects_frames)
	_assert(commands.size() == 2, "only used slots should produce a draw command, got %d" % commands.size())

	var fly_command: Dictionary = commands[0]
	_assert(fly_command["category"] == SpriteGeometry.CATEGORY_FLY, "first command should be category 'fly', got %s" % fly_command["category"])
	var expected_fly_position := SpriteGeometry.draw_origin(200 << 16, 80 << 16, int(real_frame_3["hotspot_x"]), int(real_frame_3["hotspot_y"]))
	_assert(fly_command["position"] == expected_fly_position, "fly position should account for the real atlas hotspot")

	var gore_command: Dictionary = commands[1]
	_assert(gore_command["category"] == SpriteGeometry.CATEGORY_GORE, "second command should be category 'gore', got %s" % gore_command["category"])


func _test_disabled_and_unused_slots_are_skipped() -> void:
	var rabbit_frames := _load_frames("res://content/sprites/rabbit_atlas.json")
	var all_disabled := [
		{"result": SpriteGeometry.OK, "enabled": false, "image": 0, "x": 0, "y": 0},
	]
	_assert(SpriteGeometry.build_player_draw_commands(all_disabled, rabbit_frames).is_empty(), "no enabled players should produce zero commands")

	var error_view := [
		{"result": 1, "enabled": true, "image": 0, "x": 0, "y": 0},
	]
	_assert(SpriteGeometry.build_player_draw_commands(error_view, rabbit_frames).is_empty(), "a non-OK result view should be skipped even if enabled")

	var objects_frames := _load_frames("res://content/sprites/objects_atlas.json")
	var all_unused := [
		{"used": 0, "type": SpriteGeometry.OBJ_SPRING, "image": 0, "x": 0, "y": 0},
	]
	_assert(SpriteGeometry.build_object_draw_commands(all_unused, objects_frames).is_empty(), "no used object slots should produce zero commands")


## TASK-014.03 AC#2: background under sprites, masked foreground over
## sprites. Structural check on the actual composition root (main.gd),
## since CanvasItem draw order is scene-tree child order, not something
## SpriteGeometry's pure functions touch.
func _test_draw_order_background_sprites_foreground() -> void:
	var background_index := _main_instance.get_node("Background").get_index()
	var renderer_index := _main_instance.get_node("SpriteRenderer").get_index()
	var foreground_index := _main_instance.get_node("Foreground").get_index()

	_assert(background_index < renderer_index, "Background must draw before (be an earlier sibling than) SpriteRenderer")
	_assert(renderer_index < foreground_index, "SpriteRenderer must draw before (be an earlier sibling than) Foreground")

	_main_instance.queue_free()
