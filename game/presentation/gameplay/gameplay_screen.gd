class_name GameplayScreen
extends Node2D

## Owns one match: the SimWorld, its renderers, and the pause/resume/
## end-match flow (TASK-015.04). Pause gates TickDriver, not the core
## (tick_driver.gd's own contract) -- _gate flips false while
## _pause_overlay is up, discarding that span of frames outright rather
## than banking them, exactly like the menu/scoreboard gate already did
## before this task.

signal match_ended(final_bumps: Array, enabled_slots: Array)

const LEVEL_BACKGROUND := "res://content/levels/level_background.png"
const LEVEL_FOREGROUND := "res://content/levels/level_foreground.png"
const EVENT_DRAIN_CAPACITY := 256
const MAX_PLAYERS := 4

var _world: SimWorld
var _gate := false
var _paused := false
var _sprite_renderer: SpriteRenderer
var _scoreboard_renderer: ScoreboardRenderer
var _sfx_player: SfxPlayer
var _input_router: InputRouter
var _pause_overlay: PauseOverlay
var _level_layers: Node2D


## config: {seed, flies_enabled, level_bytes, player_count, ai_mask,
## no_gore, mirror_enabled}. sfx_player/input_router are owned by
## whichever screen controller assembles GameplayScreen (Main) and outlive
## it, so they're injected rather than created here.
func start(config: Dictionary, sfx_player: SfxPlayer, input_router: InputRouter) -> void:
	_sfx_player = sfx_player
	_input_router = input_router
	_input_router.input_updated.connect(_on_input_updated)

	_world = SimWorld.new()
	var result := _world.init(
		config.get("seed", 1),
		config.get("flies_enabled", true),
		config["level_bytes"],
		config.get("player_count", 4),
		config.get("ai_mask", 0),
		config.get("no_gore", false),
	)
	_gate = result == SimWorld.OK

	_level_layers = Node2D.new()
	_level_layers.name = "LevelLayers"
	_level_layers.transform = GameSettings.mirror_transform(config.get("mirror_enabled", false), config.get("design_width", 400))
	add_child(_level_layers)

	var background := Sprite2D.new()
	background.name = "Background"
	background.centered = false
	background.texture = load(LEVEL_BACKGROUND)
	_level_layers.add_child(background)

	_sprite_renderer = SpriteRenderer.new()
	_sprite_renderer.name = "SpriteRenderer"
	_level_layers.add_child(_sprite_renderer)
	_sprite_renderer.setup(_world)

	var foreground := Sprite2D.new()
	foreground.name = "Foreground"
	foreground.centered = false
	foreground.texture = load(LEVEL_FOREGROUND)
	_level_layers.add_child(foreground)

	_scoreboard_renderer = ScoreboardRenderer.new()
	_scoreboard_renderer.name = "ScoreboardRenderer"
	add_child(_scoreboard_renderer)
	_scoreboard_renderer.setup(_world)


func _process(delta: float) -> void:
	if _world == null:
		return
	if _pause_overlay == null and Input.is_action_just_pressed("ui_cancel"):
		pause()
		return
	if _paused:
		return
	TickDriver.advance_frame(_world, delta * 1000.0, true, _gate, _left, _right, _jump)
	_drain_audio_events()


var _left := 0
var _right := 0
var _jump := 0


func _on_input_updated(left: int, right: int, jump: int) -> void:
	_left = left
	_right = right
	_jump = jump


func is_paused() -> bool:
	return _paused


## Public (not just the ui_cancel handler above) so a pause menu button
## elsewhere, or a test, can trigger the same freeze without synthesizing
## an input event -- headless test runs can't deliver those at all
## (gdUnit4's own "InputEvents ... have no effect" headless warning).
func pause() -> void:
	if _paused:
		return
	_paused = true
	_pause_overlay = PauseOverlay.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.resume_requested.connect(resume)
	_pause_overlay.end_match_requested.connect(end_match)
	add_child(_pause_overlay)


func resume() -> void:
	if not _paused:
		return
	remove_child(_pause_overlay)
	_pause_overlay.queue_free()
	_pause_overlay = null
	_paused = false


func end_match() -> void:
	var final_bumps := []
	var enabled_slots := []
	for slot in MAX_PLAYERS:
		var view := _world.player_view_get(slot)
		var enabled: bool = view.get("enabled", false)
		enabled_slots.append(enabled)
		final_bumps.append(int(view.get("bumps", 0)) if enabled else 0)
	match_ended.emit(final_bumps, enabled_slots)


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
