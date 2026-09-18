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
    steer.loadDefaultAnims();
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
    objects_mod.seedLevelObjects();
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

// player_anims/object_anims are loaded via steer.loadDefaultAnims() (moved
// there from this file's own local transcription so core/abi.zig's
// jnb_world_init can share the exact same table load -- see steer.zig's
// doc comment for the full main.c provenance and the collision_difftest.zig
// transcription-error note this used to carry).
