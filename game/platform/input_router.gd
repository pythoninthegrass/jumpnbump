class_name InputRouter
extends Node

## Routes keyboard/gamepad input for up to 4 local players into the
## bitmask form jnb_input expects: left/right/jump are each a byte with
## bit i set when player i is holding that action (include/jumpnbump.h's
## jnb_input, core/game_loop.zig's Inputs{left,right,jump: [4]bool}
## packed one-bit-per-player -- TASK-015.01). Emits input_updated every
## frame; holds no game state of its own (AC#4) -- keybindings are input
## configuration, not match state, and the emitted masks are recomputed
## from scratch each frame rather than accumulated.

signal input_updated(left: int, right: int, jump: int)

const MAX_PLAYERS := 4
const JOY_AXIS_DEADZONE := 0.5

## player index -> joypad device id. Only P1 is wired to a gamepad by
## default (AC#2 just requires at least one local player controllable by
## a gamepad); a settings UI can extend this mapping later without
## changing the router's shape.
var joypad_device_for_player: Dictionary = {0: 0}

var bindings: Array

var _store := InputBindings.new()


func _ready() -> void:
	bindings = _store.load_or_default()


func _process(_delta: float) -> void:
	var masks := InputRouter.compute_masks(bindings.size(), _is_pressed)
	input_updated.emit(masks["left"], masks["right"], masks["jump"])


## Rebinds one player's action and persists it immediately (AC#3). See
## input_bindings.gd's save-file-precedence gotcha: this write is what a
## later default-scheme change would need a player to overwrite again.
func rebind(player: int, action: String, keycode: int) -> void:
	bindings[player][action] = keycode
	_store.save(bindings)


## Pure bitmask math, split out from the live Input singleton so it's
## unit-testable: pressed is a Callable(player: int, action: String) ->
## bool -- a stub in tests, _is_pressed (below) at runtime.
static func compute_masks(player_count: int, pressed: Callable) -> Dictionary:
	var left := 0
	var right := 0
	var jump := 0
	for i in mini(player_count, MAX_PLAYERS):
		if pressed.call(i, "left"):
			left |= 1 << i
		if pressed.call(i, "right"):
			right |= 1 << i
		if pressed.call(i, "jump"):
			jump |= 1 << i
	return {"left": left, "right": right, "jump": jump}


func _is_pressed(player: int, action: String) -> bool:
	var keycode: int = bindings[player][action]
	if Input.is_physical_key_pressed(keycode):
		return true
	if joypad_device_for_player.has(player):
		return _joypad_pressed(joypad_device_for_player[player], action)
	return false


func _joypad_pressed(device: int, action: String) -> bool:
	match action:
		"left":
			return Input.get_joy_axis(device, JOY_AXIS_LEFT_X) < -JOY_AXIS_DEADZONE or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT)
		"right":
			return Input.get_joy_axis(device, JOY_AXIS_LEFT_X) > JOY_AXIS_DEADZONE or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT)
		"jump":
			return Input.is_joy_button_pressed(device, JOY_BUTTON_A)
	return false
