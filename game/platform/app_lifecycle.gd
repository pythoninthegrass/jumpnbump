class_name AppLifecycle
extends Node

## Ports main.c's dj_deinit()-on-exit path (SDL_mixer/dj_* teardown before
## the process ends) onto Godot's MainLoop notification: stops music before
## the app actually quits so no Ogg playback object leaks past shutdown
## (TASK-014.06 AC#4, the neo_snake gotcha named in the task description --
## see ~/git/neo_snake/game/presentation/screens/game_screen.gd's own
## NOTIFICATION_WM_CLOSE_REQUEST handler for the same pattern).
##
## on_quit is a Callable rather than a hardcoded MusicPlayer reference so
## this stays test-constructible without a live scene tree.

var _on_quit: Callable
var quit_requested := false

func _init(on_quit: Callable = Callable()) -> void:
	_on_quit = on_quit


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_requested = true
		if _on_quit.is_valid():
			_on_quit.call()
		# get_tree() errors on a node under test that was never added to a
		# live SceneTree (game/tests/test_audio.gd exercises this method
		# directly, the same way neo_snake's test_app_lifecycle.gd does) --
		# is_inside_tree() guards that without provoking the error.
		if is_inside_tree():
			get_tree().quit()
