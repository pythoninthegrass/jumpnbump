class_name Main
extends Node

## Composition root (TASK-014.01): main.tscn holds only this script on a
## single Node. Every other node the game needs is assembled here in
## _ready() rather than hand-built into the scene, matching neo_snake's
## GameScreen convention -- subsequent TASK-014.* subtasks add the actual
## TickDriver/renderer/audio children.


func _ready() -> void:
	pass
