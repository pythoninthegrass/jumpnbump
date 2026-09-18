class_name Main
extends Node

## Composition root (TASK-014.01): main.tscn holds only this script on a
## single Node. Every other node the game needs is assembled here in
## _ready() rather than hand-built into the scene, matching neo_snake's
## GameScreen convention -- subsequent TASK-014.* subtasks add the actual
## renderer/audio children. TASK-014.02 wires the sim itself: a SimWorld
## driven each frame by TickDriver, gated on/off without touching the core.
##
## Placeholder init: no level-loading UI or content-driven level selection
## exists yet (that lands with TASK-014.04/016), so this seeds a hardcoded
## sample level purely so the sim has something to tick against.
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

## Level layer paths: TASK-014.04 composites the "level" pair from
## game/content/levels/manifest.json (TASK-013.02) at the original 400x256
## design resolution. Real level selection (menu vs. level, custom .dat
## levels) is TASK-016's job; this hardcodes the "level" entry.
const LEVEL_BACKGROUND := "res://content/levels/level_background.png"
const LEVEL_FOREGROUND := "res://content/levels/level_foreground.png"

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

## Drained events are read back at most this many per frame; comfortably
## above core/game_loop.zig's own max_events_per_tick times a worst-case
## catch-up tick count for a single _process() call.
const EVENT_DRAIN_CAPACITY := 256

var _world: SimWorld
var _gate := false
var _sprite_renderer: SpriteRenderer
var _scoreboard_renderer: ScoreboardRenderer
var _sfx_player: SfxPlayer
var _music_player: MusicPlayer
var _app_lifecycle: AppLifecycle
var _audio_settings: AudioSettings


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

	_world = SimWorld.new()
	var result := _world.init(1, false, SAMPLE_LEVEL_TEXT.to_utf8_buffer())
	_gate = result == SimWorld.OK

	# Child order is the draw order (CanvasItem default): background first,
	# sprites in the middle, masked foreground last/on top (AC#2).
	var background := Sprite2D.new()
	background.name = "Background"
	background.centered = false
	background.texture = load(LEVEL_BACKGROUND)
	add_child(background)

	_sprite_renderer = SpriteRenderer.new()
	_sprite_renderer.name = "SpriteRenderer"
	add_child(_sprite_renderer)
	_sprite_renderer.setup(_world)

	var foreground := Sprite2D.new()
	foreground.name = "Foreground"
	foreground.centered = false
	foreground.texture = load(LEVEL_FOREGROUND)
	add_child(foreground)

	# Scoreboard draws last (on top of the masked foreground) since it's HUD
	# text/digits, not part of the level's own layering (TASK-014.05).
	_scoreboard_renderer = ScoreboardRenderer.new()
	_scoreboard_renderer.name = "ScoreboardRenderer"
	add_child(_scoreboard_renderer)
	_scoreboard_renderer.setup(_world)

	_sfx_player = SfxPlayer.new()
	_sfx_player.name = "SfxPlayer"
	add_child(_sfx_player)

	_music_player = MusicPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)
	_music_player.play("game")

	_audio_settings = AudioSettings.new()
	AudioSettings.apply_to_audio_server(_audio_settings.load_or_default())

	# Stops music before the app actually quits (TASK-014.06 AC#4) --
	# added as a child, not called directly, so _notification receives the
	# real NOTIFICATION_WM_CLOSE_REQUEST the engine delivers to nodes.
	_app_lifecycle = AppLifecycle.new(Callable(_music_player, "stop"))
	_app_lifecycle.name = "AppLifecycle"
	add_child(_app_lifecycle)


func _process(delta: float) -> void:
	if _world == null:
		return
	TickDriver.advance_frame(_world, delta * 1000.0, true, _gate)
	_drain_audio_events()


## Draining once per frame (not per tick) is what makes SfxEventCoalescer's
## per-frame dedup (AC#3) actually apply: a hitch that runs several ticks
## inside one TickDriver.advance_frame call above still only reaches this
## drain-and-play step once.
func _drain_audio_events() -> void:
	var drain: Dictionary = _world.event_drain(EVENT_DRAIN_CAPACITY)
	if drain.get("result", -1) != SimWorld.OK:
		return
	var events: Array = drain.get("events", [])
	for cue in SfxEventCoalescer.cues_for(events):
		_sfx_player.play(cue)
	var fly_events := SfxEventCoalescer.fly_volume_events_in(events)
	if not fly_events.is_empty():
		_sfx_player.apply_fly_volume(fly_events[-1]["volume"])
