class_name CorpusReplay
extends RefCounted

## Tier-D corpus replay (TASK-014.07): drives a tests/corpus/*.jsonl trace
## entirely through SimWorld -> JumpnbumpWorld -> the C ABI -> core/*.zig,
## mirroring core/game_loop_difftest.zig's own replay one layer up. Pure,
## Node-independent so it's usable from a plain test as well as gdUnit4.
##
## Trace format (tests/corpus/README.md): one JSON object per line,
## {"frame": N, "keys": ["p1_right", ...], "checksum": "hex8"}. "keys" is
## any of p{1,2,3,4}_{left,right,jump} held that tick; omitted keys are up.


## Builds the three jnb_input bitmasks (bit i = player i) SimWorld.step()
## expects, from a corpus line's "keys" array.
static func inputs_from_keys(keys: Array) -> Dictionary:
	var left := 0
	var right := 0
	var jump := 0
	for raw_key in keys:
		var key := String(raw_key)
		for p in range(4):
			var bit := 1 << p
			if key == "p%d_left" % (p + 1):
				left |= bit
			elif key == "p%d_right" % (p + 1):
				right |= bit
			elif key == "p%d_jump" % (p + 1):
				jump |= bit
	return {"left": left, "right": right, "jump": jump}


## Replays every line of `jsonl_text` against a freshly-initialized SimWorld
## seeded with `level_bytes`. Returns {"ok": bool, "message": String,
## "frame": int} -- frame is the first mismatching/failing frame, or -1 if
## every frame matched.
static func replay(jsonl_text: String, seed: int, flies_enabled: bool, level_bytes: PackedByteArray) -> Dictionary:
	var world := SimWorld.new()
	var init_result := world.init(seed, flies_enabled, level_bytes)
	if init_result != SimWorld.OK:
		return {"ok": false, "message": "init() failed (result %d)" % init_result, "frame": -1}

	for line_text in jsonl_text.split("\n"):
		if line_text.is_empty():
			continue
		var line: Dictionary = JSON.parse_string(line_text)
		if line == null:
			return {"ok": false, "message": "could not parse line: %s" % line_text, "frame": -1}
		var frame: int = line["frame"]
		var expected: String = line["checksum"]

		var bits := inputs_from_keys(line.get("keys", []))
		var step_result: int = world.step(bits["left"], bits["right"], bits["jump"])
		if step_result != SimWorld.OK:
			return {"ok": false, "message": "frame %d: step() failed (result %d)" % [frame, step_result], "frame": frame}

		var dump: Dictionary = world.world_dump()
		if dump["result"] != SimWorld.OK:
			return {"ok": false, "message": "frame %d: world_dump() failed (result %d)" % [frame, dump["result"]], "frame": frame}

		var checksum_result: Dictionary = SimWorld.checksum(dump["bytes"])
		if checksum_result["result"] != SimWorld.OK:
			return {"ok": false, "message": "frame %d: checksum() failed (result %d)" % [frame, checksum_result["result"]], "frame": frame}

		var actual: String = "%08x" % checksum_result["checksum"]
		if actual != expected:
			return {
				"ok": false,
				"message": "frame %d: checksum mismatch (got %s, corpus expects %s)" % [frame, actual, expected],
				"frame": frame,
			}

	return {"ok": true, "message": "", "frame": -1}
