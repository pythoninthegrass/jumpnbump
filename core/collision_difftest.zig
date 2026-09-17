// Tier-B differential tests for TASK-011.03: core/collision.zig's port of
// main.c's collision_check()/player_kill()/processKillPacket() vs the
// renamed-C reference in core/c_ref/collision.c (extracted verbatim from
// main.c by core/c_ref/extract_collision.py), wired up in core/build.zig
// via compileRenamedCRef.
//
// Method (the playbook's Tier-B shape, same one-tick-two-runtimes replay
// core/steer_difftest.zig established): both sides mutate one shared world.
// core/steer.zig owns the world (player[]/objects[]/ban_map/player_anims,
// in core/world.zig's canonical layout — reached here through
// core/c_ref/sim_harness.c's *_raw storage for player[]/ban_map[],
// which is what both core/collision.zig's extern mirrors and the C
// reference's `#define player player_raw` bind to), so there is exactly one
// world regardless of link order. Both sides consume one shared rnd()
// stream, re-seeded per tick: the gore spray's 144 draws and the death
// sfx's one draw are part of the compared state, so a differing draw count
// shows up as a world mismatch rather than a silent offset.
//
// Where the inputs come from. The Phase 1 corpus traces that exercise
// player bumps and kills are every trace with more than one headless
// player: 02-two-player-manual (scripted approach/jump pressure, AI off),
// 03-two-player-ai-kill / 04-two-player-ai-kill-nogore (the CPU chases and
// bump-kills the idle player, gore on/off so both sides of the no_gore gate
// are replayed), and 05-four-players-ai (all four enabled, multiple
// concurrent bump-kills). Their key streams are generated into
// core/collision_corpus_traces.zig by core/c_ref/gen_collision_traces.py.
// A bump is a property of the *moving* world, so each replayed tick runs
// the game-loop order around collision_check (main.c:1362-1367):
// cpu_move() (TASK-011.05's Zig port, for the traces' AI players),
// steer_players() (the extracted C reference from core/c_ref/steer.c,
// shared unmodified between the two sides — it is the same code on both,
// already differentially validated in TASK-011.02, and it is what brings
// the pair into overlap), then the pair under test.
//
// AC#1: "zig build difftest passes against the Phase 1 corpus for all
// traces exercising player bumps and kills, with zero checksum
// mismatches". Every field the per-frame canonical checksum folds
// (docs/checksum-format.md: bumps, bumped[4], x/y/x_add/y_add, dead_flag,
// anim/frame/frame_tick/image, objects[], rnd_call_count) is compared
// field-for-field per tick; the corpus's own checksums stay the end-to-end
// oracle (tests/corpus/README.md's reproduce command).
//
// AC#2: "The bumped[4] per-player bump tracking and bumps counter match
// the C original exactly". The bump counters are compared on every tick,
// the kill-bearing ticks are asserted to exist per trace (a trace that
// never produced a bump would make its comparison vacuous), and the
// targeted-vector test below drives the bump/kill branch corners — both
// x_add sign patterns, the else-branch undo, and the anim == 6 re-kill
// guard that makes bumps/bumped count exactly once per kill.
const std = @import("std");
const rnd_mod = @import("rnd.zig");
const world = @import("world.zig");
const steer = @import("steer.zig");
const cpu_move_mod = @import("cpu_move.zig");
const collision = @import("collision.zig");

// core/c_ref/steer.c (TASK-011.02's reference): its steer_players still
// carries the cpu_move()/update_player_actions() prologue, which the C-side
// tick below wants real, so it is NOT defined away in this binary.
extern fn c_steer_players() void;
extern fn c_position_player(player_num: c_int) void;
extern fn collision_tick() void;
extern fn player_kill_gate(c1: c_int, c2: c_int) void;
extern fn kill_packet_entry(killer: c_int, victim: c_int, x: c_int, y: c_int) c_int;

// ---------------------------------------------------------------------------
// Shared world.
//
// player_raw[]/objects_raw[]/ban_map_raw[]/keyb[] are
// core/c_ref/sim_harness.c's single shared definition: the arrays
// core/collision.zig, core/steer.zig and core/cpu_move.zig declare extern,
// and what the C references' `#define player player_raw` (and friends)
// bind to, so every side reads and writes the very same memory.
// player_anims[]/object_anims[] are core/steer.zig's exports under their
// own names. is_server / is_net are pinned to the headless server values
// the corpus was recorded on (is_net is never set headless).
// ---------------------------------------------------------------------------

extern var player_raw: [world.max_players]world.Player;
extern var objects_raw: [world.num_objects]world.Object;
extern var ban_map_raw: [world.ban_rows][world.ban_cols]c_uint;
extern var keyb: [256]i8;

const player_ptr: *[world.max_players]world.Player = @constCast(&player_raw);

var is_server_one: c_int = 1;
var is_net_zero: c_int = 0;

comptime {
    @export(&is_server_one, .{ .name = "is_server" });
    @export(&is_net_zero, .{ .name = "is_net" });
}

// The C references' rnd() — same core/rnd.zig call the Zig port makes, so
// both consume one libc stream.
export fn c_rnd_from(max: c_ushort) c_ushort {
    return rnd_mod.rnd(max);
}

// The C references' dj_play_sfx — records (id, evaluated freq) into
// core/steer.zig's C-side trace; its argument expression (the checksummed
// rnd(2000) draw) already evaluated on the C side before the call.
export fn dj_play_sfx(id: c_int, freq: c_int, vol: c_int, pan: c_int, unused: c_int, channel: c_int) void {
    _ = .{ vol, pan, unused, channel };
    steer.sfxRecordC(id, freq);
}

// core/c_ref/collision.c's player_kill calls this instead of
// serverSendKillPacket: main.c fills a NETCMD_KILL packet with the victim's
// live x/y and runs processKillPacket on it, so the harness forwards the
// same four values.
export fn kill_dispatch(killer: c_int, victim: c_int, x: c_int, y: c_int) void {
    _ = kill_packet_entry(killer, victim, x, y);
}

// cpu_move() is core/cpu_move.zig's own export (TASK-011.05 validated it
// against its own reference): the extracted steer.c and steer.zig's
// prologue both bind to that single definition, so both sides run the same
// AI. serverSendAlive is collision.zig's link-boundary extern, never
// reached while is_net is 0.
export fn serverSendAlive(playerid: c_int) void {
    // Only reachable behind is_net, which this harness pins to 0.
    _ = playerid;
}

// update_player_actions() (sdl/input.c:42) for the headless build: the
// client_player_num < 0 branch, which is keyb[] read through the same
// (unsigned char) index key_pressed() uses (the C's JOY_* macros are false
// with no joysticks, and tellServerPlayerMoved is a no-op without is_net,
// so the netcode in that branch has no headless effect).
export fn update_player_actions() void {
    for (player_ptr, 0..) |*p, i| {
        const keys = cpu_move_mod.key_pl[i];
        p.action_left = @intFromBool(keyb[@intCast(keys[0] & 0x7f)] == 1);
        p.action_right = @intFromBool(keyb[@intCast(keys[1] & 0x7f)] == 1);
        p.action_up = @intFromBool(keyb[@intCast(keys[2] & 0x7f)] == 1);
    }
}

/// main_info.no_gore — the C reference reads only this field of main_info
/// on the kill path, so it owns a one-field struct twin (collision.c's
/// preamble) defined by the harness here. noGoreC() is the one place both
/// sides' flags are set.
pub const MainInfo = extern struct {
    no_gore: c_int = 0,
};
export var main_info: MainInfo = .{};

/// Set the kill-gore flag on both sides: collision.zig's `no_gore` mirror
/// and the C reference's `main_info.no_gore`.
fn noGoreC(value: c_int) void {
    collision.no_gore = value;
    main_info.no_gore = value;
}

// ---------------------------------------------------------------------------
// Tables and level state, loaded the way init_program()/init_level() leave
// them (same transcription core/steer_difftest.zig uses).
// ---------------------------------------------------------------------------

const default_ban_map = [world.ban_rows][world.ban_cols]u32{
    .{ 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0 },
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

fn loadPlayerAnims() void {
    const data = [_]c_int{
        1, 0, 0, 0x7fff, 0, 0, 0, 0, 0, 0,
        4, 0, 0, 4, 1, 4, 2, 4, 3, 4,
        1, 0, 4, 0x7fff, 0, 0, 0, 0, 0, 0,
        4, 2, 5, 8, 6, 10, 7, 3, 6, 3,
        1, 0, 6, 0x7fff, 0, 0, 0, 0, 0, 0,
        2, 1, 5, 8, 4, 0x7fff, 0, 0, 0, 0,
        1, 0, 8, 5, 0, 0, 0, 0, 0, 0,
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
/// void tiles. Their draws ride the shared stream.
fn seedLevelObjects() void {
    for (0..16) |r| for (0..22) |col| {
        if (ban_map_raw[r][col] == steer.ban_spring) {
            steer.add_object(0, @intCast(col * 16), @intCast(r * 16), 0, 0, 0, 5);
        }
    };
    const kinds = [_]c_int{ 3, 3, 4, 4 }; // OBJ_YEL_BUTFLY x2, OBJ_PINK_BUTFLY x2
    for (kinds) |kind| {
        while (true) {
            const s1: c_int = @intCast(rnd_mod.rnd(22));
            const s2: c_int = @intCast(rnd_mod.rnd(16));
            if (ban_map_raw[@intCast(s2)][@intCast(s1)] == steer.ban_void) {
                const vx: c_int = (s1 << 4) +% 8;
                const vy: c_int = (s2 << 4) +% 8;
                const va: c_int = @bitCast(@as(u32, @bitCast(@as(c_int, rnd_mod.rnd(65535)) -% 32768)) *% 2);
                const vb: c_int = @bitCast(@as(u32, @bitCast(@as(c_int, rnd_mod.rnd(65535)) -% 32768)) *% 2);
                steer.add_object(kind, vx, vy, va, vb, 0, 0);
                break;
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Snapshot / compare over the whole canonical state.
// ---------------------------------------------------------------------------

const Snapshot = struct {
    players: [world.max_players]world.Player,
    objects: [world.num_objects]world.Object,
    rnd_calls: c_uint,
    keyb: [256]i8,
};

fn snapshot() Snapshot {
    return .{
        .players = player_raw,
        .objects = objects_raw,
        .rnd_calls = rnd_mod.rnd_call_count,
        .keyb = keyb,
    };
}

fn restore(s: *const Snapshot) void {
    player_raw = s.players;
    objects_raw = s.objects;
    rnd_mod.rnd_call_count = s.rnd_calls;
    keyb = s.keyb;
}

fn bumpTotal(s: *const Snapshot) c_int {
    var total: c_int = 0;
    for (s.players) |p| total +%= p.bumps;
    return total;
}

fn compareWorld(name: []const u8, tick: usize, want: *const Snapshot, mismatches: *usize) void {
    for (want.players, 0..) |wp, i| {
        inline for (std.meta.fields(world.Player)) |f| {
            if (f.type == [world.max_players]c_int) {
                for (wp.bumped, 0..) |wv, b| {
                    if (wv != player_raw[i].bumped[b]) {
                        std.debug.print("{s} tick {d} player[{d}].bumped[{d}]: zig={d} != c={d}\n", .{ name, tick, i, b, player_raw[i].bumped[b], wv });
                        mismatches.* += 1;
                    }
                }
            } else {
                const wv: c_int = @field(wp, f.name);
                const zv: c_int = @field(player_raw[i], f.name);
                if (wv != zv) {
                    std.debug.print("{s} tick {d} player[{d}].{s}: zig={d} != c={d}\n", .{ name, tick, i, f.name, zv, wv });
                    mismatches.* += 1;
                }
            }
        }
    }
    for (want.objects, 0..) |wo, i| {
        inline for (std.meta.fields(world.Object)) |f| {
            const wv: c_int = @field(wo, f.name);
            const zv: c_int = @field(objects_raw[i], f.name);
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

fn compareSfx(name: []const u8, tick: usize, c_sfx: *const [steer.sfx_trace_len]c_int, c_n: usize, mismatches: *usize) void {
    const z_n = steer.sfxCountZ();
    if (z_n != c_n) {
        std.debug.print("{s} tick {d}: sfx count zig={d} != c={d}\n", .{ name, tick, z_n, c_n });
        mismatches.* += 1;
        return;
    }
    for (0..c_n) |i| {
        if (steer.sfx_trace_z[i] != c_sfx[i]) {
            std.debug.print("{s} tick {d}: sfx[{d}] zig={d} != c={d}\n", .{ name, tick, i, steer.sfx_trace_z[i], c_sfx[i] });
            mismatches.* += 1;
        }
    }
}

// ---------------------------------------------------------------------------
// One tick, both sides.
// ---------------------------------------------------------------------------

/// headless_load_frame_keys() (sdl/interrpt.c:314): clear the twelve bunny
/// keys, then set the ones this tick's trace line names. keyb[] holds them
/// exactly as the headless C build does; update_player_actions() (the
/// harness export above) translates them into player[].action_* on both
/// sides, inside c_steer_players' own prologue.
fn applyKeys(keys: []const []const u8) void {
    for (cpu_move_mod.key_pl) |pl| {
        for (pl) |key| keyb[@intCast(key & 0x7f)] = 0;
    }
    for (keys) |key| {
        // "p{1..4}_{left,right,jump}" — the corpus key vocabulary, mapped
        // through the same table cpu_move()/update_player_actions use.
        if (key.len < 8 or key[0] != 'p') continue;
        const slot: usize = key[1] - '1';
        const which: usize = if (std.mem.eql(u8, key[3..], "left")) 0 else if (std.mem.eql(u8, key[3..], "right")) 1 else if (std.mem.eql(u8, key[3..], "jump")) 2 else continue;
        keyb[@intCast(cpu_move_mod.key_pl[slot][which] & 0x7f)] = 1;
    }
}

/// game_loop()'s tick order around the pair under test (main.c:1362-1367):
/// steer_players() (whose prologue runs cpu_move() and
/// update_player_actions(); on the C side that's the extracted reference
/// with cpu_move() routed to the TASK-011.05 Zig port, on the Zig side the
/// Zig port with its own cpu_move() call defined by collision.zig's twin —
/// see core/collision.zig's header for why steer.zig does not re-issue it)
/// and then collision_check().
fn tickC() void {
    c_steer_players();
    collision_tick();
}

fn tickZig() void {
    // Same prologue the extracted C runs inside c_steer_players: the AI
    // (core/cpu_move.zig, whose export the C side binds to as well) and the
    // headless key translation above, then steer's body and the pair.
    cpu_move_mod.cpu_move();
    update_player_actions();
    steer.steer_players();
    collision.collision_check();
}

/// Both sides' tick from one starting world, one key state and one seed:
/// run C, snapshot, restore, run Zig, compare. Returns the C side's world
/// so callers can inspect what happened (e.g. whether the tick scored a
/// bump).
fn tickBoth(name: []const u8, tick: usize, tick_seed: c_uint, keys: []const []const u8, mismatches: *usize) Snapshot {
    const start = snapshot();

    rnd_mod.seed(tick_seed);
    applyKeys(keys);
    steer.sfxReset();
    tickC();
    const c_sfx = steer.sfx_trace_c;
    const c_sfx_n = steer.sfxCountC();
    const c_result = snapshot();

    restore(&start);
    rnd_mod.seed(tick_seed);
    applyKeys(keys);
    steer.sfxReset();
    tickZig();
    compareSfx(name, tick, &c_sfx, c_sfx_n, mismatches);
    compareWorld(name, tick, &c_result, mismatches);
    return c_result;
}

// ---------------------------------------------------------------------------
// Corpus replay.
// ---------------------------------------------------------------------------

fn setupWorld() void {
    player_raw = std.mem.zeroes([world.max_players]world.Player);
    objects_raw = std.mem.zeroes([world.num_objects]world.Object);
    ban_map_raw = default_ban_map;
    steer.pogostick = 0;
    steer.bunnies_in_space = 0;
    steer.jetpack = 0;
    steer.blood_is_thicker_than_water = 0;
    noGoreC(0);
    cpu_move_mod.ai = [_]c_int{0} ** 4;
    @memset(&keyb, 0);
    loadPlayerAnims();
    loadObjectAnims();
}

/// init_level()'s placement phase: enable the trace's players and drop each
/// at a random spawn through the C's position_player, then check the Zig
/// port lands identically (a placement disagreement would otherwise show up
/// mid-replay as an unexplainable offset) before the compared ticks start.
fn placePlayers(name: []const u8, players: usize, ai_mask: usize, seed: c_uint) void {
    rnd_mod.seed(seed);
    for (0..players) |i| {
        player_raw[i].enabled = 1;
        c_position_player(@intCast(i));
    }
    const c_placed = player_raw;
    player_raw = [_]world.Player{.{}} ** world.max_players;
    for (0..players) |i| player_raw[i].enabled = 1;
    rnd_mod.seed(seed);
    for (0..players) |i| {
        steer.position_player(@intCast(i));
    }
    var placement_mismatches: usize = 0;
    for (c_placed, 0..) |cp, i| {
        inline for (std.meta.fields(world.Player)) |f| {
            if (f.type == [world.max_players]c_int) {
                for (cp.bumped, 0..) |wv, b| {
                    if (wv != player_raw[i].bumped[b]) placement_mismatches += 1;
                }
            } else if (@field(cp, f.name) != @field(player_raw[i], f.name)) {
                placement_mismatches += 1;
            }
        }
    }
    if (placement_mismatches != 0) {
        std.debug.print("{s}: position_player placement disagrees ({d} fields)\n", .{ name, placement_mismatches });
        std.debug.assert(placement_mismatches == 0);
    }
    player_raw = c_placed;
    for (0..world.max_players) |i| {
        cpu_move_mod.ai[i] = if (i < players) @intCast((ai_mask >> @intCast(i)) & 1) else 0;
    }
}

fn replay(trace: *const Trace, seed: c_uint, mismatches: *usize) void {
    setupWorld();
    noGoreC(if (trace.no_gore) 1 else 0);
    placePlayers(trace.name, trace.players, trace.ai_mask, seed);
    rnd_mod.seed(seed +% 1);
    seedLevelObjects();

    var kill_ticks: usize = 0;
    for (trace.ticks, 0..) |keys, tick| {
        const before = killCount(&snapshot());
        const tick_seed = seed +% 1000 +% @as(c_uint, @intCast(tick)) *% 7919;
        const c_result = tickBoth(trace.name, tick, tick_seed, keys, mismatches);
        // A tick where the C's bump counters moved must show up; a trace
        // whose replay never reaches a bump scores nothing for AC#2.
        if (killCount(&c_result) > before) kill_ticks += 1;
    }

    if (trace.expect_kills and kill_ticks == 0) {
        std.debug.print("{s}: no tick produced a bump/kill — the comparison would be vacuous for this trace\n", .{trace.name});
        mismatches.* += 1;
    }
}

fn killCount(s: *const Snapshot) c_int {
    var total: c_int = 0;
    for (s.players) |p| {
        total +%= p.bumps;
        for (p.bumped) |b| total +%= b;
    }
    return total;
}

// ---------------------------------------------------------------------------
// The corpus traces (tests/corpus/, generated into
// core/collision_corpus_traces.zig by core/c_ref/gen_collision_traces.py):
// every trace with more than one headless player, i.e. everything in the
// Phase 1 corpus that runs players into each other. no_gore comes from the
// trace's meta extra_flags.
// ---------------------------------------------------------------------------

const collision_traces = @import("collision_corpus_traces.zig");
const Trace = collision_traces.Trace;

test "collision.zig matches the extracted C reference across the bump/kill corpus traces" {
    var mismatches: usize = 0;
    var total_ticks: usize = 0;
    var kills_seen: usize = 0;
    inline for (collision_traces.traces) |entry| {
        replay(&entry.trace, entry.seed, &mismatches);
        total_ticks += entry.trace.ticks.len;
        kills_seen += 1;
    }
    if (total_ticks < 500) {
        std.debug.print("collision difftest replayed only {d} ticks\n", .{total_ticks});
        mismatches += 1;
    }
    if (kills_seen < 4) {
        std.debug.print("collision difftest replayed only {d} traces\n", .{kills_seen});
        mismatches += 1;
    }
    try std.testing.expectEqual(@as(usize, 0), mismatches);
}

// ---------------------------------------------------------------------------
// Targeted vectors. The corpus reaches the branches its scripted gameplay
// happens to walk through; the probes below drive the branch corners
// directly — the full grid of vertical gaps across the 5-px kill
// threshold, horizontal gaps across the ±12-px overlap thresholds, and
// every (x_add sign) x (y_add sign) combination the bump resolution and
// the kill guard switch on, at both draw orders — by setting the world and
// running one collision_check() on each side.
// ---------------------------------------------------------------------------

const gaps_v = [_]c_int{ -12, -6, -1, 0, 1, 5, 6, 8, 11 };
const gaps_h = [_]c_int{ -11, -6, -1, 0, 1, 6, 11 };
const vel = [_]c_int{ -65536, -1, 0, 1, 65536 };

fn probeWorld(gv: c_int, gh: c_int, v0: c_int, v1: c_int, comptime swap: usize, anim6: c_int) void {
    player_raw = std.mem.zeroes([world.max_players]world.Player);
    objects_raw = std.mem.zeroes([world.num_objects]world.Object);
    noGoreC(0);
    const p0: usize = comptime swap;
    const p1: usize = comptime 1 - swap;
    player_raw[p0] = .{
        .enabled = 1,
        .jump_ready = 1,
        .x = 100 << 16,
        .y = (100 + gv) << 16,
        .x_add = v0,
        .y_add = v1,
    };
    player_raw[p1] = .{
        .enabled = 1,
        .jump_ready = 1,
        .x = (100 + gh) << 16,
        .y = 100 << 16,
        .x_add = v1,
        .y_add = v0,
        .anim = anim6,
    };
}

fn runGrid(comptime swap: usize, mismatches: *usize, probes: *usize, bumps_seen: *usize) void {
    var seed: c_uint = 1 + @as(c_uint, @intCast(swap)) *% 977;
    for (gaps_v) |gv| {
        for (gaps_h) |gh| {
            for (vel) |v0| {
                for (vel) |v1| {
                    // anim 0: a kill can happen; anim 6: the re-kill guard
                    // (bumps must NOT move) gets the same geometry.
                    for ([_]c_int{ 0, 6 }) |anim6| {
                        setupWorld();
                        probeWorld(gv, gh, v0, v1, swap, anim6);
                        seed +%= 1;
                        const before = bumpTotal(&snapshot());
                        const after = tickBoth("probe", 0, seed, &.{}, mismatches);
                        if (bumpTotal(&after) > before) bumps_seen.* += 1;
                        probes.* += 1;
                    }
                }
            }
        }
    }
}

test "the full bump/kill vector grid matches the extracted C reference" {
    var mismatches: usize = 0;
    var probes: usize = 0;
    var bumps_seen: usize = 0;

    runGrid(0, &mismatches, &probes, &bumps_seen);
    runGrid(1, &mismatches, &probes, &bumps_seen);

    if (probes < 4000) {
        std.debug.print("bump/kill vector grid ran only {d} cases\n", .{probes});
        mismatches += 1;
    }
    if (bumps_seen == 0) {
        std.debug.print("bump/kill vector grid produced no bumps at all\n", .{});
        mismatches += 1;
    }
    try std.testing.expectEqual(@as(usize, 0), mismatches);
}
