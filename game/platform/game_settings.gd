class_name GameSettings
extends RefCounted

## Persists the original CLI-flag-controlled options that TASK-015.03
## promotes to an in-game settings UI, with an injected base directory
## (tests point it at a temp dir instead of the real user:// profile),
## mirroring AudioSettings' atomic tmp->dst write.
##
## -scaleup, -fullscreen, and -mouse are deliberately NOT surfaced here or
## anywhere in the settings UI: Godot's own display handling (canvas_items
## stretch, window resizing) and gamepad support supersede them (AC#3).

const FILE_NAME := "game_settings.json"

const DEFAULTS := {
	"sound_enabled": true,   # inverse of main.c's -nosound
	"music_enabled": true,   # inverse of -musicnosound
	"gore_enabled": true,    # inverse of jnb_config.no_gore / -nogore
	"flies_enabled": true,   # jnb_config.flies_enabled / inverse of -noflies
	"mirror_enabled": false, # main.c's -mirror (flip)
	"player_count": 4,       # jnb_config.player_count, 1..JNB_MAX_PLAYERS
}

const MIN_PLAYER_COUNT := 1
const MAX_PLAYER_COUNT := 4

var _base_dir: String

func _init(base_dir: String = "user://") -> void:
	_base_dir = base_dir


func _path() -> String:
	return _base_dir.path_join(FILE_NAME)


static func _defaults() -> Dictionary:
	return DEFAULTS.duplicate()


## Reads the on-disk settings map, filling in any missing/invalid key with
## its default rather than leaving a caller to guess. player_count is
## clamped to [MIN_PLAYER_COUNT, MAX_PLAYER_COUNT].
func load_or_default() -> Dictionary:
	var defaults := _defaults()
	if not FileAccess.file_exists(_path()):
		return defaults
	var file := FileAccess.open(_path(), FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return defaults
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return defaults
	var out := {}
	for key in defaults:
		out[key] = parsed[key] if parsed.has(key) else defaults[key]
	out["player_count"] = clampi(int(out["player_count"]), MIN_PLAYER_COUNT, MAX_PLAYER_COUNT)
	return out


## Atomic tmp -> dst rename so a crash mid-write never leaves a truncated
## file behind for the next load_or_default() to choke on.
func save(settings: Dictionary) -> Error:
	if not DirAccess.dir_exists_absolute(_base_dir):
		var err := DirAccess.make_dir_recursive_absolute(_base_dir)
		if err != OK:
			return err
	var tmp_path := _path() + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(settings, "\t"))
	file.close()
	return DirAccess.rename_absolute(tmp_path, _path())


## Mutes the SFX/Music buses per sound_enabled/music_enabled -- separate
## from AudioSettings' per-bus dB level, which stays whatever the player
## last set independent of this on/off switch.
static func apply_to_audio_server(settings: Dictionary) -> void:
	_set_bus_mute("SFX", not settings.get("sound_enabled", true))
	_set_bus_mute("Music", not settings.get("music_enabled", true))


static func _set_bus_mute(bus: String, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx != -1:
		AudioServer.set_bus_mute(idx, muted)


## jnb_config's fields these settings feed directly: SimWorld.init's
## flies_enabled/player_count/player_ai_mask/no_gore params.
static func no_gore(settings: Dictionary) -> bool:
	return not settings.get("gore_enabled", true)


## Pure horizontal-flip transform for main.c's -mirror: flips `node`
## (expected to be the level-layers/sprite container, not HUD text) about
## the design width's center. Left to whichever screen actually owns that
## container to call (TASK-015.04's match flow) -- kept here, and pure,
## so it's unit-testable without a live scene tree.
static func mirror_transform(mirror_enabled: bool, design_width: int) -> Transform2D:
	if not mirror_enabled:
		return Transform2D.IDENTITY
	return Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2(design_width, 0))
