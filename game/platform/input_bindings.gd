class_name InputBindings
extends RefCounted

## Persists per-player keybindings to disk with an injected base directory
## (tests point it at a temp dir instead of the real user:// profile),
## mirroring AudioSettings' atomic tmp->dst write (TASK-015.01).
##
## Rebind-persistence gotcha (neo_snake): load_or_default() prefers a save
## file over DEFAULT_BINDINGS whenever one exists. On any machine that
## already has a save file, changing DEFAULT_BINDINGS below has zero
## effect until the player rebinds again or the save file is deleted --
## the save file always wins once it exists.

const FILE_NAME := "input_bindings.json"

## Matches globals.pre's USE_SDL KEY_PLn_LEFT/RIGHT/JUMP scheme: P1 arrows,
## P2 WASD, P3 IJL, P4 numpad 4/6/8. Jump doubles as "up" -- the original
## has no separate up key.
const DEFAULT_BINDINGS := [
	{"left": KEY_LEFT, "right": KEY_RIGHT, "jump": KEY_UP},
	{"left": KEY_A, "right": KEY_D, "jump": KEY_W},
	{"left": KEY_J, "right": KEY_L, "jump": KEY_I},
	{"left": KEY_KP_4, "right": KEY_KP_6, "jump": KEY_KP_8},
]

const ACTIONS := ["left", "right", "jump"]

var _base_dir: String

func _init(base_dir: String = "user://") -> void:
	_base_dir = base_dir


func _path() -> String:
	return _base_dir.path_join(FILE_NAME)


static func _defaults() -> Array:
	return DEFAULT_BINDINGS.duplicate(true)


## Reads the on-disk per-player keybind array, filling in any missing or
## invalid player/action with the matching default rather than leaving a
## caller to guess.
func load_or_default() -> Array:
	var defaults := _defaults()
	if not FileAccess.file_exists(_path()):
		return defaults
	var file := FileAccess.open(_path(), FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return defaults
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_ARRAY:
		return defaults
	var out := []
	for i in defaults.size():
		var player_default: Dictionary = defaults[i]
		var player_saved: Variant = parsed[i] if i < parsed.size() else null
		var player_out := {}
		for action in ACTIONS:
			if typeof(player_saved) == TYPE_DICTIONARY and player_saved.has(action):
				player_out[action] = int(player_saved[action])
			else:
				player_out[action] = player_default[action]
		out.append(player_out)
	return out


## Atomic tmp -> dst rename so a crash mid-write never leaves a truncated
## file behind for the next load_or_default() to choke on.
func save(bindings: Array) -> Error:
	if not DirAccess.dir_exists_absolute(_base_dir):
		var err := DirAccess.make_dir_recursive_absolute(_base_dir)
		if err != OK:
			return err
	var tmp_path := _path() + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(bindings, "\t"))
	file.close()
	return DirAccess.rename_absolute(tmp_path, _path())
