extends SceneTree

## Manual headless smoke test for level-layer composition (TASK-014.04),
## runnable via:
##   godot --headless --path game --script res://tests/test_level_layers.gd
## Stopgap until TASK-014.07 bootstraps gdUnit4, matching
## tests/test_sprite_geometry.gd's convention. Exits 0 on success, 1 on the
## first failed assertion (printed to stderr).

var _failures := 0
var _gameplay_instance: GameplayScreen


func _initialize() -> void:
	_test_compute_window_size_is_an_integer_multiple()
	_test_compute_window_size_scales_with_display_scale()

	# Node._ready() is deferred to the next idle frame -- instantiate now,
	# assert on the populated children from process_frame's one-shot
	# callback below, once GameplayScreen's own start() has actually run.
	# Main.gd (TASK-015.04) no longer builds level layers itself at
	# startup -- it shows TitleScreen first -- so this test exercises
	# GameplayScreen directly instead of main.tscn.
	_gameplay_instance = GameplayScreen.new()
	get_root().add_child(_gameplay_instance)
	var input_router := InputRouter.new()
	get_root().add_child(input_router)
	_gameplay_instance.start(
		{"seed": 1, "flies_enabled": false, "level_bytes": Main.SAMPLE_LEVEL_TEXT.to_utf8_buffer(), "player_count": 0, "ai_mask": 0, "no_gore": false},
		SfxPlayer.new(),
		input_router,
	)
	process_frame.connect(_run_scene_checks_once, CONNECT_ONE_SHOT)


func _run_scene_checks_once() -> void:
	_test_background_and_foreground_are_400x256()
	_test_project_settings_use_keep_stretch()

	if _failures > 0:
		push_error("%d test_level_layers assertion(s) failed" % _failures)
		quit(1)
	else:
		print("test_level_layers: OK")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: %s" % message)


## AC#3: window sizing is code (Main.compute_window_size), not a hardcoded
## project.godot window/size/viewport_* value -- those describe the design
## canvas the canvas_items/keep stretch mode scales into, not the OS window.
func _test_compute_window_size_is_an_integer_multiple() -> void:
	var size := Main.compute_window_size(Vector2i(400, 256), 2, 1.0)
	_assert(size == Vector2i(800, 512), "2x scale at display_scale 1.0 should be 800x512, got %s" % size)
	_assert(size.x % 400 == 0 and size.y % 256 == 0, "window size should be an integer multiple of the design size")


func _test_compute_window_size_scales_with_display_scale() -> void:
	var size := Main.compute_window_size(Vector2i(400, 256), 2, 1.5)
	_assert(size == Vector2i(1200, 768), "2x scale at display_scale 1.5 should be 1200x768, got %s" % size)


## AC#1: the level renders at the original 400x256 design resolution.
func _test_background_and_foreground_are_400x256() -> void:
	var background: Sprite2D = _gameplay_instance.get_node("LevelLayers/Background")
	var foreground: Sprite2D = _gameplay_instance.get_node("LevelLayers/Foreground")

	_assert(background.texture != null, "Background must have a texture loaded")
	_assert(foreground.texture != null, "Foreground must have a texture loaded")
	_assert(background.texture.get_size() == Vector2(400, 256), "Background texture should be 400x256, got %s" % background.texture.get_size())
	_assert(foreground.texture.get_size() == Vector2(400, 256), "Foreground texture should be 400x256, got %s" % foreground.texture.get_size())

	_gameplay_instance.queue_free()


## AC#2: letterboxing on window resize without stretching distortion comes
## from Godot's own canvas_items/keep stretch mode, not code this task
## reinvents -- assert the project actually has that mode configured, since
## that's the load-bearing setting behind AC#2. (Pixel-level letterbox
## rendering itself is only observable in a windowed run, not headlessly.)
func _test_project_settings_use_keep_stretch() -> void:
	var mode: String = ProjectSettings.get_setting("display/window/stretch/mode")
	var aspect: String = ProjectSettings.get_setting("display/window/stretch/aspect")
	_assert(mode == "canvas_items", "stretch mode should be canvas_items, got %s" % mode)
	_assert(aspect == "keep", "stretch aspect should be keep (letterboxed), got %s" % aspect)
