class_name LevelPickerScreen
extends Control

## TASK-016.02: select a custom .dat level via an in-game list, a native
## file browser, or OS-level drag-and-drop onto the game window, with
## validation that reports a clear error instead of crashing on a malformed
## file. Mirrors MenuScreen/SettingsScreen's build-in-_ready() Control
## structure and SettingsScreen's injected-base-dir convention (tests point
## CustomLevels at a temp dir instead of the real user:// profile).

## payload is JumpnbumpAssetLoader.load_dat()'s result Dictionary, or {}
## for the built-in level.
signal level_selected(payload: Dictionary, display_name: String)
signal closed()

const BUILT_IN_LABEL := "Built-in Level"
const DAT_FILTER := "*.dat ; Jump'n'Bump Level"

var _base_dir: String
var _custom_levels: CustomLevels
var _recent_rows: VBoxContainer
var _error_label: Label
var _file_dialog: FileDialog


func _init(base_dir: String = "user://") -> void:
	_base_dir = base_dir


func _ready() -> void:
	_custom_levels = CustomLevels.new(_base_dir)
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	add_child(rows)

	var built_in_button := Button.new()
	built_in_button.name = "BuiltInButton"
	built_in_button.text = BUILT_IN_LABEL
	built_in_button.pressed.connect(_on_built_in_pressed)
	rows.add_child(built_in_button)

	_recent_rows = VBoxContainer.new()
	_recent_rows.name = "RecentRows"
	rows.add_child(_recent_rows)
	_refresh_recent_rows()

	var browse_button := Button.new()
	browse_button.name = "BrowseButton"
	browse_button.text = "Browse..."
	browse_button.pressed.connect(_on_browse_pressed)
	rows.add_child(browse_button)

	_error_label = Label.new()
	_error_label.name = "ErrorLabel"
	_error_label.visible = false
	rows.add_child(_error_label)

	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "Back"
	back_button.pressed.connect(_on_back_pressed)
	rows.add_child(back_button)

	_file_dialog = FileDialog.new()
	_file_dialog.name = "FileDialog"
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.add_filter(DAT_FILTER)
	_file_dialog.file_selected.connect(_try_select)
	add_child(_file_dialog)

	built_in_button.grab_focus()

	if is_inside_tree() and get_window() != null:
		get_window().files_dropped.connect(_on_files_dropped)


func _exit_tree() -> void:
	if is_inside_tree() and get_window() != null and get_window().files_dropped.is_connected(_on_files_dropped):
		get_window().files_dropped.disconnect(_on_files_dropped)


func _refresh_recent_rows() -> void:
	for child in _recent_rows.get_children():
		child.queue_free()
	var entries := _custom_levels.list()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var button := Button.new()
		button.name = "RecentButton%d" % i
		button.text = entry["name"]
		button.pressed.connect(_try_select.bind(entry["path"]))
		_recent_rows.add_child(button)


func _on_built_in_pressed() -> void:
	_hide_error()
	level_selected.emit({}, BUILT_IN_LABEL)


func _on_browse_pressed() -> void:
	_file_dialog.popup_centered_ratio()


## `paths` is whatever files the OS reports were dropped onto the window at
## once; only the first one ending in ".dat" (case-insensitive) is used, so
## dropping an unrelated file (or several) doesn't silently pick one at
## random.
func _on_files_dropped(paths: PackedStringArray) -> void:
	for path in paths:
		if path.get_extension().to_lower() == "dat":
			_try_select(path)
			return
	_show_error("Drop a .dat level file.")


func _try_select(path: String) -> void:
	var result: Dictionary = JumpnbumpAssetLoader.load_dat(path)
	var validation: Dictionary = LevelValidator.validate(result)
	if not validation["ok"]:
		_show_error(validation["error"])
		return

	_hide_error()
	var display_name := path.get_file()
	_custom_levels.add_recent(path, display_name)
	_refresh_recent_rows()
	level_selected.emit(result, display_name)


func _show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true


func _hide_error() -> void:
	_error_label.visible = false


func _on_back_pressed() -> void:
	closed.emit()
