// Tier-B differential tests for TASK-011.02: core/steer.zig's port of
// main.c's steer_players()/position_player() vs the renamed-C reference in
// core/c_ref/steer.c (extracted verbatim from main.c by
// core/c_ref/extract_steered.py), wired up in core/build.zig via
// compileRenamedCRef.
//
// Method (the playbook's Tier-B shape, grown from rnd_difftest.zig's
// fresh-seed pairs into a stateful tick replay): both sides mutate one
// shared world arena. core/steer.zig owns the storage (player[]/objects[]/
// ban_map/player_anims/object_anims/is_server as exported globals under the
// C names, per the playbook's globals-ownership rule) — and this harness
// rebinds the C reference's same-named externs onto it by writing steer.zig's
// own exported symbols over the C's link-time common symbols, so there is
// exactly one world regardless of link order. Both sides also consume one
// shared rnd() stream.
//
// The stream: core/steer.zig's `extern fn rnd` binds to core/rnd.zig's
// exported rnd (libc rand(), rnd_call_count included); the C reference's
// `#define rnd(max) c_rnd_from(max)` binds to this file's c_rnd_from, which
// calls the same core/rnd.zig function. Before each side's tick the harness
// re-seeds libc's PRNG to that tick's seed, so the k-th draw of the C run
// and the k-th draw of the Zig run are the same value, and a differing draw
// count or a differing value shows up as a world-state mismatch.
//
// Per tick: snapshot, run the C side, deep-copy its world, restore the
// snapshot, re-seed, run the Zig side, compare every field. Because both
// sides start the tick from the same world and the same PRNG state, the
// only source of a difference is the ported logic itself — tile handling,
// gravity/jump constants, snap arithmetic, or rnd() consumption.
//
// AC#1: "zig build difftest passes against the Phase 1 corpus for all
// traces exercising water/ice/spring tiles and jumping". The replayed tick
// inputs are the scripted per-frame key lists from the four corpus traces
// whose meta.json mechanic is water/ice/spring/jump gameplay —
// 01-single-player-basic (walk/jump/land), 06-water-immersion,
// 07-spring-bounce, 08-ice-slide — with each trace's meta
// headless_players/headless_ai_mask (all four record mask 0, so
// steer_players runs on scripted actions alone, exactly as the C ran them).
// The corpus checksums remain the whole-pipeline oracle (tests/corpus/
// README.md's reproduce command); this differential is the per-subsystem
// one the playbook calls for, and it fails first when a physics constant
// or threshold drifts.
//
// Out of the replay because they are out of this task: cpu_move()
// (TASK-011.05), update_objects()/add_object animation advance
// (TASK-011.04) and update_flies() (TASK-011.06). The harness drives one
// steer_players tick at a time over the objects[] slots init_level() left.
const std = @import("std");
const rnd_mod = @import("rnd.zig");
const world = @import("world.zig");
const steer = @import("steer.zig");
// TASK-011.04: add_object()'s canonical home moved from steer.zig to
// objects.zig; steer_players() reaches it as an extern fn and the C reference
// (c_steer_players) calls the same add_object symbol, so the harness drives
// and the world both go through objects.add_object. objects.zig's own extern
// globals (objects[]/object_anims[]/ban_map[]) resolve to steer.zig's exports.
const objects_mod = @import("objects.zig");

extern fn c_steer_players() void;
extern fn c_position_player(player_num: c_int) void;
extern fn c_cpu_move() void;
extern fn c_update_player_actions() void;

// ---------------------------------------------------------------------------
// World storage: core/steer.zig's exported globals ARE the world (the
// playbook's globals-ownership rule; the C reference binds its extern
// declarations to the same C names through C linkage, so both sides of the
// differential mutate one world). `players`/`objects` below are this
// harness's private snapshot buffers — snapshot() copies the live world
// into them, restore() writes it back — and the `p`/`o` aliases keep the
// replay code below reading like the module's own names.
// ---------------------------------------------------------------------------

var players: [world.max_players]world.Player = undefined;
var objects: [world.num_objects]world.Object = undefined;

/// is_server/is_net: one shared copy for steer.zig's `extern var
/// is_server` and the C reference's same-named extern, pinned to the
/// headless server path the corpus was recorded on (is_net is never set
/// headless).
var is_server_one: c_int = 1;
var is_net_zero: c_int = 0;

comptime {
    @export(&is_server_one, .{ .name = "is_server" });
    @export(&is_net_zero, .{ .name = "is_net" });
}

/// main.c:74's built-in grid (the shape the probe's synthetic world uses).
const probe_default_ban_map = [world.ban_rows][world.ban_cols]u32{
    .{ 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0 },
    .{ 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1 },
    .{ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1 },
    .{ 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 1, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1 },
    .{ 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 0, 0, 0, 0, 0, 1, 3, 3, 3, 1, 1, 1 },
    .{ 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    .{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
};

// core/c_ref/steer.c's extracted steer_players still carries its
// cpu_move()/update_player_actions() prologue; TASK-011.05 and the input
// layer own those, so the harness defines them away and the C tick starts
// where the port's tick starts.
export fn cpu_move() void {}
export fn update_player_actions() void {}

// The C reference's rnd() — same core/rnd.zig call the Zig port makes, so
// both consume one libc stream.
export fn c_rnd_from(max: c_ushort) c_ushort {
    return rnd_mod.rnd(max);
}

// The C reference's dj_play_sfx — a no-op; its argument expression (the
// rnd(2000) draw) already evaluated on the C side before the call.
export fn dj_play_sfx(id: c_int, freq: c_int, vol: c_int, pan: c_int, unused: c_int, channel: c_int) void {
    _ = .{ vol, pan, unused, channel };
    steer.sfxRecordC(id, freq);
}

// ---------------------------------------------------------------------------
// Tables and level state, loaded the way init_program()/init_level() leave
// them.
// ---------------------------------------------------------------------------

/// The level's default ban_map from main.c:74 (the grid data/levelmap.txt
/// packs to, which is what the corpus was recorded against). Row 16 is the
/// force-filled solid floor.
const default_ban_map = [world.ban_rows][world.ban_cols]u32{
    .{ 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0 },
    .{ 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1 },
    .{ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1 },
    .{ 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 1, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1 },
    .{ 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 0, 0, 0, 0, 0, 1, 3, 3, 3, 1, 1, 1 },
    .{ 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    .{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
};

/// player_anim_data from init_program (main.c:3105-3112), unfolded into
/// player_anims exactly like main.c:3269-3273.
fn loadPlayerAnims() void {
    const data = [_]c_int{
        1, 0, 0, 0x7fff, 0, 0,      0, 0, 0, 0,
        4, 0, 0, 4,      1, 4,      2, 4, 3, 4,
        1, 0, 4, 0x7fff, 0, 0,      0, 0, 0, 0,
        4, 2, 5, 8,      6, 10,     7, 3, 6, 3,
        1, 0, 6, 0x7fff, 0, 0,      0, 0, 0, 0,
        2, 1, 5, 8,      4, 0x7fff, 0, 0, 0, 0,
        1, 0, 8, 5,      0, 0,      0, 0, 0, 0,
    };
    for (0..7) |a| {
        steer.player_anims[a].num_frames = data[a * 10];
        steer.player_anims[a].restart_frame = data[a * 10 + 1];
        for (0..4) |f| {
            steer.player_anims[a].frame[f].image = data[a * 10 + f * 2 + 2];
            steer.player_anims[a].frame[f].ticks = data[a * 10 + f * 2 + 3];
        }
    }
}

/// object_anims from main.c:103-219. Rows 3-7 are the butterfly/fur/flesh
/// frames init_level seeds; only the spring reset and add_object read the
/// table inside this task's scope, but all rows load so a stray anim index
/// reads the same table on both sides.
fn loadObjectAnims() void {
    const Row = struct { nf: c_int, rf: c_int, frames: [10][2]c_int };
    const rows = [_]Row{
        .{ .nf = 6, .rf = 0, .frames = .{ .{ 0, 3 }, .{ 1, 3 }, .{ 2, 3 }, .{ 3, 3 }, .{ 4, 3 }, .{ 5, 3 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 } } }, // spring
        .{ .nf = 9, .rf = 0, .frames = .{ .{ 6, 2 }, .{ 7, 2 }, .{ 8, 2 }, .{ 9, 2 }, .{ 10, 2 }, .{ 11, 2 }, .{ 12, 2 }, .{ 13, 2 }, .{ 14, 2 }, .{ 0, 0 } } }, // splash
        .{ .nf = 6, .rf = 0, .frames = .{ .{ 15, 3 }, .{ 16, 3 }, .{ 16, 3 }, .{ 17, 3 }, .{ 18, 3 }, .{ 19, 3 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 } } }, // smoke
        .{ .nf = 10, .rf = 0, .frames = .{ .{ 20, 2 }, .{ 21, 2 }, .{ 22, 2 }, .{ 23, 2 }, .{ 24, 2 }, .{ 25, 2 }, .{ 24, 2 }, .{ 23, 2 }, .{ 22, 2 }, .{ 21, 2 } } },
        .{ .nf = 10, .rf = 0, .frames = .{ .{ 26, 2 }, .{ 27, 2 }, .{ 28, 2 }, .{ 29, 2 }, .{ 30, 2 }, .{ 31, 2 }, .{ 30, 2 }, .{ 29, 2 }, .{ 28, 2 }, .{ 27, 2 } } },
        .{ .nf = 10, .rf = 0, .frames = .{ .{ 26, 2 }, .{ 27, 2 }, .{ 28, 2 }, .{ 29, 2 }, .{ 30, 2 }, .{ 31, 2 }, .{ 30, 2 }, .{ 29, 2 }, .{ 28, 2 }, .{ 27, 2 } } },
        .{ .nf = 10, .rf = 0, .frames = .{ .{ 26, 2 }, .{ 27, 2 }, .{ 28, 2 }, .{ 29, 2 }, .{ 30, 2 }, .{ 31, 2 }, .{ 30, 2 }, .{ 29, 2 }, .{ 28, 2 }, .{ 27, 2 } } },
        .{ .nf = 8, .rf = 0, .frames = .{ .{ 32, 2 }, .{ 33, 2 }, .{ 34, 2 }, .{ 35, 2 }, .{ 36, 2 }, .{ 37, 2 }, .{ 38, 2 }, .{ 39, 2 }, .{ 0, 0 }, .{ 0, 0 } } },
    };
    for (rows, 0..) |row, i| {
        steer.object_anims[i].num_frames = row.nf;
        steer.object_anims[i].restart_frame = row.rf;
        for (row.frames, 0..) |fr, f| {
            steer.object_anims[i].frame[f].image = fr[0];
            steer.object_anims[i].frame[f].ticks = fr[1];
        }
    }
}

/// init_level()'s objects[] seeding (main.c:2907-2930): an OBJ_SPRING in
/// every spring tile, then two yellow and two pink butterflies at random
/// void tiles. The butterfly draws ride the shared stream; their per-tick
/// motion is update_objects() (TASK-011.04) and stays frozen here.
fn seedLevelObjects() void {
    for (0..16) |r| for (0..22) |col| {
        if (steer.ban_map[r][col] == steer.ban_spring) {
            objects_mod.add_object(0, @intCast(col * 16), @intCast(r * 16), 0, 0, 0, 5);
        }
    };
    const kinds = [_]c_int{ 3, 3, 4, 4 }; // OBJ_YEL_BUTFLY x2, OBJ_PINK_BUTFLY x2
    for (kinds) |kind| {
        while (true) {
            const s1: c_int = @intCast(rnd_mod.rnd(22));
            const s2: c_int = @intCast(rnd_mod.rnd(16));
            if (steer.ban_map[@intCast(s2)][@intCast(s1)] == steer.ban_void) {
                const vx: c_int = (s1 << 4) +% 8;
                const vy: c_int = (s2 << 4) +% 8;
                const va: c_int = @bitCast(@as(u32, @bitCast(@as(c_int, rnd_mod.rnd(65535)) -% 32768)) *% 2);
                const vb: c_int = @bitCast(@as(u32, @bitCast(@as(c_int, rnd_mod.rnd(65535)) -% 32768)) *% 2);
                objects_mod.add_object(kind, vx, vy, va, vb, 0, 0);
                break;
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Snapshot / compare.
// ---------------------------------------------------------------------------

const Snapshot = struct {
    players: [world.max_players]world.Player,
    objects: [world.num_objects]world.Object,
    rnd_calls: c_uint,
};

fn snapshot() Snapshot {
    return .{
        .players = steer.player,
        .objects = steer.objects,
        .rnd_calls = rnd_mod.rnd_call_count,
    };
}

fn restore(s: *const Snapshot) void {
    steer.player = s.players;
    steer.objects = s.objects;
    rnd_mod.rnd_call_count = s.rnd_calls;
}

fn comparePlayer(name: []const u8, tick: usize, idx: usize, want: world.Player, got: world.Player, mismatches: *usize) void {
    inline for (std.meta.fields(world.Player)) |f| {
        if (f.type == [world.max_players]c_int) {
            for (want.bumped, 0..) |wv, b| {
                if (wv != got.bumped[b]) {
                    std.debug.print("{s} tick {d} player[{d}].bumped[{d}]: zig={d} != c={d}\n", .{ name, tick, idx, b, got.bumped[b], wv });
                    mismatches.* += 1;
                }
            }
        } else {
            const wv: c_int = @field(want, f.name);
            const zv: c_int = @field(got, f.name);
            if (wv != zv) {
                std.debug.print("{s} tick {d} player[{d}].{s}: zig={d} != c={d}\n", .{ name, tick, idx, f.name, zv, wv });
                mismatches.* += 1;
            }
        }
    }
}

fn compareWorld(name: []const u8, tick: usize, want: *const Snapshot, mismatches: *usize) void {
    for (want.players, 0..) |wp, i| {
        comparePlayer(name, tick, i, wp, steer.player[i], mismatches);
    }
    for (want.objects, 0..) |wo, i| {
        inline for (std.meta.fields(world.Object)) |f| {
            const wv: c_int = @field(wo, f.name);
            const zv: c_int = @field(steer.objects[i], f.name);
            if (wv != zv) {
                std.debug.print("{s} tick {d} objects[{d}].{s}: zig={d} != c={d}\n", .{ name, tick, i, f.name, zv, wv });
                mismatches.* += 1;
            }
        }
    }
    if (want.rnd_calls != rnd_mod.rnd_call_count) {
        std.debug.print("{s} tick {d}: rnd_call_count zig={d} != c={d}\n", .{ name, tick, rnd_mod.rnd_call_count, want.rnd_calls });
        mismatches.* += 1;
    }
}

// ---------------------------------------------------------------------------
// Replay.
// ---------------------------------------------------------------------------

fn applyKeys(keys: []const []const u8) void {
    for (&steer.player) |*p| {
        p.action_left = 0;
        p.action_right = 0;
        p.action_up = 0;
    }
    for (keys) |key| {
        // "p{1..4}_{left,right,jump}" — the corpus key vocabulary.
        // "p2_left" is 7 bytes; the old `< 8` bound silently dropped every
        // key and made the replay a no-op for both sides.
        if (key.len < 5 or key[0] != 'p') continue;
        const slot: usize = key[1] - '1';
        const rest = key[2..];
        if (rest.len < 2 or rest[0] != '_') continue;
        const p = &steer.player[slot];
        if (std.mem.eql(u8, rest[1..], "left")) {
            p.action_left = 1;
        } else if (std.mem.eql(u8, rest[1..], "right")) {
            p.action_right = 1;
        } else if (std.mem.eql(u8, rest[1..], "jump")) {
            p.action_up = 1;
        }
    }
}

/// init_level()'s placement phase for one trace: enable the trace's players
/// and drop each at a random spawn through the C's position_player (the Zig
/// port's position_player is checked against the same placement below).
/// Runs once per trace with the stream open, before any compared tick.
fn placePlayers(trace: *const Trace, seed: c_uint) void {
    rnd_mod.seed(seed);
    for (0..trace.players) |i| {
        c_position_player(@intCast(i));
    }
    // position_player implementations ever disagree, the very first
    // steer_players tick would fail with an unexplainable offset, so pin
    // the placement itself here as well.
    const c_placed = steer.player;
    steer.player = [_]world.Player{.{}} ** world.max_players;
    for (0..trace.players) |i| {
        steer.player[i].enabled = 1;
    }
    rnd_mod.seed(seed);
    for (0..trace.players) |i| {
        steer.position_player(@intCast(i));
    }
    var mismatches: usize = 0;
    for (0..trace.players) |i| {
        comparePlayer(trace.name, 0, i, c_placed[i], steer.player[i], &mismatches);
    }
    std.debug.assert(mismatches == 0);

    // Restore the C placement as the canonical starting world (the two are
    // now known equal) and let the level objects ride on top of it.
    steer.player = c_placed;
}

fn replay(trace: *const Trace, seed: c_uint, mismatches: *usize) void {
    setupWorld();
    // The trace's players only — steer.player carries over from the previous
    // trace otherwise, and a stale enabled player picks up scripted keys
    // aimed at another trace.
    for (0..world.max_players) |i| {
        steer.player[i].enabled = if (i < trace.players) 1 else 0;
    }
    placePlayers(trace, seed);
    rnd_mod.seed(seed +% 1);
    seedLevelObjects();

    for (trace.ticks, 0..) |keys, tick| {
        const start = snapshot();
        const tick_seed = seed +% 1000 +% @as(c_uint, @intCast(tick)) *% 7919;

        // --- C side ---
        rnd_mod.seed(tick_seed);
        applyKeys(keys);
        steer.sfxReset();
        c_steer_players();
        const c_sfx = steer.sfx_trace_c;
        const c_sfx_n = steer.sfxCountC();
        const c_result = snapshot();

        // --- Zig side: same seed, same actions, same starting world ---
        restore(&start);
        rnd_mod.seed(tick_seed);
        applyKeys(keys);
        steer.steer_players();
        // compare the sfx event streams (id+evaluated-freq) the two sides emitted
        if (steer.sfxCountZ() != c_sfx_n) {
            std.debug.print("{s} tick {d}: sfx count zig={d} != c={d}\n", .{ trace.name, tick, steer.sfxCountZ(), c_sfx_n });
            mismatches.* += 1;
        } else {
            for (0..c_sfx_n) |i| {
                if (steer.sfx_trace_z[i] != c_sfx[i]) {
                    std.debug.print("{s} tick {d}: sfx[{d}] zig={d} != c={d}\n", .{ trace.name, tick, i, steer.sfx_trace_z[i], c_sfx[i] });
                    mismatches.* += 1;
                }
            }
        }
        compareWorld(trace.name, tick, &c_result, mismatches);
    }
}

fn setupWorld() void {
    steer.player = std.mem.zeroes([world.max_players]world.Player);
    steer.objects = std.mem.zeroes([world.num_objects]world.Object);
    steer.ban_map = default_ban_map;
    steer.pogostick = 0;
    steer.bunnies_in_space = 0;
    steer.jetpack = 0;
    steer.blood_is_thicker_than_water = 0;
    loadPlayerAnims();
    loadObjectAnims();
}

// ---------------------------------------------------------------------------
// The traces. The scripted key frames are transcribed from
// tests/corpus/<name>.jsonl into the generated Zig file below — a plain
// `keys` list per tick, in corpus line order — by gen_corpus_traces.py,
// which runs as a build step (core/build.zig) and refreshes whenever the
// corpus changes. The checksum fields deliberately do not cross into this
// layer: the corpus checksums stay the end-to-end oracle
// (tests/corpus/README.md's reproduce command), and the differential here
// is field-for-field world state, per the header comment.
// ---------------------------------------------------------------------------

const corpus_traces = @import("corpus_traces.zig");
const Trace = corpus_traces.Trace;

test "steer.zig matches the extracted C reference across the water/ice/spring/jump traces" {
    var mismatches: usize = 0;

    var total_ticks: usize = 0;
    inline for (corpus_traces.traces) |entry| {
        replay(&entry.trace, entry.seed, &mismatches);
        total_ticks += entry.trace.ticks.len;
    }

    if (total_ticks < 600) {
        std.debug.print("steer difftest replayed only {d} ticks\n", .{total_ticks});
        mismatches += 1;
    }
    try std.testing.expectEqual(@as(usize, 0), mismatches);
}
