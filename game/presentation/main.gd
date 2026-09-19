class_name Main
extends Node

## Composition root (TASK-014.01) and, since TASK-015.04, the title ->
## menu -> gameplay -> scores -> menu screen flow controller. main.tscn
## holds only this script on a single Node; every screen is instantiated
## in code and swapped under _screen_container as one child at a time.
## Audio players, InputRouter, and AppLifecycle are created once here and
## outlive every screen swap, so quitting from any screen still stops the
## one live MusicPlayer (TASK-014.06 AC#4) and InputRouter's persisted
## keybinds survive the whole session, not just one match.
##
## Placeholder level: no level-loading UI or content-driven level
## selection exists yet (TASK-016's job), so every match hardcodes the
## same sample level (TASK-014.02's fixture text).
const SAMPLE_LEVEL_TEXT := (
	"1110000000000000000000\n" +
	"1000000000001000011000\n" +
	"1000111100001100000000\n" +
	"1000000000011110000011\n" +
	"1100000000111000000001\n" +
	"1110001111110000000001\n" +
	"1000000000000011110001\n" +
	"1000000000000000000011\n" +
	"1110011100000000000111\n" +
	"1000000000003100000001\n" +
	"1000000000031110000001\n" +
	"1011110000311111111001\n" +
	"1000000000000000000001\n" +
	"1100000000000000000011\n" +
	"2222222214000001333111\n" +
	"1111111111111111111111\n"
)

## The original design resolution (main.c's SCREEN_WIDTH/SCREEN_HEIGHT).
## game/project.godot's viewport_width/height mirror these for the
## canvas_items/keep stretch base; DESIGN_SIZE is the code-side source of
## truth used to size the actual OS window (AC#3).
const DESIGN_SIZE := Vector2i(400, 256)

## Initial window size is an integer multiple of DESIGN_SIZE so canvas_items
## stretch starts pixel-perfect rather than needing non-integer upscaling;
## the user can still freely resize afterwards, and keep-aspect stretch mode
## (project.godot) letterboxes any resulting non-integer or mismatched-aspect
## window size rather than distorting it.
const WINDOW_SCALE := 2

var _music_player: MusicPlayer
var _sfx_player: SfxPlayer
var _input_router: InputRouter
var _app_lifecycle: AppLifecycle
var _screen_container: Node
var _current_screen: Node

## TASK-016.02: the level LevelPickerScreen last selected (JumpnbumpAssetLoader
## .load_dat() payload, already validated), or {} for the built-in level.
## Owned here, not by MenuScreen, so it survives MenuScreen being swapped
## out and back in (e.g. after a match ends and the player returns to menu).
var _selected_level_payload: Dictionary = {}
var _selected_level_name := "Built-in Level"


## Pure function (no Window/DisplayServer access) so window-sizing math is
## unit-testable without a live window, matching neo_snake's
## GameScreen._ready() pattern of deriving window size from the design size
## and the current screen's display scale rather than hardcoding it in
## project.godot.
static func compute_window_size(design_size: Vector2i, scale: int, display_scale: float) -> Vector2i:
	return Vector2i(Vector2(design_size * scale) * display_scale)


func _apply_window_size() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var display_scale := DisplayServer.screen_get_scale(screen)
	get_window().size = compute_window_size(DESIGN_SIZE, WINDOW_SCALE, display_scale)


func _ready() -> void:
	_apply_window_size()

	_sfx_player = SfxPlayer.new()
	_sfx_player.name = "SfxPlayer"
	add_child(_sfx_player)

	_music_player = MusicPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)

	var audio_settings := AudioSettings.new()
	AudioSettings.apply_to_audio_server(audio_settings.load_or_default())
	GameSettings.apply_to_audio_server(GameSettings.new().load_or_default())

	# Stops music before the app actually quits (TASK-014.06 AC#4), no
	# matter which screen is showing when the close request arrives --
	# added as a child, not called directly, so _notification receives the
	# real NOTIFICATION_WM_CLOSE_REQUEST the engine delivers to nodes.
	_app_lifecycle = AppLifecycle.new(Callable(_music_player, "stop"))
	_app_lifecycle.name = "AppLifecycle"
	add_child(_app_lifecycle)

	_input_router = InputRouter.new()
	_input_router.name = "InputRouter"
	add_child(_input_router)

	_screen_container = Node.new()
	_screen_container.name = "ScreenContainer"
	add_child(_screen_container)

	_show_title()
	_maybe_drive_capture_state()


## Visual-capture tooling only (TASK-016.02 follow-up, mirroring neo_snake's
## game_screen.gd _maybe_drive_capture_state()/decision-025): real OS-level
## key/mouse injection via wtype into a live Godot window under headless
## sway does not reach Godot's input handling reliably, so
## tools/capture_level_picker.sh drives screen transitions straight through
## these already-tested methods instead of simulating clicks. Guarded
## behind an explicit --capture-state= CLI user-arg normal play never
## passes -- inert for every real launch.
func _maybe_drive_capture_state() -> void:
	var state := _capture_state_arg()
	match state:
		"", "title":
			return
		"menu":
			_show_menu()
		"level_picker":
			_show_menu()
			_show_level_picker()
		"level_picker_error":
			_show_menu()
			_show_level_picker()
			var picker := _current_screen as LevelPickerScreen
			picker._try_select(_write_capture_corrupt_dat())
		"gameplay_builtin":
			_show_menu()
			_start_match(0)
		"gameplay_custom":
			_show_menu()
			var game_dir: String = ProjectSettings.globalize_path("res://").rstrip("/")
			var dat_path := game_dir.get_base_dir().path_join("data/jumpbump.dat")
			_selected_level_payload = JumpnbumpAssetLoader.load_dat(dat_path)
			_selected_level_name = "jumpbump.dat"
			_start_match(0)


func _capture_state_arg() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-state="):
			return arg.substr("--capture-state=".length())
	return ""


## A truncated .dat (claims one entry, supplies no directory table) --
## same fixture shape as test_asset_loader.gd's and test_level_picker_screen.gd's
## corrupt-archive tests, built fresh here so the capture harness exercises
## the real JumpnbumpAssetLoader -> LevelValidator -> error-label path
## rather than a hardcoded string.
func _write_capture_corrupt_dat() -> String:
	var path := "user://capture_corrupt.dat"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_32(1)
	file.close()
	return ProjectSettings.globalize_path(path)


func _swap_screen(screen: Node) -> void:
	if _current_screen != null:
		_current_screen.queue_free()
	_current_screen = screen
	_screen_container.add_child(screen)


func _show_title() -> void:
	_music_player.play("menu")
	var title := TitleScreen.new()
	title.name = "TitleScreen"
	title.start_requested.connect(_show_menu)
	_swap_screen(title)


func _show_menu() -> void:
	_music_player.play("menu")
	var menu := MenuScreen.new()
	menu.name = "MenuScreen"
	menu.set_input_router(_input_router)
	menu.set_level_name(_selected_level_name)
	menu.start_requested.connect(_start_match)
	menu.level_picker_requested.connect(_show_level_picker)
	_swap_screen(menu)


func _show_level_picker() -> void:
	var picker := LevelPickerScreen.new()
	picker.name = "LevelPickerScreen"
	picker.level_selected.connect(_on_level_selected)
	picker.closed.connect(_show_menu)
	_swap_screen(picker)


func _on_level_selected(payload: Dictionary, display_name: String) -> void:
	_selected_level_payload = payload
	_selected_level_name = display_name
	_show_menu()


func _start_match(ai_mask: int) -> void:
	var settings := GameSettings.new().load_or_default()
	_music_player.play("game")

	var gameplay := GameplayScreen.new()
	gameplay.name = "GameplayScreen"
	gameplay.match_ended.connect(_show_scores)
	_swap_screen(gameplay)
	gameplay.start(
		{
			"seed": 1,
			"flies_enabled": settings["flies_enabled"],
			"level_bytes": SAMPLE_LEVEL_TEXT.to_utf8_buffer(),
			"player_count": settings["player_count"],
			"ai_mask": ai_mask,
			"no_gore": GameSettings.no_gore(settings),
			"mirror_enabled": settings["mirror_enabled"],
			"design_width": DESIGN_SIZE.x,
			"custom_level": _selected_level_payload,
		},
		_sfx_player,
		_input_router,
	)


func _show_scores(final_bumps: Array, enabled_slots: Array) -> void:
	_music_player.play("scores")
	var scores := ScoresScreen.new(final_bumps, enabled_slots)
	scores.name = "ScoresScreen"
	scores.continue_requested.connect(_show_menu)
	_swap_screen(scores)
