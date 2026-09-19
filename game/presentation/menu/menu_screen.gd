class_name MenuScreen
extends Control

## Ports menu.c's menu.pcx backdrop as the visual layout (TASK-015.02).
## menu.c itself turned out to hold only the DOS attract-mode title
## screen (a scripted rabbit walk-in + credits scroll, no player-select
## UI at all) -- there is no legacy colour/AI/key-assignment screen to
## port pixel-for-pixel, so that interaction model is net-new here,
## built with real Control nodes (Buttons/Labels) laid over the original
## backdrop rather than raw mouse-click hit regions (main.c had none of
## those either). Godot's Control base class handles keyboard/gamepad
## ui_up/ui_down/ui_left/ui_right/ui_accept focus traversal automatically
## for any focusable node (Buttons default to FOCUS_ALL) -- AC#4 needs no
## extra wiring beyond grabbing initial focus.

signal start_requested(ai_mask: int)

const BACKGROUND := "res://content/levels/menu_background.png"
const FOREGROUND := "res://content/levels/menu_foreground.png"
const REBIND_ACTIONS := ["left", "right", "jump"]

var ai_mask := 0

var _input_router: InputRouter
var _mode_buttons: Array = []
var _key_buttons: Array = []
var _rebind_slot := -1
var _rebind_action := ""


func set_input_router(router: InputRouter) -> void:
	_input_router = router


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := TextureRect.new()
	background.name = "Background"
	background.texture = load(BACKGROUND)
	background.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rows)

	for slot in MenuSlots.MAX_PLAYERS:
		rows.add_child(_build_row(slot))

	var start_button := Button.new()
	start_button.name = "StartButton"
	start_button.text = "Start"
	start_button.pressed.connect(_on_start_pressed)
	rows.add_child(start_button)

	var foreground := TextureRect.new()
	foreground.name = "Foreground"
	foreground.texture = load(FOREGROUND)
	foreground.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foreground)

	start_button.grab_focus()


func _build_row(slot: int) -> Control:
	var row := HBoxContainer.new()
	row.name = "Slot%d" % slot

	var swatch := ColorRect.new()
	swatch.name = "Swatch"
	swatch.color = MenuSlots.PLAYER_COLORS[slot]
	swatch.custom_minimum_size = Vector2(12, 12)
	row.add_child(swatch)

	var label := Label.new()
	label.name = "Label"
	label.text = MenuSlots.PLAYER_LABELS[slot]
	row.add_child(label)

	var mode_button := Button.new()
	mode_button.name = "ModeButton"
	mode_button.text = _mode_text(slot)
	mode_button.pressed.connect(_on_mode_pressed.bind(slot))
	row.add_child(mode_button)
	_mode_buttons.append(mode_button)

	var key_button := Button.new()
	key_button.name = "KeyButton"
	key_button.text = "KEYS"
	key_button.pressed.connect(_on_keys_pressed.bind(slot))
	row.add_child(key_button)
	_key_buttons.append(key_button)

	return row


func _mode_text(slot: int) -> String:
	return "AI" if MenuSlots.is_ai(ai_mask, slot) else "HUMAN"


func _on_mode_pressed(slot: int) -> void:
	ai_mask = MenuSlots.toggle_ai(ai_mask, slot)
	_mode_buttons[slot].text = _mode_text(slot)
	_key_buttons[slot].disabled = MenuSlots.is_ai(ai_mask, slot)


## Enters a sequential "press left / press right / press jump" capture
## mode for this slot; the next 3 physical key presses (_unhandled_input
## below) rebind it, one action at a time.
func _on_keys_pressed(slot: int) -> void:
	if MenuSlots.is_ai(ai_mask, slot):
		return
	_rebind_slot = slot
	_rebind_action = REBIND_ACTIONS[0]
	_key_buttons[slot].text = "PRESS %s..." % _rebind_action.to_upper()


func _unhandled_input(event: InputEvent) -> void:
	if _rebind_slot == -1 or not (event is InputEventKey) or not event.pressed:
		return
	var key_event := event as InputEventKey
	if _input_router != null:
		_input_router.rebind(_rebind_slot, _rebind_action, key_event.physical_keycode)
	var next_index := REBIND_ACTIONS.find(_rebind_action) + 1
	if next_index < REBIND_ACTIONS.size():
		_rebind_action = REBIND_ACTIONS[next_index]
		_key_buttons[_rebind_slot].text = "PRESS %s..." % _rebind_action.to_upper()
	else:
		_key_buttons[_rebind_slot].text = "KEYS"
		_rebind_slot = -1
		_rebind_action = ""
	get_viewport().set_input_as_handled()


func _on_start_pressed() -> void:
	start_requested.emit(ai_mask)
