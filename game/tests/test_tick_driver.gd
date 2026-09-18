extends SceneTree

## Manual headless smoke test for TickDriver (TASK-014.02), runnable via:
##   godot --headless --path game --script res://tests/test_tick_driver.gd
## This is a stopgap until TASK-014.07 bootstraps gdUnit4 and converts this
## into a real GdUnitTestSuite -- see that task's description. Exits 0 on
## success, 1 on the first failed assertion (printed to stderr).
##
## core/abitest.zig's own sample_16_rows fixture, duplicated here (not
## shared -- game/ has no way to @import Zig test fixtures) as raw
## levelmap.txt-format text: 16 rows of 22 '0'-'4' digits.
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

var _failures := 0


func _initialize() -> void:
	_test_advance_frame_never_reads_a_clock()
	_test_gate_and_running_discard_delta_without_banking()
	_test_60hz_tick_rate_preserved_via_jnb_pumps_accumulator()

	if _failures > 0:
		push_error("%d test_tick_driver assertion(s) failed" % _failures)
		quit(1)
	else:
		print("test_tick_driver: OK")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: %s" % message)


func _new_world() -> SimWorld:
	var world := SimWorld.new()
	var result := world.init(1, false, SAMPLE_LEVEL_TEXT.to_utf8_buffer())
	_assert(result == SimWorld.OK, "world.init() should return OK, got %d" % result)
	return world


## AC#1: advance_frame is a pure static function, never touching a clock
## itself -- verified the same way neo_snake's test_tick_driver.gd does, by
## scanning the source for clock APIs rather than trying to mock one out.
func _test_advance_frame_never_reads_a_clock() -> void:
	var source := FileAccess.get_file_as_string("res://simulation/tick_driver.gd")
	_assert(not source.contains("OS.get_ticks"), "tick_driver.gd must not call OS.get_ticks*")
	_assert(not source.contains("Time.get_ticks"), "tick_driver.gd must not call Time.get_ticks*")
	_assert(not source.contains("Time.get_unix_time"), "tick_driver.gd must not call Time.get_unix_time*")


## AC#2: pausing (running=false or gate=false) must discard the frame's
## delta outright rather than banking it for a later call.
func _test_gate_and_running_discard_delta_without_banking() -> void:
	var world := _new_world()

	var paused_result: Dictionary = TickDriver.advance_frame(world, 5000.0, false, true)
	_assert(paused_result["ticks"] == 0, "running=false must produce 0 ticks, got %d" % paused_result["ticks"])

	var gated_result: Dictionary = TickDriver.advance_frame(world, 5000.0, true, false)
	_assert(gated_result["ticks"] == 0, "gate=false must produce 0 ticks, got %d" % gated_result["ticks"])

	# If either call above had leaked its delta into jnb_pump's accumulator,
	# this small follow-up call would already have accumulated ticks.
	var small_result: Dictionary = TickDriver.advance_frame(world, 1.0, true, true)
	_assert(small_result["ticks"] == 0, "a small follow-up frame must not inherit banked ticks from a discarded frame, got %d" % small_result["ticks"])


## AC#3: the original 60Hz tick rate is preserved through jnb_pump's own
## fixed-timestep accumulator (core/game_loop.zig), not reimplemented here --
## feeding exactly 1000ms across many small, uneven per-frame deltas must
## yield exactly 60 ticks with zero drift.
func _test_60hz_tick_rate_preserved_via_jnb_pumps_accumulator() -> void:
	var world := _new_world()
	var total_ticks := 0
	for i in range(100):
		var result: Dictionary = TickDriver.advance_frame(world, 10.0, true, true)
		_assert(result["result"] == SimWorld.OK, "advance_frame result should be OK, got %d" % result["result"])
		total_ticks += result["ticks"]
	_assert(total_ticks == 60, "1000ms of uneven 10ms frames should yield exactly 60 ticks, got %d" % total_ticks)
