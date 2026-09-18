extends GdUnitTestSuite

## Tier-D corpus replay (TASK-014.07/TASK-018): replays the Phase 1 JSONL
## corpus (tests/corpus/*.jsonl, TASK-008.03 -- copied here as
## game/tests/corpus/ since Godot's res:// cannot reach outside the project
## root, alongside a copy of data/levelmap.txt, the real level the corpus
## was recorded against per core/game_loop_difftest.zig's own setup)
## through the real GDExtension, diffing checksums frame-for-frame against
## docs/porting-playbook.md's Tier-B oracle (core/build.zig's `difftest`
## step already proved these same checksums against the Zig-vs-C
## reference).
##
## TASK-018 closed the gap this suite originally discovered: core/abi.zig's
## jnb_world_init now replicates main.c's own headless-init sequence
## (enable/AI-mask/position each configured player, seed the level's
## springs/butterflies, spawn flies) via jnb_config's new player_count/
## player_ai_mask fields, forwarded here from each trace's meta.json
## (headless_players/headless_ai_mask) through SimWorld.init() ->
## CorpusReplay.replay(). test_a_world_with_zero_configured_players_stays_
## disabled below documents the opt-in default (player_count=0 still
## enables nobody) so a regression there fails loudly.

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

func test_a_world_with_zero_configured_players_stays_disabled() -> void:
	var world := SimWorld.new()
	var level := _read_file(CORPUS_DIR + "levelmap.txt")
	assert_int(world.init(1, false, level.to_utf8_buffer())).is_equal(SimWorld.OK)

	var before: Dictionary = world.player_view_get(0)
	assert_int(before["enabled"]).is_equal(0)

	# p1_right held for 5 ticks -- still never becomes enabled: player_count
	# defaults to 0, and only jnb_world_init (not per-tick input) enables a
	# player.
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
		var no_gore: bool = (meta["extra_flags"] as Array).has("-nogore")
		var result := CorpusReplay.replay(
			text,
			int(meta["seed"]),
			flies_enabled,
			level,
			int(meta["headless_players"]),
			int(meta["headless_ai_mask"]),
			no_gore,
		)
		if not result["ok"]:
			failures.append("%s: %s" % [name, result["message"]])

	if not failures.is_empty():
		fail("%d/%d corpus traces failed to reproduce recorded checksums:\n%s" % [failures.size(), TRACE_NAMES.size(), "\n".join(failures)])


func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text()
