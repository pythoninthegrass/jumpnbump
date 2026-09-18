class_name AudioSettings
extends RefCounted

## Persists per-bus volume (dB) to disk with an injected base directory
## (tests point it at a temp dir instead of the real user:// profile),
## mirroring neo_snake's SaveStore atomic tmp->dst write. Scoped to just
## the audio-bus volume this task needs (TASK-014.06 AC#2) rather than a
## full settings/save schema -- that's TASK-015.03's job once it lands.

const FILE_NAME := "audio_settings.json"
const BUSES := ["Master", "Music", "SFX", "UI"]

var _base_dir: String

func _init(base_dir: String = "user://") -> void:
	_base_dir = base_dir


func _path() -> String:
	return _base_dir.path_join(FILE_NAME)


static func _defaults() -> Dictionary:
	var volume_db := {}
	for bus in BUSES:
		volume_db[bus] = 0.0
	return volume_db


## Reads the on-disk volume-db map, filling in any missing/invalid bus with
## 0.0 dB (unity gain) rather than leaving a caller to guess.
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
	for bus in BUSES:
		out[bus] = float(parsed[bus]) if parsed.has(bus) else defaults[bus]
	return out


## Atomic tmp -> dst rename so a crash mid-write never leaves a truncated
## file behind for the next load_or_default() to choke on.
func save(volume_db: Dictionary) -> Error:
	if not DirAccess.dir_exists_absolute(_base_dir):
		var err := DirAccess.make_dir_recursive_absolute(_base_dir)
		if err != OK:
			return err
	var tmp_path := _path() + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(volume_db, "\t"))
	file.close()
	return DirAccess.rename_absolute(tmp_path, _path())


## Applies a loaded/edited volume-db map to the live AudioServer buses.
static func apply_to_audio_server(volume_db: Dictionary) -> void:
	for bus: String in volume_db:
		var idx := AudioServer.get_bus_index(bus)
		if idx != -1:
			AudioServer.set_bus_volume_db(idx, float(volume_db[bus]))


## Reads the live AudioServer bus volumes back into a volume-db map, for a
## caller to hand to save() after the player adjusts a slider.
static func read_from_audio_server() -> Dictionary:
	var out := {}
	for bus in BUSES:
		var idx := AudioServer.get_bus_index(bus)
		out[bus] = AudioServer.get_bus_volume_db(idx) if idx != -1 else 0.0
	return out
