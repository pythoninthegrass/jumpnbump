class_name TitleScreen
extends Control

## First screen shown (TASK-015.04): a static title over menu.pcx's
## backdrop with a Start button, standing in for main.c/menu.c's
## scripted attract-mode loop (rabbits walking in, credits scrolling)
## which has no interactive UI of its own to route "press to continue"
## through -- see TASK-015.02's menu_screen.gd for why menu.c isn't a
## literal port target.

signal start_requested

const BACKGROUND := "res://content/levels/menu_background.png"


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

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "JUMP'N'BUMP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)

	var start_button := Button.new()
	start_button.name = "StartButton"
	start_button.text = "Start"
	start_button.pressed.connect(func() -> void: start_requested.emit())
	rows.add_child(start_button)
	start_button.grab_focus()
