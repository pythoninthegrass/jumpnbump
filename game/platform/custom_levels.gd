class_name CustomLevels
extends RefCounted

## Persists a most-recently-used list of successfully-loaded custom .dat
## paths (TASK-016.02 AC#3), mirroring GameSettings.gd's injected-base-dir /
## atomic tmp->dst JSON save so tests use a temp dir instead of the real
## user:// profile.

const FILE_NAME := "custom_levels.json"
const MAX_ENTRIES := 10

var _base_dir: String

func _init(base_dir: String = "user://") -> void:
	_base_dir = base_dir


func _path() -> String:
	return _base_dir.path_join(FILE_NAME)


## Entries are {"path": String, "name": String}, most-recently-used first.
## Entries whose path no longer exists on disk are silently dropped -- a
## custom level file the player deleted or moved just disappears from the
## list rather than surfacing as another error state.
func list() -> Array:
	if not FileAccess.file_exists(_path()):
		return []
	var file := FileAccess.open(_path(), FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return []
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_ARRAY:
		return []
	var out := []
	for entry in parsed:
		if typeof(entry) == TYPE_DICTIONARY and entry.has("path") and entry.has("name") and FileAccess.file_exists(entry["path"]):
			out.append({"path": entry["path"], "name": entry["name"]})
	return out


## Moves `path` (or inserts it) to the front of the list, capped at
## MAX_ENTRIES. Re-adding an already-listed path just re-orders it rather
## than duplicating it.
func add_recent(path: String, display_name: String) -> Error:
	var entries := list()
	entries = entries.filter(func(entry: Dictionary) -> bool: return entry["path"] != path)
	entries.push_front({"path": path, "name": display_name})
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	return _save(entries)


func _save(entries: Array) -> Error:
	if not DirAccess.dir_exists_absolute(_base_dir):
		var err := DirAccess.make_dir_recursive_absolute(_base_dir)
		if err != OK:
			return err
	var tmp_path := _path() + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(entries, "\t"))
	file.close()
	return DirAccess.rename_absolute(tmp_path, _path())
