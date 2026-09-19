class_name PauseOverlay
extends Control

## Shown over GameplayScreen while paused (TASK-015.04). Purely a
## presentation overlay: it holds no simulation state itself, it only
## asks GameplayScreen (via these signals) to resume or end the match.

signal resume_requested
signal end_match_requested


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.set_anchors_preset(Control.PRESET_FULL_RECT)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(rows)

	var label := Label.new()
	label.name = "PausedLabel"
	label.text = "PAUSED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(label)

	var resume_button := Button.new()
	resume_button.name = "ResumeButton"
	resume_button.text = "Resume"
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	rows.add_child(resume_button)

	var end_match_button := Button.new()
	end_match_button.name = "EndMatchButton"
	end_match_button.text = "End Match"
	end_match_button.pressed.connect(func() -> void: end_match_requested.emit())
	rows.add_child(end_match_button)

	resume_button.grab_focus()
