class_name ScoresScreen
extends Control

## Post-match tally (TASK-015.04), matching main.c's MOD_SCORES screen in
## spirit: shows each enabled player's total bumps (jnb_player_view.bumps)
## and returns to the menu on continue. The original also drew a
## per-opponent bump matrix, but the ABI only exposes the total (per-
## victim bumped[] tallies are internal-only, include/jumpnbump.h) --
## this shows the total, same number ScoreboardRenderer's in-match HUD
## already uses.

signal continue_requested

const BACKGROUND := "res://content/levels/menu_background.png"

var _final_bumps: Array
var _enabled_slots: Array


func _init(final_bumps: Array = [], enabled_slots: Array = []) -> void:
	_final_bumps = final_bumps
	_enabled_slots = enabled_slots


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := TextureRect.new()
	background.name = "Background"
	background.texture = load(BACKGROUND)
	background.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.set_anchors_preset(Control.PRESET_FULL_RECT)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(rows)

	for slot in MenuSlots.MAX_PLAYERS:
		if slot >= _enabled_slots.size() or not _enabled_slots[slot]:
			continue
		var label := Label.new()
		label.name = "Slot%dLabel" % slot
		label.text = "%s: %d" % [MenuSlots.PLAYER_LABELS[slot], _final_bumps[slot]]
		rows.add_child(label)

	var continue_button := Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "Continue"
	continue_button.pressed.connect(func() -> void: continue_requested.emit())
	rows.add_child(continue_button)
	continue_button.grab_focus()
