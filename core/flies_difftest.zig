// Tier-B differential tests for TASK-011.06: core/flies.zig vs the
// renamed-C reference (core/c_ref/flies.c), wired up in core/build.zig
// via compileRenamedCRef.
//
// flies[]/lord_of_the_flies are core/flies.zig's own exports; player_raw[]
// and ban_map_raw[] are core/c_ref/flies_harness.c's shared storage (the
// same arrays core/flies.zig declares extern) -- both sides of this binary
// read/write the identical memory. rnd() is rnd.zig's real, unrenamed
// export, so update_flies' rnd(3) jitter draws from one shared PRNG
// stream: the harness reseeds it to the same value immediately before
// each side's run so both consume the identical draw sequence, the same
// way core/cpu_move_difftest.zig snapshots/restores keyb[] around its two
// runs instead of maintaining two independent copies.
const std = @import("std");
const flies = @import("flies.zig");
const rnd = @import("rnd.zig");

extern var player_raw: [4]flies.Player;
extern var ban_map_raw: [17][22]c_uint;

extern fn c_get_closest_player_to_point(x: c_int, y: c_int, dist: *c_int, closest_player: *c_int) void;
extern fn c_update_flies(update_count: c_int) void;
extern fn c_spawn_flies() void;

const default_level = [16][]const u8{
    "1110000000000000000000",
    "1000000000001000011000",
    "1000111100001100000000",
    "1000000000011110000011",
    "1100000000111000000001",
    "1110001111110000000001",
    "1000000000000011110001",
    "1000000000000000000011",
    "1110011100000000000111",
    "1000000000003100000001",
    "1000000000031110000001",
    "1011110000311111111001",
    "1000000000000000000001",
    "1100000000000000000011",
    "2222222214000001333111",
    "1111111111111111111111",
};

fn loadDefaultLevel() void {
    for (0..16) |r| {
        for (0..22) |col| {
            ban_map_raw[r][col] = default_level[r][col] - '0';
        }
    }
    for (0..22) |col| {
        ban_map_raw[16][col] = 1;
    }
}

fn setPlayers(xs: [4]i32, ys: [4]i32, enabled: [4]c_int) void {
    for (0..4) |i| {
        player_raw[i] = .{ .x = xs[i], .y = ys[i], .enabled = enabled[i] };
    }
}

fn px(v: i32) i32 {
    return v << 16;
}

/// Reseed to `seed`, run flies.update_flies(update_count), snapshot the
/// result, rewind flies[] to the pre-run input, reseed to the same value,
/// run the C reference, then compare every fly's full state.
fn runBothAndCompare(label: []const u8, seed: u32, update_count: c_int, mismatches: *usize) void {
    const before = flies.flies;
    rnd.seed(seed);
    flies.update_flies(update_count);
    const zig_after = flies.flies;
    flies.flies = before;
    rnd.seed(seed);
    c_update_flies(update_count);
    for (0..flies.num_flies) |k| {
        const a = zig_after[k];
        const b = flies.flies[k];
        if (a.x != b.x or a.y != b.y or a.old_x != b.old_x or a.old_y != b.old_y) {
            std.debug.print("{s}: fly[{d}] zig=({d},{d},{d},{d}) c_ref=({d},{d},{d},{d})\n", .{
                label, k, a.x, a.y, a.old_x, a.old_y, b.x, b.y, b.old_x, b.old_y,
            });
            mismatches.* += 1;
        }
    }
}

test "update_flies matches the C reference across positions, seeds and lord_of_the_flies" {
    loadDefaultLevel();
    var mismatches: usize = 0;
    var ticks: usize = 0;

    const centers = [_][2]i32{ .{ 160, 120 }, .{ 20, 20 }, .{ 340, 230 }, .{ 176, 8 }, .{ 176, 232 } };
    const offsets = [_][2]i32{ .{ -20, 0 }, .{ 20, 0 }, .{ 0, -20 }, .{ 0, 20 }, .{ -40, -40 } };

    for (centers) |center| {
        for (offsets) |off| {
            for ([_]c_int{ 0, 1 }) |lord| {
                flies.lord_of_the_flies = lord;
                for (&flies.flies) |*fly| {
                    fly.* = .{};
                    fly.x = center[0];
                    fly.y = center[1];
                }
                setPlayers(
                    .{ px(center[0] + off[0]), 0, 0, 0 },
                    .{ px(center[1] + off[1]), 0, 0, 0 },
                    .{ 1, 0, 0, 0 },
                );

                var tick: usize = 0;
                while (tick < 20) : (tick += 1) {
                    const seed: u32 = @intCast(1 + center[0] * 7 + center[1] * 13 + @as(i32, @intCast(tick)) * 3 + lord * 101);
                    var buf: [96]u8 = undefined;
                    const case = std.fmt.bufPrint(&buf, "center({d},{d}) off({d},{d}) lord={d} tick {d}", .{ center[0], center[1], off[0], off[1], lord, tick }) catch "?";
                    runBothAndCompare(case, seed, 1, &mismatches);
                    ticks += 1;
                    if (mismatches > 0) return std.testing.expectEqual(@as(usize, 0), mismatches);
                }
            }
        }
    }

    try std.testing.expect(ticks >= 400);
    try std.testing.expectEqual(@as(usize, 0), mismatches);
}

test "update_flies matches the C with no players enabled" {
    // Every player disabled: get_closest_player_to_point never finds a
    // target, so every fly's move is pure swarm-cohesion plus jitter.
    loadDefaultLevel();
    setPlayers(.{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 });
    var mismatches: usize = 0;

    for (&flies.flies) |*fly| {
        fly.* = .{};
        fly.x = 176;
        fly.y = 120;
    }

    var tick: usize = 0;
    while (tick < 100) : (tick += 1) {
        var buf: [32]u8 = undefined;
        const case = std.fmt.bufPrint(&buf, "no-player tick {d}", .{tick}) catch "?";
        runBothAndCompare(case, @intCast(500 + tick), 1, &mismatches);
    }

    try std.testing.expectEqual(@as(usize, 0), mismatches);
}

test "spawn_flies matches the C reference" {
    // spawn_flies keeps re-rolling until it lands on a void tile, so this
    // pins the retry loop's rnd() consumption too, not just the formula.
    loadDefaultLevel();
    var mismatches: usize = 0;

    var seed: u32 = 1;
    while (seed <= 20) : (seed += 1) {
        rnd.seed(seed);
        flies.spawn_flies();
        const zig_flies = flies.flies;

        rnd.seed(seed);
        c_spawn_flies();

        for (0..flies.num_flies) |k| {
            if (zig_flies[k].x != flies.flies[k].x or zig_flies[k].y != flies.flies[k].y) {
                std.debug.print("spawn seed {d}: fly[{d}] zig=({d},{d}) c_ref=({d},{d})\n", .{
                    seed, k, zig_flies[k].x, zig_flies[k].y, flies.flies[k].x, flies.flies[k].y,
                });
                mismatches += 1;
            }
        }
    }

    try std.testing.expectEqual(@as(usize, 0), mismatches);
}

test "get_closest_player_to_point matches the C reference" {
    loadDefaultLevel();
    var mismatches: usize = 0;

    const corners = [_]i32{ 0, 8, 100, 175, 300, 351 };
    for (corners) |px_ | {
        for (corners) |py_| {
            setPlayers(
                .{ px(50), px(300), px(10), px(340) },
                .{ px(50), px(200), px(230), px(5) },
                .{ 1, 1, 1, 1 },
            );
            var zig_dist: c_int = -1;
            var zig_closest: c_int = -1;
            flies.get_closest_player_to_point(px_, py_, &zig_dist, &zig_closest);

            var c_dist: c_int = -1;
            var c_closest: c_int = -1;
            c_get_closest_player_to_point(px_, py_, &c_dist, &c_closest);

            if (zig_dist != c_dist or zig_closest != c_closest) {
                std.debug.print("point ({d},{d}): zig=({d},{d}) c_ref=({d},{d})\n", .{ px_, py_, zig_dist, zig_closest, c_dist, c_closest });
                mismatches += 1;
            }
        }
    }

    try std.testing.expectEqual(@as(usize, 0), mismatches);
}
