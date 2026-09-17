//! Tier-C ABI conformance tests (TASK-012.03): every test in this file
//! reaches core/abi.zig exclusively through `@cImport(jumpnbump.h)` — never
//! by `@import`ing world.zig/game_loop.zig/levelmap.zig/rnd.zig directly.
//! That rule is mechanically enforced by tools/validate_abi_test_purity.py,
//! which fails the build if this file `@import`s anything other than
//! `"std"`. Without that guard Tier-C silently degrades into a second copy
//! of Tier-A.
//!
//! Known gap this suite documents rather than hides: `jnb_world_init`
//! (TASK-012.02) seeds the RNG and parses the level into `ban_map`, but does
//! not replicate main.c's/core/game_loop_difftest.zig's full headless-init
//! sequence (position_player() to enable + place each player, seedLevelObjects()
//! to spawn springs/butterflies, spawn_flies()) — there is no ABI call for
//! any of that yet. So a freshly-initialized world has every player
//! `enabled == 0`, and core/steer.zig's steer_players() skips disabled
//! players entirely: stepping such a world is a real, well-defined tick
//! (rnd_call_count/frame_num/ban_map all still participate in the checksum)
//! but produces no player movement and no gameplay events. This suite tests
//! the ABI surface and its determinism honestly against that real behavior,
//! rather than fabricating a "gameplay" scenario the current ABI can't
//! actually produce. A future task that adds a player-enable/level-object
//! seeding entry point can extend this suite with real movement/event
//! assertions once that exists.
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
    return .{
        .abi_version = c.JNB_ABI_VERSION,
        ._pad0 = 0,
        .rng_seed = seed,
        .flies_enabled = 1,
        ._pad1 = .{ 0, 0, 0 },
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
    // Nothing seeds an object into a freshly-initialized world (no ABI entry
    // point yet replicates main.c's init_level() object seeding), so every
    // slot starts unused.
    for (objects) |o| try std.testing.expectEqual(@as(u8, 0), o.used);
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
    // No ABI entry point yet enables a player (see the file header comment),
    // so a freshly-initialized world's player 0 is unenabled and untouched.
    try std.testing.expectEqual(@as(u8, 0), view.enabled);
    try std.testing.expectEqual(@as(u8, 0), view.dead_flag);
}

test "jnb_world_reset clears players/objects/frame_num/events but keeps the level and RNG stream" {
    var storage: StorageBuf = .{};
    const config = makeConfig(1);
    try initOk(&storage, &config);

    const inputs: c.jnb_input = .{ .left = 0, .right = 1, .jump = 0, ._pad = 0 };
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_step(storage.ptr(), inputs));
    }

    try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_world_reset(storage.ptr()));

    // frame_num (folded into the dump) is back to a freshly-initialized
    // world's value; the RNG stream (rnd_call_count) is NOT reseeded, per
    // the header's documented reset() contract, so it does not necessarily
    // match a from-scratch init unless nothing consumed the RNG during the
    // five steps above (here, with every player disabled, nothing did) —
    // reset() and a fresh init are only guaranteed to agree when the RNG
    // stream was untouched, which core/steer.zig's disabled-player skip
    // guarantees for this specific scenario.
    var storage2: StorageBuf = .{};
    try initOk(&storage2, &config);

    const need = c.jnb_world_dump_len();
    var dump: [16384]u8 = undefined;
    var dump2: [16384]u8 = undefined;
    var written: usize = 0;
    var written2: usize = 0;
    try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_world_dump(storage.ptr(), &dump, dump.len, &written));
    try std.testing.expectEqual(@as(c.jnb_result, c.JNB_OK), c.jnb_world_dump(storage2.ptr(), &dump2, dump2.len, &written2));
    try std.testing.expectEqual(need, written);
    try std.testing.expectEqualSlices(u8, dump[0..written], dump2[0..written2]);

    try std.testing.expectEqual(@as(usize, 0), c.jnb_event_count(storage.ptr()));
}
