//! Tier-C ABI conformance tests (TASK-012.03): every test in this file
//! reaches core/abi.zig exclusively through `@cImport(jumpnbump.h)` — never
//! by `@import`ing world.zig/game_loop.zig/levelmap.zig/rnd.zig directly.
//! That rule is mechanically enforced by tools/validate_abi_test_purity.py,
//! which fails the build if this file `@import`s anything other than
//! `"std"`. Without that guard Tier-C silently degrades into a second copy
//! of Tier-A.
//!
//! `jnb_world_init` (TASK-012.02, extended by TASK-018) replicates main.c's
//! full headless-init sequence (main.c:1549-1598): enable+AI-mask
//! `config.player_count` players, `position_player()` each one,
//! `seedLevelObjects()` the level's springs/butterflies, and `spawn_flies()`
//! if `config.flies_enabled` — all before the first tick. So a
//! freshly-initialized world already has its level objects seeded and its
//! configured players enabled/positioned; `makeConfig()` below defaults
//! `player_count`/`player_ai_mask` to 0 for tests that only care about
//! ABI plumbing (buffer contracts, error codes, determinism), and
//! `makeConfigWithPlayers()` opts a test into real enabled players where
//! that matters (reset semantics, AI-mask wiring).
const std = @import("std");

const c = @cImport({
    @cInclude("jumpnbump.h");
});

/// Every test here fits comfortably under this buffer's size (checked at
/// runtime against jnb_world_size, not assumed) — mirrors neo_snake's
/// abitest.zig StorageBuf pattern.
const StorageBuf = struct {
    bytes: [16384]u8 align(64) = undefined,

    fn ptr(self: *StorageBuf) *c.jnb_world {
        return @ptrCast(&self.bytes);
    }
};

/// core/levelmap.zig's own `sample_16_rows` test fixture, duplicated here
/// (not `@import`ed — the purity rule only allows `"std"`) as raw
/// levelmap.txt-format text: 16 rows of 22 '0'-'4' digits, matching
/// main.c's hardcoded default ban_map exactly.
const sample_level_text =
    "1110000000000000000000\n" ++
    "1000000000001000011000\n" ++
    "1000111100001100000000\n" ++
    "1000000000011110000011\n" ++
    "1100000000111000000001\n" ++
    "1110001111110000000001\n" ++
    "1000000000000011110001\n" ++
    "1000000000000000000011\n" ++
    "1110011100000000000111\n" ++
    "1000000000003100000001\n" ++
    "1000000000031110000001\n" ++
    "1011110000311111111001\n" ++
    "1000000000000000000001\n" ++
    "1100000000000000000011\n" ++
    "2222222214000001333111\n" ++
    "1111111111111111111111\n";

fn makeConfig(seed: u32) c.jnb_config {
    return makeConfigWithPlayers(seed, 0, 0);
}

fn makeConfigWithPlayers(seed: u32, player_count: u8, player_ai_mask: u8) c.jnb_config {
    return .{
        .abi_version = c.JNB_ABI_VERSION,
        ._pad0 = 0,
        .rng_seed = seed,
        .flies_enabled = 1,
        .player_count = player_count,
        .player_ai_mask = player_ai_mask,
        .no_gore = 0,
    };
}

fn initOk(storage: *StorageBuf, config: *const c.jnb_config) !void {
    try std.testing.expect(c.jnb_world_size() <= storage.bytes.len);
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_OK),
        c.jnb_world_init(storage.ptr(), config, sample_level_text.ptr, sample_level_text.len),
    );
}

test "jnb_world_init rejects a mismatched abi_version and accepts the real one" {
    var storage: StorageBuf = .{};
    var config = makeConfig(1);

    config.abi_version = c.JNB_ABI_VERSION + 1;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_ERR_ABI_VERSION_MISMATCH),
        c.jnb_world_init(storage.ptr(), &config, sample_level_text.ptr, sample_level_text.len),
    );

    config.abi_version = c.JNB_ABI_VERSION;
    try initOk(&storage, &config);
}

test "jnb_world_init rejects a zero rng_seed" {
    var storage: StorageBuf = .{};
    const config = makeConfig(0);
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_ERR_INVALID_ARGUMENT),
        c.jnb_world_init(storage.ptr(), &config, sample_level_text.ptr, sample_level_text.len),
    );
}

test "jnb_world_init reports JNB_ERR_LEVEL_PARSE_FAILED on truncated level bytes" {
    var storage: StorageBuf = .{};
    const config = makeConfig(1);
    const truncated = "1110000000000000000000\n"; // one row, not sixteen
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_ERR_LEVEL_PARSE_FAILED),
        c.jnb_world_init(storage.ptr(), &config, truncated.ptr, truncated.len),
    );
}

test "every jnb_result value is reachable from at least one call path" {
    var storage: StorageBuf = .{};
    var config = makeConfig(1);

    // JNB_ERR_ABI_VERSION_MISMATCH
    config.abi_version = c.JNB_ABI_VERSION + 1;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_ERR_ABI_VERSION_MISMATCH),
        c.jnb_world_init(storage.ptr(), &config, sample_level_text.ptr, sample_level_text.len),
    );
    config.abi_version = c.JNB_ABI_VERSION;

    // JNB_ERR_INVALID_ARGUMENT (zero rng_seed, rejected before any world exists)
    const bad_seed = blk: {
        var cfg = config;
        cfg.rng_seed = 0;
        break :blk cfg;
    };
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_ERR_INVALID_ARGUMENT),
        c.jnb_world_init(storage.ptr(), &bad_seed, sample_level_text.ptr, sample_level_text.len),
    );

    // JNB_ERR_LEVEL_PARSE_FAILED
    const truncated = "1110000000000000000000\n";
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_ERR_LEVEL_PARSE_FAILED),
        c.jnb_world_init(storage.ptr(), &config, truncated.ptr, truncated.len),
    );

    // JNB_OK
    try initOk(&storage, &config);

    // JNB_ERR_INVALID_ARGUMENT again, this time from an out-of-range player index.
    var view: c.jnb_player_view = undefined;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_ERR_INVALID_ARGUMENT),
        c.jnb_player_view_get(storage.ptr(), c.JNB_MAX_PLAYERS, &view),
    );

    // JNB_ERR_BUFFER_TOO_SMALL
    var too_small: [1]c.jnb_object_view = undefined;
    var required: usize = 0;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_ERR_BUFFER_TOO_SMALL),
        c.jnb_objects_copy(storage.ptr(), &too_small, too_small.len, &required),
    );
}

test "jnb_objects_copy two-call length-then-fill contract" {
    var storage: StorageBuf = .{};
    const config = makeConfig(1);
    try initOk(&storage, &config);

    // NULL/0-capacity call: reports the required length without copying.
    var required: usize = 0;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_OK),
        c.jnb_objects_copy(storage.ptr(), null, 0, &required),
    );
    try std.testing.expectEqual(@as(usize, c.JNB_NUM_OBJECTS), required);

    // Too-small nonzero capacity: JNB_ERR_BUFFER_TOO_SMALL, required still reported.
    var too_small: [10]c.jnb_object_view = undefined;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_ERR_BUFFER_TOO_SMALL),
        c.jnb_objects_copy(storage.ptr(), &too_small, too_small.len, &required),
    );
    try std.testing.expectEqual(@as(usize, c.JNB_NUM_OBJECTS), required);

    // Sufficient capacity: succeeds, every slot copied (used or not, per the header).
    var objects: [c.JNB_NUM_OBJECTS]c.jnb_object_view = undefined;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_OK),
        c.jnb_objects_copy(storage.ptr(), &objects, objects.len, &required),
    );
    try std.testing.expectEqual(@as(usize, c.JNB_NUM_OBJECTS), required);
    // sample_level_text has exactly one spring tile (row 14, col 9) within
    // seedLevelObjects()'s 16-row scan bound, plus the two yellow and two
    // pink butterflies init_level() always seeds -- five used slots, first-fit
    // allocated in that exact order (spring, yel, yel, pink, pink).
    var used_count: usize = 0;
    for (objects) |o| {
        if (o.used != 0) used_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 5), used_count);
    try std.testing.expectEqual(@as(i32, 0), objects[0].type); // OBJ_SPRING
    try std.testing.expectEqual(@as(i32, 3), objects[1].type); // OBJ_YEL_BUTFLY
    try std.testing.expectEqual(@as(i32, 3), objects[2].type); // OBJ_YEL_BUTFLY
    try std.testing.expectEqual(@as(i32, 4), objects[3].type); // OBJ_PINK_BUTFLY
    try std.testing.expectEqual(@as(i32, 4), objects[4].type); // OBJ_PINK_BUTFLY
    for (objects[5..]) |o| try std.testing.expectEqual(@as(u8, 0), o.used);
}

test "jnb_world_dump two-call length-then-fill contract" {
    var storage: StorageBuf = .{};
    const config = makeConfig(1);
    try initOk(&storage, &config);

    const need = c.jnb_world_dump_len();
    try std.testing.expect(need > 0);

    var written: usize = 0;
    const too_small = try std.testing.allocator.alloc(u8, need - 1);
    defer std.testing.allocator.free(too_small);
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_ERR_BUFFER_TOO_SMALL),
        c.jnb_world_dump(storage.ptr(), too_small.ptr, too_small.len, &written),
    );
    try std.testing.expectEqual(need, written);

    const exact = try std.testing.allocator.alloc(u8, need);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_OK),
        c.jnb_world_dump(storage.ptr(), exact.ptr, exact.len, &written),
    );
    try std.testing.expectEqual(need, written);
}

test "jnb_event_drain two-call length-then-fill contract on an empty queue" {
    var storage: StorageBuf = .{};
    const config = makeConfig(1);
    try initOk(&storage, &config);

    // A freshly-initialized, never-stepped world has no queued events.
    try std.testing.expectEqual(@as(usize, 0), c.jnb_event_count(storage.ptr()));

    var out_count: usize = 0;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_OK),
        c.jnb_event_drain(storage.ptr(), null, 0, &out_count),
    );
    try std.testing.expectEqual(@as(usize, 0), out_count);

    var buf: [16]c.jnb_event = undefined;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_OK),
        c.jnb_event_drain(storage.ptr(), &buf, buf.len, &out_count),
    );
    try std.testing.expectEqual(@as(usize, 0), out_count);
}

test "@sizeOf on the ABI-crossing structs matches include/jumpnbump.h's static_asserts" {
    try std.testing.expectEqual(@as(usize, 12), @sizeOf(c.jnb_config));
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(c.jnb_input));
    try std.testing.expectEqual(@as(usize, 40), @sizeOf(c.jnb_player_view));
    try std.testing.expectEqual(@as(usize, 36), @sizeOf(c.jnb_object_view));
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(c.jnb_event));
}

test "jnb_step advances frame_num-driven state deterministically and jnb_checksum matches jnb_world_dump" {
    var storage: StorageBuf = .{};
    const config = makeConfig(1);
    try initOk(&storage, &config);

    const inputs: c.jnb_input = .{ .left = 0, .right = 1, .jump = 0, ._pad = 0 };
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_step(storage.ptr(), inputs));
    }

    const need = c.jnb_world_dump_len();
    var dump: [16384]u8 = undefined;
    try std.testing.expect(need <= dump.len);
    var written: usize = 0;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_OK),
        c.jnb_world_dump(storage.ptr(), &dump, dump.len, &written),
    );

    var checksum: u32 = 0;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_OK),
        c.jnb_checksum(&dump, written, &checksum),
    );

    // Determinism: an identical fresh world, stepped with the identical
    // seed/level/inputs, must dump to the exact same bytes and checksum —
    // this is the property the whole checksum format exists to guarantee
    // (docs/checksum-format.md), exercised here entirely through the C ABI.
    var storage2: StorageBuf = .{};
    try initOk(&storage2, &config);
    i = 0;
    while (i < 10) : (i += 1) {
        try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_step(storage2.ptr(), inputs));
    }
    var dump2: [16384]u8 = undefined;
    var written2: usize = 0;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_OK),
        c.jnb_world_dump(storage2.ptr(), &dump2, dump2.len, &written2),
    );
    try std.testing.expectEqualSlices(u8, dump[0..written], dump2[0..written2]);

    var checksum2: u32 = 0;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_OK),
        c.jnb_checksum(&dump2, written2, &checksum2),
    );
    try std.testing.expectEqual(checksum, checksum2);

    // rnd_call_count/frame_num are folded into the dump (docs/checksum-format.md
    // fields 1-2), so ten real ticks against an untouched world must not
    // leave it identical to a freshly-initialized one that took zero ticks.
    var storage3: StorageBuf = .{};
    try initOk(&storage3, &config);
    var dump3: [16384]u8 = undefined;
    var written3: usize = 0;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_OK),
        c.jnb_world_dump(storage3.ptr(), &dump3, dump3.len, &written3),
    );
    try std.testing.expect(!std.mem.eql(u8, dump[0..written], dump3[0..written3]));
}

test "jnb_pump advances a whole number of 60Hz ticks for a given delta and queues per-tick events" {
    var storage: StorageBuf = .{};
    const config = makeConfig(1);
    try initOk(&storage, &config);

    const inputs: c.jnb_input = .{ .left = 0, .right = 0, .jump = 0, ._pad = 0 };
    var out_ticks: u32 = 0;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_OK),
        c.jnb_pump(storage.ptr(), 1000, inputs, &out_ticks),
    );
    try std.testing.expectEqual(@as(u32, 60), out_ticks);

    // jnb_pump must match jnb_step called once per tick, tick-for-tick, on
    // an identical fresh world (both walk the same accumulator arithmetic).
    var storage2: StorageBuf = .{};
    try initOk(&storage2, &config);
    var i: usize = 0;
    while (i < 60) : (i += 1) {
        try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_step(storage2.ptr(), inputs));
    }

    var dump1: [16384]u8 = undefined;
    var dump2: [16384]u8 = undefined;
    var w1: usize = 0;
    var w2: usize = 0;
    try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_world_dump(storage.ptr(), &dump1, dump1.len, &w1));
    try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_world_dump(storage2.ptr(), &dump2, dump2.len, &w2));
    try std.testing.expectEqualSlices(u8, dump1[0..w1], dump2[0..w2]);
}

test "jnb_player_view_get rejects an out-of-range player and reports a disabled player's real fields" {
    var storage: StorageBuf = .{};
    const config = makeConfig(1);
    try initOk(&storage, &config);

    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_ERR_INVALID_ARGUMENT),
        c.jnb_player_view_get(storage.ptr(), c.JNB_MAX_PLAYERS, @ptrFromInt(@alignOf(c.jnb_player_view))),
    );

    var view: c.jnb_player_view = undefined;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_OK),
        c.jnb_player_view_get(storage.ptr(), 0, &view),
    );
    // makeConfig() defaults to zero enabled players, so a freshly-initialized
    // world's player 0 is unenabled and untouched.
    try std.testing.expectEqual(@as(u8, 0), view.enabled);
    try std.testing.expectEqual(@as(u8, 0), view.dead_flag);
}

test "jnb_world_init enables and positions config.player_count players, applies player_ai_mask" {
    var storage: StorageBuf = .{};
    // Players 0 and 2 AI-driven (bits 0 and 2 set), player 1 manual;
    // player 3 left disabled (player_count=3).
    const config = makeConfigWithPlayers(1, 3, 0b101);
    try initOk(&storage, &config);

    var view: c.jnb_player_view = undefined;
    inline for (0..3) |p| {
        try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_player_view_get(storage.ptr(), p, &view));
        try std.testing.expectEqual(@as(u8, 1), view.enabled);
        // position_player() sets jump_ready=1; a player that was never
        // positioned keeps the zeroed default -- this is how the test
        // observes "position_player ran" through the ABI's view struct
        // without a raw internal field read.
        try std.testing.expectEqual(@as(u8, 1), view.jump_ready);
    }
    try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_player_view_get(storage.ptr(), 3, &view));
    try std.testing.expectEqual(@as(u8, 0), view.enabled);
    try std.testing.expectEqual(@as(u8, 0), view.jump_ready);

    // AI-mask actually changes simulation behavior: an AI-driven player 0
    // fed all-zero manual input still acts through cpu_move() every tick
    // (cpu_move() needs another enabled player to chase, hence two players
    // here), while the identical seed/level with player 0 NOT AI-driven
    // only reacts to (absent) manual input -- so their post-step checksums
    // must diverge, proving player_ai_mask actually reached
    // core/cpu_move.zig's ai[] rather than being silently ignored.
    // The ABI's player/object/ban_map storage is a process-wide singleton
    // (see abi.zig's file header comment) -- every world shares the exact
    // same underlying globals, distinguished only by each StorageBuf's own
    // Instance bookkeeping (state/frame_num/events). So the two worlds below
    // must run to completion (init, step, dump into a LOCAL byte buffer)
    // one at a time, never interleaved, exactly like this file's other
    // multi-world determinism tests (e.g. "jnb_step advances..." above) --
    // interleaving jnb_step calls between two live worlds would silently
    // step one shared world twice, not two independent ones.
    const zero_inputs: c.jnb_input = .{ .left = 0, .right = 0, .jump = 0, ._pad = 0 };
    var ai_dump: [16384]u8 = undefined;
    var ai_written: usize = 0;
    {
        var ai_storage: StorageBuf = .{};
        try initOk(&ai_storage, &makeConfigWithPlayers(1, 2, 1));
        var i: usize = 0;
        while (i < 200) : (i += 1) {
            try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_step(ai_storage.ptr(), zero_inputs));
        }
        try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_world_dump(ai_storage.ptr(), &ai_dump, ai_dump.len, &ai_written));
    }

    var manual_dump: [16384]u8 = undefined;
    var manual_written: usize = 0;
    {
        var manual_storage: StorageBuf = .{};
        try initOk(&manual_storage, &makeConfigWithPlayers(1, 2, 0));
        var i: usize = 0;
        while (i < 200) : (i += 1) {
            try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_step(manual_storage.ptr(), zero_inputs));
        }
        try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_world_dump(manual_storage.ptr(), &manual_dump, manual_dump.len, &manual_written));
    }

    try std.testing.expect(!std.mem.eql(u8, ai_dump[0..ai_written], manual_dump[0..manual_written]));
}

/// Reads a little-endian u32 out of a raw jnb_world_dump buffer — legitimate
/// Tier-C usage of the *documented* dump wire format (docs/checksum-format.md:
/// frame_num at byte offset 0, rnd_call_count at offset 4), not a reach into
/// core/world.zig internals.
fn dumpU32(dump: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, dump[offset..][0..4], .little);
}

test "jnb_world_reset clears players/objects/frame_num/events but keeps the level and RNG stream" {
    var storage: StorageBuf = .{};
    // A real enabled/AI-driven player this time (unlike every other test's
    // makeConfig(seed) default of zero players), so "reset clears players"
    // is actually exercised against a player that moved, rather than one
    // that was disabled the whole time.
    const config = makeConfigWithPlayers(1, 1, 1);
    try initOk(&storage, &config);

    const inputs: c.jnb_input = .{ .left = 0, .right = 0, .jump = 0, ._pad = 0 };
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_step(storage.ptr(), inputs));
    }

    // Pre-reset: the AI-driven player is enabled, level objects (springs/
    // butterflies) are seeded, and the RNG stream has advanced past init
    // (butterfly wobble + AI + flies all draw from it every tick).
    var pre_view: c.jnb_player_view = undefined;
    try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_player_view_get(storage.ptr(), 0, &pre_view));
    try std.testing.expectEqual(@as(u8, 1), pre_view.enabled);

    var pre_dump: [16384]u8 = undefined;
    var pre_written: usize = 0;
    try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_world_dump(storage.ptr(), &pre_dump, pre_dump.len, &pre_written));
    const rnd_before_reset = dumpU32(pre_dump[0..pre_written], 4);

    try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_world_reset(storage.ptr()));

    // Players cleared.
    var post_view: c.jnb_player_view = undefined;
    try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_player_view_get(storage.ptr(), 0, &post_view));
    try std.testing.expectEqual(@as(u8, 0), post_view.enabled);

    // Objects cleared -- including the springs/butterflies init_level()
    // seeded, even though reset() does not reseed them.
    var post_objects: [c.JNB_NUM_OBJECTS]c.jnb_object_view = undefined;
    var post_required: usize = 0;
    try std.testing.expectEqual(
        @as(c.jnb_result, c.JNB_OK),
        c.jnb_objects_copy(storage.ptr(), &post_objects, post_objects.len, &post_required),
    );
    for (post_objects) |o| try std.testing.expectEqual(@as(u8, 0), o.used);

    // Events cleared.
    try std.testing.expectEqual(@as(usize, 0), c.jnb_event_count(storage.ptr()));

    // frame_num cleared -- back to 0xffffffff, the "no tick has completed
    // yet" sentinel a fresh world also starts at (abi.zig's Instance doc
    // comment: matching main.c's pre-increment headless_frame_num means 0
    // is tick 0's own label, not "nothing has run", so those two states
    // can't share the same stored value). RNG stream NOT reseeded (reset()
    // itself makes no rnd() calls, so the count immediately after reset
    // must equal the count immediately before it), and the level's ban_map
    // bytes unchanged.
    var post_dump: [16384]u8 = undefined;
    var post_written: usize = 0;
    try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_world_dump(storage.ptr(), &post_dump, post_dump.len, &post_written));
    try std.testing.expectEqual(@as(u32, 0xffffffff), dumpU32(post_dump[0..post_written], 0));
    try std.testing.expectEqual(rnd_before_reset, dumpU32(post_dump[0..post_written], 4));

    const ban_map_bytes = @as(usize, c.JNB_BAN_ROWS) * @as(usize, c.JNB_BAN_COLS) * 4;
    const ban_map_start = pre_written - ban_map_bytes;
    try std.testing.expectEqualSlices(u8, pre_dump[ban_map_start..pre_written], post_dump[ban_map_start..post_written]);
}

test "jnb_step reproduces the Phase 1 corpus's real recorded checksum through the real ABI" {
    // tests/corpus/01-single-player-basic.jsonl's frame-0 line, verbatim
    // (seed 1, one enabled player, p1_right held, sample_level_text's own
    // grid -- which is levelmap.zig's sample_16_rows fixture and also
    // happens to be the real committed data/jumpbump.dat levelmap.txt,
    // confirmed identical byte-for-byte). game/tests/test_corpus_replay.gd
    // (TASK-014.07) exercises the FULL 10-trace corpus through the real
    // GDExtension; this single frame pins the same oracle value at the
    // Tier-C/ABI-only layer, since Tier-C purity forbids @import-ing
    // core/game_loop_difftest.zig's own already-passing Tier-B replay of
    // it. Catches exactly the two defects TASK-018 found: player_count/
    // player_ai_mask not reaching player enable/position/AI at all, and
    // frame_num's off-by-one against main.c's pre-increment
    // headless_emit_checksum() convention (main.c:1386-1391) -- either
    // regressing flips this checksum.
    var storage: StorageBuf = .{};
    try initOk(&storage, &makeConfigWithPlayers(1, 1, 0));

    const inputs: c.jnb_input = .{ .left = 0, .right = 1, .jump = 0, ._pad = 0 };
    try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_step(storage.ptr(), inputs));

    var dump: [16384]u8 = undefined;
    var written: usize = 0;
    try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_world_dump(storage.ptr(), &dump, dump.len, &written));
    var checksum: u32 = 0;
    try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_checksum(&dump, written, &checksum));
    try std.testing.expectEqual(@as(u32, 0x1584ec43), checksum);
}

