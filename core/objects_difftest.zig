// Tier-B differential tests for TASK-011.04: core/objects.zig's port of
// main.c's add_object()/update_objects() vs the renamed-C reference in
// core/c_ref/objects.c (extracted verbatim from main.c by
// core/c_ref/extract_objects.py), wired up in core/build.zig via
// compileRenamedCRef.
//
// Method (the playbook's Tier-B shape, the same one-tick-replay core/
// steer_difftest.zig uses): both sides mutate one shared world (objects[]/
// object_anims[]/ban_map[]) and consume one shared rnd() stream. objects.zig
// owns the storage (its externs bind steer.zig's exported objects[]/
// object_anims[]/ban_map[] at link time); the C reference binds its same-named
// externs onto the very same symbols, so there is exactly one world.
//
// Per tick: snapshot, run the C reference's c_update_objects, deep-copy its
// world + captured add_pob/add_leftovers stream, restore the snapshot, re-seed
// the PRNG, run the Zig update_objects, then compare every object slot field
// AND the two draw streams. Because both sides start each tick from the same
// world and the same PRNG state, the only source of a difference is the ported
// logic: the animation-advance rules, the butterfly/fur/flesh physics and tile
// bounce, the allocator, the octant/atan2 replacement (observable through the
// fur blob's add_pob frame index), or rnd() consumption.
//
// The draw boundary: update_objects calls add_pob once per live object (and
// add_leftovers twice for a settling flesh blob). Those are the only visible
// outputs that carry the octant math's result — a wrong octant shows up as a
// wrong `frame + octant` image argument, never as a stored-field difference.
// The C reference still calls the real add_pob/add_leftovers (unrenamed,
// verbatim from main.c), captured by the strong exports below; the Zig side
// (TASK-011.08) carries no such calls at all — it records into
// core/objects.zig's own draw_trace_z, which this harness reads directly
// after each Zig run instead of relying on a shared capture sink.
//
// Scenarios are driven directly (not corpus-replayed) because update_objects'
// inputs are the objects[] slots themselves plus the rnd() stream: the replay
// seeds each of the eight particle types into a known slot with a known
// velocity, runs many ticks, and lets the butterfly wobble / fur-blob bounce /
// flesh-settle walk the octant circle and the tile boundaries. A scripted
// allocator test fills all 200 slots to prove the first-fit scan and the
// silent-drop-on-full match.
const std = @import("std");
const rnd_mod = @import("rnd.zig");
const world = @import("world.zig");
const objects = @import("objects.zig");

extern fn c_update_objects() void;
extern fn c_add_object(type_: c_int, x: c_int, y: c_int, x_add: c_int, y_add: c_int, anim: c_int, frame: c_int) void;

// ---------------------------------------------------------------------------
// Shared world: steer.zig's exported storage (objects[]/object_anims[]/
// ban_map[]) — the same symbols objects.zig's externs resolve to. The C
// reference binds its extern declarations to these too.
// ---------------------------------------------------------------------------

// The C reference reads objects_raw[]/object_anims[]/ban_map_raw[] under
// those exact names, and so do objects.zig's own externs — one set of
// symbols, physically defined in steer.zig (TASK-011.02) but reached here
// directly, the same way steer_difftest.zig/collision_difftest.zig/
// cpu_move_difftest.zig each declare their own extern bindings to the shared
// world rather than reaching through another module's (non-pub) exports.
// object_anims[] wasn't part of that TASK-011.03 world-storage rename, so
// it's still reached through steer.zig's own (still-pub) export.
extern var objects_raw: [world.num_objects]world.Object;
extern var ban_map_raw: [world.ban_rows][world.ban_cols]u32;
const steer = @import("steer.zig");

/// The default level's ban_map (main.c:74), the grid the particles bounce on.
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

/// object_anims from main.c:103-219 (all eight rows), loaded identically to
/// core/steer_difftest.zig so a stray anim index reads the same table on both
/// sides.
fn loadObjectAnims() void {
    const Row = struct { nf: c_int, rf: c_int, frames: [10][2]c_int };
    const rows = [_]Row{
        .{ .nf = 6, .rf = 0, .frames = .{ .{ 0, 3 }, .{ 1, 3 }, .{ 2, 3 }, .{ 3, 3 }, .{ 4, 3 }, .{ 5, 3 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 } } }, // spring
        .{ .nf = 9, .rf = 0, .frames = .{ .{ 6, 2 }, .{ 7, 2 }, .{ 8, 2 }, .{ 9, 2 }, .{ 10, 2 }, .{ 11, 2 }, .{ 12, 2 }, .{ 13, 2 }, .{ 14, 2 }, .{ 0, 0 } } }, // splash
        .{ .nf = 6, .rf = 0, .frames = .{ .{ 15, 3 }, .{ 16, 3 }, .{ 16, 3 }, .{ 17, 3 }, .{ 18, 3 }, .{ 19, 3 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 } } }, // smoke
        .{ .nf = 10, .rf = 0, .frames = .{ .{ 20, 2 }, .{ 21, 2 }, .{ 22, 2 }, .{ 23, 2 }, .{ 24, 2 }, .{ 25, 2 }, .{ 24, 2 }, .{ 23, 2 }, .{ 22, 2 }, .{ 21, 2 } } }, // yel right
        .{ .nf = 10, .rf = 0, .frames = .{ .{ 26, 2 }, .{ 27, 2 }, .{ 28, 2 }, .{ 29, 2 }, .{ 30, 2 }, .{ 31, 2 }, .{ 30, 2 }, .{ 29, 2 }, .{ 28, 2 }, .{ 27, 2 } } }, // yel left
        .{ .nf = 10, .rf = 0, .frames = .{ .{ 26, 2 }, .{ 27, 2 }, .{ 28, 2 }, .{ 29, 2 }, .{ 30, 2 }, .{ 31, 2 }, .{ 30, 2 }, .{ 29, 2 }, .{ 28, 2 }, .{ 27, 2 } } }, // pink right
        .{ .nf = 10, .rf = 0, .frames = .{ .{ 26, 2 }, .{ 27, 2 }, .{ 28, 2 }, .{ 29, 2 }, .{ 30, 2 }, .{ 31, 2 }, .{ 30, 2 }, .{ 29, 2 }, .{ 28, 2 }, .{ 27, 2 } } }, // pink left
        .{ .nf = 4, .rf = 0, .frames = .{ .{ 76, 4 }, .{ 77, 4 }, .{ 78, 4 }, .{ 79, 4 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 } } }, // flesh_trace
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

// ---------------------------------------------------------------------------
// Draw-stream capture. add_pob/add_leftovers are the C reference's own
// (unrenamed) calls, extracted verbatim from main.c — the strong exports
// below are the only definitions of those two symbols in this binary, since
// the Zig side (TASK-011.08) no longer calls them at all. Zig's own draws
// are read straight from core/objects.zig's draw_trace_z after each of its
// runs (see runScenario below), not captured through a shared sink.
//
// A fur blob draws frame + octant as `image`; flesh draws frame. Recording the
// (x, y, image) triple is what makes the octant math observable.
// ---------------------------------------------------------------------------

const DrawEvent = struct { kind: c_int, a: c_int, b: c_int, image: c_int };
var draw_z: [8192]DrawEvent = undefined;
var draw_c: [8192]DrawEvent = undefined;
var n_z: usize = 0;
var n_c: usize = 0;

export fn add_pob(page: ?*anyopaque, x: c_int, y: c_int, image: c_int, gobs: ?*anyopaque) void {
    _ = .{ page, gobs };
    if (n_c < draw_c.len) draw_c[n_c] = .{ .kind = 0, .a = x, .b = y, .image = image };
    n_c += 1;
}

export fn add_leftovers(which: c_int, x: c_int, y: c_int, frame: c_int, gobs: ?*anyopaque) void {
    _ = gobs;
    if (n_c < draw_c.len) draw_c[n_c] = .{ .kind = which, .a = x, .b = y, .image = frame };
    n_c += 1;
}

/// The C reference's rnd() — same core/rnd.zig call the Zig port makes, so
/// both consume one libc stream.
export fn c_rnd_from(max: c_ushort) c_ushort {
    return rnd_mod.rnd(max);
}

// Placeholders for the two draw operands the extracted C passes to add_pob/
// add_leftovers (which the capture sinks above drop). Only &object_gobs is
// taken, so any object works; main_info is only read as main_info.draw_page.
export var object_gobs: c_int = 0;
export var main_info: extern struct { draw_page: ?*anyopaque } = .{ .draw_page = null };

// Importing steer.zig (for its world-storage exports) also pulls its
// position_player, which reads is_server; nothing in the particle replay calls
// position_player, but the symbol still has to resolve. Pinned to the headless
// server value like core/steer_difftest.zig does.
var is_server_one: c_int = 1;
var is_net_zero: c_int = 0;
comptime {
    @export(&is_server_one, .{ .name = "is_server" });
    @export(&is_net_zero, .{ .name = "is_net" });
}

// ---------------------------------------------------------------------------
// Snapshot / compare.
// ---------------------------------------------------------------------------

const Snapshot = struct {
    objects: [world.num_objects]world.Object,
    rnd_calls: c_uint,
};

fn snapshot() Snapshot {
    return .{
        .objects = objects_raw,
        .rnd_calls = rnd_mod.rnd_call_count,
    };
}

fn restore(s: *const Snapshot) void {
    objects_raw = s.objects;
    rnd_mod.rnd_call_count = s.rnd_calls;
}

fn compareObjects(name: []const u8, tick: usize, want: *const Snapshot, mismatches: *usize) void {
    for (want.objects, 0..) |wo, i| {
        inline for (std.meta.fields(world.Object)) |f| {
            const wv: c_int = @field(wo, f.name);
            const zv: c_int = @field(objects_raw[i], f.name);
            if (wv != zv) {
                if (mismatches.* < 40) std.debug.print("{s} tick {d} objects[{d}].{s}: zig={d} != c={d}\n", .{ name, tick, i, f.name, zv, wv });
                mismatches.* += 1;
            }
        }
    }
    if (want.rnd_calls != rnd_mod.rnd_call_count) {
        std.debug.print("{s} tick {d}: rnd_call_count zig={d} != c={d}\n", .{ name, tick, rnd_mod.rnd_call_count, want.rnd_calls });
        mismatches.* += 1;
    }
}

/// Compare the two captured draw streams (C run's vs the Zig run's, recorded
/// into separate buffers). A length mismatch or any differing (kind,x,y,image)
/// event is a difference in what the port would draw — including the octant
/// rotation frame.
fn compareDraws(name: []const u8, tick: usize, mismatches: *usize) void {
    if (n_c != n_z) {
        std.debug.print("{s} tick {d}: draw count zig={d} != c={d}\n", .{ name, tick, n_z, n_c });
        mismatches.* += 1;
        return;
    }
    var i: usize = 0;
    while (i < n_c) : (i += 1) {
        const c = draw_c[i];
        const z = draw_z[i];
        if (c.kind != z.kind or c.a != z.a or c.b != z.b or c.image != z.image) {
            if (mismatches.* < 40) std.debug.print("{s} tick {d} draw[{d}]: zig=(k{d},x{d},y{d},im{d}) != c=(k{d},x{d},y{d},im{d})\n", .{ name, tick, i, z.kind, z.a, z.b, z.image, c.kind, c.a, c.b, c.image });
            mismatches.* += 1;
        }
    }
}

// ---------------------------------------------------------------------------
// Scenario replay. Each scenario places particles via the C add_object
// (c_add_object, so the seed uses the oracle's allocator), then runs N ticks:
// snapshot, run C, capture world+draws, restore, run Zig, compare.
// ---------------------------------------------------------------------------

fn setupWorld() void {
    objects_raw = std.mem.zeroes([world.num_objects]world.Object);
    ban_map_raw = default_ban_map;
    loadObjectAnims();
}

/// Seed one object slot directly (bypassing the allocator) with the given
/// type/anim/frame and fixed-point velocity, at tile-pixel (px, py). The
/// ticks/image lookup mirrors add_object's *unchecked* table read: flesh blobs
/// are legitimately seeded with anim 0 and frame 76-79 (main.c:582-588), which
/// reads object_anims[0].frame[76] — past the 10-frame row, into the next rows'
/// memory, exactly as the oracle does. The pointer cast (not a Zig array index)
/// keeps that read unchecked so it matches objects.zig's add_object instead of
/// trapping on the out-of-range frame index.
fn seedObject(slot: usize, type_: c_int, px: c_int, py: c_int, x_add: c_int, y_add: c_int, anim: c_int, frame: c_int) void {
    const o = &objects_raw[slot];
    o.* = .{};
    o.used = 1;
    o.type = type_;
    o.x = @bitCast(@as(u32, @bitCast(px)) << 16);
    o.y = @bitCast(@as(u32, @bitCast(py)) << 16);
    o.x_add = x_add;
    o.y_add = y_add;
    o.anim = anim;
    o.frame = frame;
    const rows = @as([*]const steer.ObjectAnim, @ptrCast(&steer.object_anims));
    const fr = @as([*]const steer.AnimFrame, @ptrCast(&rows[@as(u32, @bitCast(anim))].frame));
    // Raw pointer index (unchecked): the C reads object_anims[anim].frame[frame]
    // with frame up to 79, well past the 10-frame row, matching the oracle's
    // unchecked memory read. Sign-extend the int index the way pointer
    // arithmetic does, then reinterpret as the (unsigned) index Zig wants.
    const fi: u64 = @bitCast(@as(i64, frame));
    o.ticks = fr[fi].ticks;
    o.image = fr[fi].image;
}

const Scenario = struct {
    name: []const u8,
    seed: c_uint,
    ticks: usize,
    place: *const fn () void,
};

fn runScenario(scn: *const Scenario, mismatches: *usize) void {
    setupWorld();
    scn.place();
    for (0..scn.ticks) |tick| {
        const start = snapshot();
        const tick_seed = scn.seed +% @as(c_uint, @intCast(tick)) *% 7919;

        // --- C side ---
        rnd_mod.seed(tick_seed);
        n_c = 0;
        c_update_objects();
        const c_result = snapshot();

        // --- Zig side: same seed, same starting world ---
        restore(&start);
        rnd_mod.seed(tick_seed);
        objects.drawResetZ();
        update_objects_entry();
        n_z = 0;
        for (0..objects.drawCountZ()) |i| {
            const d = objects.draw_trace_z[i];
            if (n_z < draw_z.len) draw_z[n_z] = .{ .kind = d.kind, .a = d.a, .b = d.b, .image = d.image };
            n_z += 1;
        }
        compareObjects(scn.name, tick, &c_result, mismatches);
        compareDraws(scn.name, tick, mismatches);
    }
}

/// The Zig update_objects entry. objects.zig exports it under the C name; call
//  through that export so the differential exercises the same linkage the game
//  loop will use.
fn update_objects_entry() void {
    objects.update_objects();
}

// --- Scenario placement functions -----------------------------------------

fn placeSprings() void {
    var i: usize = 0;
    for (0..16) |r| for (0..22) |col| {
        if (default_ban_map[r][col] == 4) { // BAN_SPRING
            seedObject(@mod(i + 1, 200), 0, @intCast(col * 16), @intCast(r * 16), 0, 0, 0, 5);
            i += 1;
        }
    };
}

fn placeSplashSmoke() void {
    seedObject(1, 1, 100, 100, 0, 0, 1, 0); // splash
    seedObject(2, 2, 120, 90, 32768, -32768, 2, 0); // smoke moving up-right
    seedObject(3, 2, 200, 80, -40000, 16384, 2, 3); // smoke moving down-left
}

fn placeButterflies() void {
    // Two yellow + two pink, launched in each diagonal so the wobble walks the
    // direction switch (left/right anim) and both wall bounces.
    seedObject(1, 3, 100, 100, 30000, 30000, 3, 0); // yel right
    seedObject(2, 3, 300, 120, -30000, -20000, 4, 0); // yel left
    seedObject(3, 4, 150, 200, 20000, -30000, 5, 0); // pink right
    seedObject(4, 4, 320, 60, -28000, 28000, 6, 0); // pink left
}

fn placeFurBlobs() void {
    // Fur launched across the eight compass directions so octant() is exercised
    // over every quadrant and diagonal over successive ticks (its velocity
    // wobbles and bounces off tiles, sweeping the circle).
    seedObject(1, 5, 180, 120, 60000, 0, 0, 0); // -> +x
    seedObject(2, 5, 180, 120, -60000, 0, 0, 0); // -> -x
    seedObject(3, 5, 180, 120, 0, 60000, 0, 0); // -> +y
    seedObject(4, 5, 180, 120, 0, -60000, 0, 0); // -> -y
    seedObject(5, 5, 180, 120, 50000, 50000, 0, 0); // -> +x+y
    seedObject(6, 5, 180, 120, -50000, 50000, 0, 0); // -> -x+y
    seedObject(7, 5, 180, 120, 50000, -50000, 0, 0); // -> +x-y
    seedObject(8, 5, 180, 120, -50000, -50000, 0, 0); // -> -x-y
}

fn placeFleshBlobs() void {
    seedObject(1, 6, 180, 60, 40000, 0, 0, 76); // flesh, frame 76 -> flesh_trace spawn path
    seedObject(2, 6, 200, 40, -40000, 0, 0, 77);
    seedObject(3, 6, 220, 30, 0, 0, 0, 78);
    seedObject(4, 6, 160, 200, 30000, 20000, 0, 0); // falls onto solid, settles
}

fn placeFleshTrace() void {
    seedObject(1, 7, 100, 100, 0, 0, 7, 0);
    seedObject(2, 7, 110, 100, 0, 0, 7, 1);
    seedObject(3, 7, 120, 100, 0, 0, 7, 2);
    seedObject(4, 7, 130, 100, 0, 0, 7, 3);
}

/// Allocator stress: fill all 200 slots one at a time through c_add_object,
/// then attempt an overflow add. Both sides run update_objects afterward, so a
/// divergence in the first-fit scan or the silent-drop-on-full would show.
fn placeAllocatorStress() void {
    var i: usize = 0;
    while (i < 200) : (i += 1) {
        c_add_object(2, 10, 10, 16384, 16384, 2, 0); // smoke, so it animates & frees
    }
    // 201st add must be a silent no-op on both sides (loop falls through).
    c_add_object(2, 10, 10, 16384, 16384, 2, 0);
}

const scenarios = [_]Scenario{
    .{ .name = "springs", .seed = 0xC0FFEE, .ticks = 40, .place = &placeSprings },
    .{ .name = "splash_smoke", .seed = 0xBEEF01, .ticks = 40, .place = &placeSplashSmoke },
    .{ .name = "butterflies", .seed = 0x1234AB, .ticks = 600, .place = &placeButterflies },
    .{ .name = "fur_blobs", .seed = 0x5A5A5A, .ticks = 600, .place = &placeFurBlobs },
    .{ .name = "flesh_blobs", .seed = 0x0F0F0F, .ticks = 400, .place = &placeFleshBlobs },
    .{ .name = "flesh_trace", .seed = 0x77AA00, .ticks = 40, .place = &placeFleshTrace },
    .{ .name = "allocator_stress", .seed = 0x0102, .ticks = 80, .place = &placeAllocatorStress },
};

test "objects.zig matches the extracted C reference across the particle scenarios" {
    var mismatches: usize = 0;
    var total_ticks: usize = 0;
    for (&scenarios) |*scn| {
        runScenario(scn, &mismatches);
        total_ticks += scn.ticks;
    }
    if (total_ticks < 1500) {
        std.debug.print("objects difftest replayed only {d} ticks\n", .{total_ticks});
        mismatches += 1;
    }
    try std.testing.expectEqual(@as(usize, 0), mismatches);
}
