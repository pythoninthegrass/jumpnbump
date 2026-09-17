// Tier-B differential test for TASK-011.07: AC#1's full end-to-end replay.
//
// Every other TASK-011.* difftest compares its own subsystem against a
// renamed-C reference, synthesizing (or resynchronizing per tick) inputs
// that exercise it — the full checksum this task's AC#1 asks for only
// becomes possible once every subsystem is ported (TASK-011.02-06,
// already merged and individually validated), which is exactly what this
// task integrates. So there is no renamed-C reference here: the oracle is
// the corpus's own recorded per-tick checksums (tests/corpus/*.jsonl),
// captured from the real C binary (tests/corpus/README.md), replayed
// through core/game_loop.zig's step() with ONE continuous rnd() stream
// from the trace's seed (srand() runs exactly once at program start,
// main.c:3250) — not resynchronized per tick, since a real checksum
// mismatch several ticks after a small drift is exactly the failure mode
// AC#1 exists to catch.
//
// Setup mirrors main.c's own init sequence (main.c:1549-1595 for the
// headless-players/AI mask, main.c:2868 init_level()): enable the trace's
// players and set their ai[] bit, position_player() each enabled player in
// order, zero objects[], seed the level's spring/butterfly objects, then
// spawn_flies() if flies_enabled — all drawing from the one rnd() stream
// the trace's seed started, in that exact order, before the first
// replayed tick.
const std = @import("std");
const rnd_mod = @import("rnd.zig");
const world = @import("world.zig");
const steer = @import("steer.zig");
const cpu_move_mod = @import("cpu_move.zig");
const collision = @import("collision.zig");
const objects_mod = @import("objects.zig");
const flies_mod = @import("flies.zig");
const game_loop = @import("game_loop.zig");
const dat = @import("dat.zig");
const levelmap = @import("levelmap.zig");

extern var player_raw: [world.max_players]world.Player;
extern var objects_raw: [world.num_objects]world.Object;
extern var ban_map_raw: [world.ban_rows][world.ban_cols]c_uint;
extern var keyb: [256]i8;
extern var no_gore: c_int;

const player_ptr: *[world.max_players]world.Player = @constCast(&player_raw);

const obj_spring: c_int = 0;
const obj_yel_butfly: c_int = 3;
const obj_pink_butfly: c_int = 4;
const obj_anim_spring: c_int = 0;

/// levelmap.txt, packed inside data/jumpbump.dat, read once and cached:
/// read_level() (main.c:3586) loads this over the file-scope ban_map[]
/// static initializer at program start, before any headless setup runs, so
/// it -- not the static array (which core/steer_difftest.zig's/core/
/// collision_difftest.zig's own synthetic per-tick-resynchronized replays
/// use instead, since neither needs to match a real recorded corpus
/// checksum) -- is the level the corpus was actually recorded against.
var real_ban_map: ?[world.ban_rows][world.ban_cols]c_uint = null;

fn loadRealBanMap(allocator: std.mem.Allocator) ![world.ban_rows][world.ban_cols]c_uint {
    if (real_ban_map) |m| return m;
    const io = std.testing.io;
    const cwd = std.Io.Dir.cwd();
    const dat_bytes = try dat.loadDatafile(allocator, io, cwd, "../data/jumpbump.dat");
    defer allocator.free(dat_bytes);
    const level_bytes = dat.open(dat_bytes, "levelmap.txt") orelse return error.LevelmapNotFound;
    const parsed = try levelmap.parse(level_bytes, false);
    var out: [world.ban_rows][world.ban_cols]c_uint = undefined;
    for (0..world.ban_rows) |r| for (0..world.ban_cols) |c| {
        out[r][c] = parsed[r][c];
    };
    real_ban_map = out;
    return out;
}

fn setupWorld(allocator: std.mem.Allocator) !void {
    player_raw = std.mem.zeroes([world.max_players]world.Player);
    objects_raw = std.mem.zeroes([world.num_objects]world.Object);
    ban_map_raw = try loadRealBanMap(allocator);
    steer.pogostick = 0;
    steer.bunnies_in_space = 0;
    steer.jetpack = 0;
    steer.blood_is_thicker_than_water = 0;
    no_gore = 0;
    cpu_move_mod.ai = [_]c_int{0} ** world.max_players;
    game_loop.flies_enabled = 1;
    @memset(&keyb, 0);
    loadRealPlayerAnims();
    loadRealObjectAnims();
}

/// init_level()'s object seeding (main.c:2868-2937), verbatim order: an
/// OBJ_SPRING in every spring tile (16 rows, not 17 -- main.c's own loop
/// bound), then two yellow and two pink butterflies at random void tiles.
/// All draw from the one rnd() stream the trace's seed already started.
fn seedLevelObjects() void {
    for (0..16) |r| for (0..world.ban_cols) |c| {
        if (ban_map_raw[r][c] == steer.ban_spring) {
            objects_mod.add_object(obj_spring, @intCast(c * 16), @intCast(r * 16), 0, 0, obj_anim_spring, 5);
        }
    };
    const kinds = [_]c_int{ obj_yel_butfly, obj_yel_butfly, obj_pink_butfly, obj_pink_butfly };
    for (kinds) |kind| {
        while (true) {
            const s1: c_int = @intCast(rnd_mod.rnd(22));
            const s2: c_int = @intCast(rnd_mod.rnd(16));
            if (ban_map_raw[@intCast(s2)][@intCast(s1)] == steer.ban_void) {
                const vx: c_int = (s1 << 4) +% 8;
                const vy: c_int = (s2 << 4) +% 8;
                // add_object's y_add and x_add args are both `(rnd(65535) - 32768) * 2`
                // in main.c; the reference binary evaluates function arguments
                // right-to-left, so the y_add rnd() call consumes the RNG stream
                // before the x_add one does. Order matters for rnd_call_count-driven
                // determinism, so this mirrors that evaluation order exactly.
                const vb: c_int = (@as(c_int, @intCast(rnd_mod.rnd(65535))) -% 32768) *% 2;
                const va: c_int = (@as(c_int, @intCast(rnd_mod.rnd(65535))) -% 32768) *% 2;
                objects_mod.add_object(kind, vx, vy, va, vb, 0, 0);
                break;
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Corpus reading. tests/corpus/<name>.jsonl (one {"frame","keys","checksum"}
// object per line) and its <name>.meta.json sidecar (seed/headless_players/
// headless_ai_mask/extra_flags), read directly at test time -- unlike the
// per-subsystem difftests, this one needs the corpus's own checksums as the
// oracle, not just its key shapes, so there is no generated Zig transcript.
// ---------------------------------------------------------------------------

const Meta = struct {
    seed: u32,
    headless_players: usize,
    headless_ai_mask: u32,
    extra_flags: [][]const u8,
};

const Line = struct {
    frame: u32,
    keys: [][]const u8,
    checksum: []const u8,
};

const corpus_dir = "../tests/corpus/";

const traces = [_][]const u8{
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
};

fn keysToInputs(keys: []const []const u8) game_loop.Inputs {
    var inputs: game_loop.Inputs = .{};
    for (keys) |key| {
        for (0..world.max_players) |p| {
            var buf: [16]u8 = undefined;
            const left = std.fmt.bufPrint(&buf, "p{d}_left", .{p + 1}) catch unreachable;
            if (std.mem.eql(u8, key, left)) inputs.left[p] = true;
        }
        for (0..world.max_players) |p| {
            var buf: [16]u8 = undefined;
            const right = std.fmt.bufPrint(&buf, "p{d}_right", .{p + 1}) catch unreachable;
            if (std.mem.eql(u8, key, right)) inputs.right[p] = true;
        }
        for (0..world.max_players) |p| {
            var buf: [16]u8 = undefined;
            const jump = std.fmt.bufPrint(&buf, "p{d}_jump", .{p + 1}) catch unreachable;
            if (std.mem.eql(u8, key, jump)) inputs.jump[p] = true;
        }
    }
    return inputs;
}

fn checksumHex(buf: *[8]u8, hash: u32) []const u8 {
    return std.fmt.bufPrint(buf, "{x:0>8}", .{hash}) catch unreachable;
}

fn replayTrace(allocator: std.mem.Allocator, name: []const u8, mismatches: *usize, total_ticks: *usize) !void {
    const io = std.testing.io;
    const cwd = std.Io.Dir.cwd();

    var meta_path_buf: [128]u8 = undefined;
    const meta_path = try std.fmt.bufPrint(&meta_path_buf, corpus_dir ++ "{s}.meta.json", .{name});
    const meta_bytes = try cwd.readFileAlloc(io, meta_path, allocator, .limited(64 * 1024));
    defer allocator.free(meta_bytes);
    const meta_parsed = try std.json.parseFromSlice(Meta, allocator, meta_bytes, .{ .ignore_unknown_fields = true });
    defer meta_parsed.deinit();
    const meta = meta_parsed.value;

    var no_gore_flag = false;
    var flies_off = false;
    for (meta.extra_flags) |flag| {
        if (std.mem.eql(u8, flag, "-nogore")) no_gore_flag = true;
        if (std.mem.eql(u8, flag, "-noflies")) flies_off = true;
    }

    var trace_path_buf: [128]u8 = undefined;
    const trace_path = try std.fmt.bufPrint(&trace_path_buf, corpus_dir ++ "{s}.jsonl", .{name});
    const trace_bytes = try cwd.readFileAlloc(io, trace_path, allocator, .limited(1024 * 1024));
    defer allocator.free(trace_bytes);

    // --- init_level() sequence, one continuous rnd() stream from meta.seed ---
    rnd_mod.seed(meta.seed);
    try setupWorld(allocator);
    no_gore = if (no_gore_flag) 1 else 0;
    game_loop.flies_enabled = if (flies_off) 0 else 1;

    const hn = @min(meta.headless_players, world.max_players);
    for (0..hn) |i| {
        player_ptr[i].enabled = 1;
        cpu_move_mod.ai[i] = @intCast((meta.headless_ai_mask >> @intCast(i)) & 1);
    }
    for (0..hn) |i| {
        player_ptr[i].bumps = 0;
        player_ptr[i].bumped = [_]c_int{0} ** world.max_players;
        steer.position_player(@intCast(i));
    }
    seedLevelObjects();
    if (game_loop.flies_enabled != 0) flies_mod.spawn_flies();

    var state: game_loop.State = .{};
    for (0..world.num_objects) |i| state.prev_used[i] = objects_raw[i].used != 0;

    var line_it = std.mem.splitScalar(u8, trace_bytes, '\n');
    var tick: usize = 0;
    while (line_it.next()) |line| : (tick += 1) {
        if (line.len == 0) continue;
        const parsed = try std.json.parseFromSlice(Line, allocator, line, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();
        const entry = parsed.value;

        // sdl/interrpt.c's headless_load_frame_keys() zeroes all 12 known
        // player key slots -- AI-driven players included -- every tick
        // before the trace's line sets the manual ones back; that
        // unconditional reset (not just game_loop.zig's applyInputs(),
        // which skips AI players since cpu_move() owns their bits) is what
        // makes cpu_move()'s own "is my jump key still held" hysteresis
        // check see 0 every tick in headless replay, never its own
        // previous-tick write. Reproduced here so the harness matches the
        // oracle's actual headless key lifecycle, not just the general
        // interactive-mode one game_loop.zig models.
        for (cpu_move_mod.key_pl) |keys| {
            keyb[@intCast(keys[0] & 0x7f)] = 0;
            keyb[@intCast(keys[1] & 0x7f)] = 0;
            keyb[@intCast(keys[2] & 0x7f)] = 0;
        }
        const inputs = keysToInputs(entry.keys);
        _ = game_loop.step(&state, inputs);

        var w: world.World = .{ .frame_num = entry.frame, .rnd_call_count = rnd_mod.rnd_call_count };
        for (0..world.max_players) |i| w.players[i] = player_ptr[i];
        for (0..world.num_objects) |i| w.objects[i] = objects_raw[i];
        for (0..world.ban_rows) |r| for (0..world.ban_cols) |c| {
            w.ban_map[r][c] = ban_map_raw[r][c];
        };

        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try world.dumpTo(&out, allocator, &w);
        const hash = world.fnv1a32(out.items);
        var hex_buf: [8]u8 = undefined;
        const hex = checksumHex(&hex_buf, hash);

        if (!std.mem.eql(u8, hex, entry.checksum)) {
            std.debug.print("{s} frame {d}: checksum zig={s} != corpus={s}\n", .{ name, entry.frame, hex, entry.checksum });
            mismatches.* += 1;
        }
        total_ticks.* += 1;
    }
}

test "game_loop.step matches the Phase 1 corpus end-to-end, zero checksum mismatches" {
    const allocator = std.testing.allocator;
    var mismatches: usize = 0;
    var total_ticks: usize = 0;

    for (traces) |name| {
        try replayTrace(allocator, name, &mismatches, &total_ticks);
    }

    try std.testing.expect(total_ticks >= 1700);
    try std.testing.expectEqual(@as(usize, 0), mismatches);
}

// player_anims/object_anims are core/steer.zig's own exports
// (pub export var player_anims/object_anims), loaded once at program start
// (main.c:3105-3112's player_anim_data[]/main.c:96-171's object_anims
// static initializer) -- but no core module ports that literal load yet
// (it lives in main() before init_level(), out of TASK-011.07's scope), so
// this difftest transcribes both tables directly from main.c itself.
//
// NOTE: core/collision_difftest.zig's own loadObjectAnims has transcription
// errors relative to main.c (smoke's num_frames is 5, not 6; the two pink
// butterfly rows are their own distinct 32-37/38-43 image ranges, not a
// copy of yellow's 26-31; flesh_trace is nf=4 with images 76-79, not nf=8
// with 32-39) that its own tests don't happen to exercise (it never reads
// a pink butterfly's or flesh_trace's frame images), so this file
// transcribes the table fresh from main.c rather than copying that one.
fn loadRealPlayerAnims() void {
    // main.c:3105's player_anim_data[]: num_frames, restart_frame, then 4
    // (image, ticks) pairs per row, flat.
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

fn loadRealObjectAnims() void {
    // main.c:96-171's object_anims[8] static initializer, transcribed row
    // for row: spring, splash, smoke, yel_butfly_right, yel_butfly_left,
    // pink_butfly_right, pink_butfly_left, flesh_trace.
    const Row = struct { nf: c_int, rf: c_int, frames: [10][2]c_int };
    const rows = [_]Row{
        .{ .nf = 6, .rf = 0, .frames = .{ .{ 0, 3 }, .{ 1, 3 }, .{ 2, 3 }, .{ 3, 3 }, .{ 4, 3 }, .{ 5, 3 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 } } },
        .{ .nf = 9, .rf = 0, .frames = .{ .{ 6, 2 }, .{ 7, 2 }, .{ 8, 2 }, .{ 9, 2 }, .{ 10, 2 }, .{ 11, 2 }, .{ 12, 2 }, .{ 13, 2 }, .{ 14, 2 }, .{ 0, 0 } } },
        .{ .nf = 5, .rf = 0, .frames = .{ .{ 15, 3 }, .{ 16, 3 }, .{ 16, 3 }, .{ 17, 3 }, .{ 18, 3 }, .{ 19, 3 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 } } },
        .{ .nf = 10, .rf = 0, .frames = .{ .{ 20, 2 }, .{ 21, 2 }, .{ 22, 2 }, .{ 23, 2 }, .{ 24, 2 }, .{ 25, 2 }, .{ 24, 2 }, .{ 23, 2 }, .{ 22, 2 }, .{ 21, 2 } } },
        .{ .nf = 10, .rf = 0, .frames = .{ .{ 26, 2 }, .{ 27, 2 }, .{ 28, 2 }, .{ 29, 2 }, .{ 30, 2 }, .{ 31, 2 }, .{ 30, 2 }, .{ 29, 2 }, .{ 28, 2 }, .{ 27, 2 } } },
        .{ .nf = 10, .rf = 0, .frames = .{ .{ 32, 2 }, .{ 33, 2 }, .{ 34, 2 }, .{ 35, 2 }, .{ 36, 2 }, .{ 37, 2 }, .{ 36, 2 }, .{ 35, 2 }, .{ 34, 2 }, .{ 33, 2 } } },
        .{ .nf = 10, .rf = 0, .frames = .{ .{ 38, 2 }, .{ 39, 2 }, .{ 40, 2 }, .{ 41, 2 }, .{ 42, 2 }, .{ 43, 2 }, .{ 42, 2 }, .{ 41, 2 }, .{ 40, 2 }, .{ 39, 2 } } },
        .{ .nf = 4, .rf = 0, .frames = .{ .{ 76, 4 }, .{ 77, 4 }, .{ 78, 4 }, .{ 79, 4 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 } } },
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
