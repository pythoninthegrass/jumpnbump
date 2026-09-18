class_name Main
extends Node

## Composition root (TASK-014.01): main.tscn holds only this script on a
## single Node. Every other node the game needs is assembled here in
## _ready() rather than hand-built into the scene, matching neo_snake's
## GameScreen convention -- subsequent TASK-014.* subtasks add the actual
## renderer/audio children. TASK-014.02 wires the sim itself: a SimWorld
## driven each frame by TickDriver, gated on/off without touching the core.
##
## Placeholder init: no level-loading UI or content-driven level selection
## exists yet (that lands with TASK-014.04/016), so this seeds a hardcoded
## sample level purely so the sim has something to tick against.
const SAMPLE_LEVEL_TEXT := (
	"1110000000000000000000\n" +
	"1000000000001000011000\n" +
	"1000111100001100000000\n" +
	"1000000000011110000011\n" +
	"1100000000111000000001\n" +
	"1110001111110000000001\n" +
	"1000000000000011110001\n" +
	"1000000000000000000011\n" +
	"1110011100000000000111\n" +
	"1000000000003100000001\n" +
	"1000000000031110000001\n" +
	"1011110000311111111001\n" +
	"1000000000000000000001\n" +
	"1100000000000000000011\n" +
	"2222222214000001333111\n" +
	"1111111111111111111111\n"
)

var _world: SimWorld
var _gate := false


func _ready() -> void:
	_world = SimWorld.new()
	var result := _world.init(1, false, SAMPLE_LEVEL_TEXT.to_utf8_buffer())
	_gate = result == SimWorld.OK


func _process(delta: float) -> void:
	if _world == null:
		return
	TickDriver.advance_frame(_world, delta * 1000.0, true, _gate)
