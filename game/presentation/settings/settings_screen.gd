class_name SettingsScreen
extends Control

## In-game settings UI for TASK-015.03: surfaces the original CLI-flag
## options (-nosound, -musicnosound, -nogore, -noflies, -mirror, player
## count) as toggles/a stepper, persisted immediately on every change via
## GameSettings. Deliberately has no -scaleup/-fullscreen/-mouse
## equivalents (AC#3) -- Godot's own display handling and gamepad support
## supersede them.

signal closed(settings: Dictionary)

const TOGGLE_KEYS := ["sound_enabled", "music_enabled", "gore_enabled", "flies_enabled", "mirror_enabled"]
const TOGGLE_LABELS := {
	"sound_enabled": "SOUND",
	"music_enabled": "MUSIC",
	"gore_enabled": "GORE",
	"flies_enabled": "FLIES",
	"mirror_enabled": "MIRROR",
}

var settings: Dictionary

var _base_dir: String
var _store: GameSettings
var _toggle_buttons: Dictionary = {}
var _player_count_label: Label


func _init(base_dir: String = "user://") -> void:
	_base_dir = base_dir


func _ready() -> void:
	_store = GameSettings.new(_base_dir)
	settings = _store.load_or_default()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	add_child(rows)

	for key in TOGGLE_KEYS:
		rows.add_child(_build_toggle_row(key))
	rows.add_child(_build_player_count_row())

	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "Back"
	back_button.pressed.connect(_on_back_pressed)
	rows.add_child(back_button)
	back_button.grab_focus()


func _build_toggle_row(key: String) -> Control:
	var row := HBoxContainer.new()
	row.name = key

	var label := Label.new()
	label.name = "Label"
	label.text = TOGGLE_LABELS[key]
	row.add_child(label)

	var button := Button.new()
	button.name = "ToggleButton"
	button.text = _toggle_text(key)
	button.pressed.connect(_on_toggle_pressed.bind(key))
	row.add_child(button)
	_toggle_buttons[key] = button

	return row


func _toggle_text(key: String) -> String:
	return "ON" if settings.get(key, true) else "OFF"


func _on_toggle_pressed(key: String) -> void:
	settings[key] = not settings.get(key, true)
	_toggle_buttons[key].text = _toggle_text(key)
	_store.save(settings)


func _build_player_count_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "player_count"

	var label := Label.new()
	label.name = "Label"
	label.text = "PLAYERS"
	row.add_child(label)

	var dec := Button.new()
	dec.name = "DecrementButton"
	dec.text = "-"
	dec.pressed.connect(_on_player_count_delta.bind(-1))
	row.add_child(dec)

	_player_count_label = Label.new()
	_player_count_label.name = "PlayerCountLabel"
	_player_count_label.text = str(settings["player_count"])
	row.add_child(_player_count_label)

	var inc := Button.new()
	inc.name = "IncrementButton"
	inc.text = "+"
	inc.pressed.connect(_on_player_count_delta.bind(1))
	row.add_child(inc)

	return row


func _on_player_count_delta(delta: int) -> void:
	settings["player_count"] = clampi(int(settings["player_count"]) + delta, GameSettings.MIN_PLAYER_COUNT, GameSettings.MAX_PLAYER_COUNT)
	_player_count_label.text = str(settings["player_count"])
	_store.save(settings)


func _on_back_pressed() -> void:
	closed.emit(settings)
