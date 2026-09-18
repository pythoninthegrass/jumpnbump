class_name SfxPlayer
extends Node

## Plays the five offline-rendered WAV cues committed at
## game/content/audio/sfx/*.wav (TASK-013.03, tools/render_sfx.py). One
## AudioStreamPlayer per cue (neo_snake's SfxPlayer convention): these are
## all short one-shot cues, so retriggering an already-playing cue just
## restarts it -- no pooling/polyphony needed at this scale. "fly" is the
## one exception -- see FLY_CUE below.
##
## Lives entirely in presentation (Main owns one, wires play() calls off
## SfxEventCoalescer.cues_for) -- core/*.zig never references audio in any
## form, per docs/porting-playbook.md's core-purity rule
## (tools/validate_simulation_boundary.py's AUDIO_NAMES denylist).

const SFX_DIR := "res://content/audio/sfx/"

## main.c's four one-shot dj_play_sfx cues that reach a corresponding
## core/game_loop.zig sfx event (jump/spring/splash via core/steer.zig,
## death via core/collision.zig -- see event_coalescer.gd's id-disambiguation
## comment). All route to the "SFX" bus.
const ONE_SHOT_CUES: Array[String] = ["jump", "spring", "splash", "death"]

## The fly swarm's buzz (main.c channel 4): a *looping* cue whose volume is
## driven every frame from core/flies.zig's JNB_EVENT_SFX_VOLUME payload
## (event_coalescer.gd's fly_volume_events_in), not a one-shot play() call --
## see event_coalescer.gd's FLY_CHANNEL comment for why there is no
## corresponding one-shot "fly" trigger to fire from the event stream.
const FLY_CUE := "fly"

var _players := {}
var _fly_player: AudioStreamPlayer


func _ready() -> void:
	for cue in ONE_SHOT_CUES:
		_players[cue] = _make_player(cue, false)
	_fly_player = _make_player(FLY_CUE, true)


func _make_player(cue: String, loop: bool) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var path := "%s%s.wav" % [SFX_DIR, cue]
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		if loop and stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = stream.data.size()
		player.stream = stream
	else:
		push_error("SfxPlayer: missing cue %s" % path)
	player.bus = "SFX"
	add_child(player)
	return player


func play(cue: String) -> void:
	var player: AudioStreamPlayer = _players.get(cue)
	if player != null and player.stream != null:
		player.play()


## Starts the fly-swarm loop (idempotently) and sets its volume from the
## core's 0..64 channel-volume scale (main.c's dj_set_sfx_channel_volume
## range), converted to dB. A volume of 0 stops the loop outright rather
## than fading an AudioStreamPlayer to silence while still consuming a
## voice, matching main.c's dj_stop_sfx_channel(4) intent at swarm teardown.
func apply_fly_volume(volume_0_to_64: int) -> void:
	if _fly_player.stream == null:
		return
	if volume_0_to_64 <= 0:
		if _fly_player.playing:
			_fly_player.stop()
		return
	var clamped: float = clampf(float(volume_0_to_64) / 64.0, 0.0, 1.0)
	_fly_player.volume_db = linear_to_db(clamped)
	if not _fly_player.playing:
		_fly_player.play()
