extends GdUnitTestSuite

## Tier-D corpus replay (TASK-014.07): replays the Phase 1 JSONL corpus
## (tests/corpus/*.jsonl, TASK-008.03 -- copied here as game/tests/corpus/
## since Godot's res:// cannot reach outside the project root, alongside a
## copy of data/levelmap.txt, the real level the corpus was recorded
## against per core/game_loop_difftest.zig's own setup) through the real
## GDExtension, diffing checksums frame-for-frame against docs/porting-
## playbook.md's Tier-B oracle (core/build.zig's `difftest` step already
## proved these same checksums against the Zig-vs-C reference).
##
## KNOWN GAP, discovered while writing this suite: core/abi.zig's
## jnb_world_init (TASK-012.02) never enables, positions, or seeds any
## player -- main.c's own headless setup calls position_player() per
## enabled player and seeds level springs/butterflies via init_level()
## (see core/game_loop_difftest.zig's setupWorld()/seedLevelObjects(),
## which replicates that sequence manually for its OWN Tier-B replay,
## entirely bypassing the ABI). No jnb_* export exists to reach any of
## that from outside core/ -- jnb_config carries only abi_version/
## rng_seed/flies_enabled, and jnb_player_view_get is read-only. So every
## player.enabled stays 0 forever through the real GDExtension, and EVERY
## corpus trace's checksums genuinely cannot match yet: this is a
## pre-existing gap in already-completed TASK-012.02, not something
## introduced or fixable in this game-layer task. test_a_fresh_world_
## never_enables_any_player below locks in and documents that exact
## observed behavior; the moment a future ABI change fixes this, that
## guard test fails loudly, which is the trigger to come back here and
## expect this suite's real checksum-matching test to go green.
##
## This test is deliberately left failing rather than skipped/weakened --
## see this task's own commit message and implementation notes for the
## full writeup. A green gdUnit4 report here would misrepresent Tier-D
## coverage that does not exist yet.

const CORPUS_DIR := "res://tests/corpus/"
const TRACE_NAMES := [
	"01-single-player-basic",
	"02-two-player-manual",
	"03-two-player-ai-kill",
	"04-two-player-ai-kill-nogore",
	"05-four-players-ai",
	"06-water-immersion",
	"07-spring-bounce",
	"08-ice-slide",
	"09-flies-off",
	"10-spring-water-mix",
]

## 03/04/05 additionally require AI-driven players (meta.json's
## headless_ai_mask != 0): the ABI has no way to mark a player AI-driven
## either (core/cpu_move.zig's ai[] array is reachable only from within
## core/, same root cause as the header comment above), so these three
## would still be unrepresentable even if the enable/position gap above
## were fixed today. Listed separately so fixing the header-comment gap
## alone has an honest, narrower set left to solve.
const ALSO_NEEDS_AI_MASK := ["03-two-player-ai-kill", "04-two-player-ai-kill-nogore", "05-four-players-ai"]


func test_a_fresh_world_never_enables_any_player() -> void:
	var world := SimWorld.new()
	var level := _read_file(CORPUS_DIR + "levelmap.txt")
	assert_int(world.init(1, false, level.to_utf8_buffer())).is_equal(SimWorld.OK)

	var before: Dictionary = world.player_view_get(0)
	assert_int(before["enabled"]).is_equal(0)

	# p1_right held for 5 ticks -- still never becomes enabled, since no
	# jnb_* export exists to flip it (see the file header).
	for _i in range(5):
		assert_int(world.step(1, 0, 0)).is_equal(SimWorld.OK)
	var after: Dictionary = world.player_view_get(0)
	assert_int(after["enabled"]).is_equal(0)


func test_every_corpus_trace_replays_with_matching_checksums() -> void:
	var level := _read_file(CORPUS_DIR + "levelmap.txt").to_utf8_buffer()
	var failures: Array[String] = []
	for name in TRACE_NAMES:
		var meta: Dictionary = JSON.parse_string(_read_file(CORPUS_DIR + name + ".meta.json"))
		var text := _read_file(CORPUS_DIR + name + ".jsonl")
		var flies_enabled: bool = not (meta["extra_flags"] as Array).has("-noflies")
		var result := CorpusReplay.replay(text, int(meta["seed"]), flies_enabled, level)
		if not result["ok"]:
			var suffix := " (also needs AI-mask support, not just player-enable)" if ALSO_NEEDS_AI_MASK.has(name) else ""
			failures.append("%s: %s%s" % [name, result["message"], suffix])

	if not failures.is_empty():
		fail("%d/%d corpus traces failed to reproduce recorded checksums (expected today -- see file header):\n%s" % [failures.size(), TRACE_NAMES.size(), "\n".join(failures)])


func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text()
