class_name MusicPlayer
extends Node

## Plays the offline-rendered OGG tracks committed at
## game/content/audio/music/*.ogg (TASK-013.03, tools/render_music.py),
## looping continuously once started -- matching main.c's own dj_load_mod/
## dj_play_mod usage (loaded once at startup, looped for the life of the
## screen it belongs to). Single AudioStreamPlayer on the "Music" bus
## (neo_snake's Master -> Music/SFX/UI bus layout, TASK-014.06).
##
## Track name -> asset mirrors main.c:3340-3363's own three MOD_* contexts:
## MOD_MENU=jump.mod, MOD_GAME=bump.mod, MOD_SCORES=scores.mod. Only "game"
## is driven today -- Main is the gameplay scene directly, with no menu/
## scoreboard screen flow yet (that lands with TASK-015.04).
const TRACKS := {
	"menu": "res://content/audio/music/jump.ogg",
	"game": "res://content/audio/music/bump.ogg",
	"scores": "res://content/audio/music/scores.ogg",
}

var _player: AudioStreamPlayer
var _current_track := ""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	add_child(_player)


## Loads (if not already loaded) and plays `track` looped. Switching tracks
## mid-play stops the previous one first; re-requesting the already-playing
## track is a no-op, matching main.c never restarting a mod it already has
## loaded and playing.
func play(track: String) -> void:
	if track == _current_track and _player.playing:
		return
	var path: String = TRACKS.get(track, "")
	if path == "":
		push_error("MusicPlayer: unknown track %s" % track)
		return
	if not ResourceLoader.exists(path):
		push_error("MusicPlayer: missing %s" % path)
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_player.stream = stream
	_current_track = track
	_player.play()


func stop() -> void:
	_player.stop()
	_current_track = ""


func is_playing() -> bool:
	return _player.playing
