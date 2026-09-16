// Canonical world layout + serialization (TASK-011.01), ported per
// docs/porting-playbook.md.
//
// One tick of canonical simulation state, laid out field-for-field as
// docs/checksum-format.md fixes it and as main.c's headless_emit_checksum()
// folds it (main.c:1258): frame_num, rnd_call_count, all 4 player[]
// entries in player_t declaration order, all 200 objects[] slots in
// object_t declaration order (every slot, used or not), then ban_map's
// 374 cells row-major. Serialization emits each int as 4 explicit
// little-endian bytes regardless of host byte order — the same byte
// sequence the Phase 1 checksum folds — so the difftest harness can diff
// these buffers directly.
//
// player_t/object_t are the playbook's struct-twin case: mirrored as
// plain-data extern structs here. World is the large-state case and owns
// the only copy of this layout in core/ — later TASK-011.* modules reach
// it via extern var mirrors of the arrays it contains, never by
// re-declaring it, and nothing here `@import`s another ported module.
const std = @import("std");
const levelmap = @import("levelmap.zig");

pub const max_players = 4; // JNB_MAX_PLAYERS
pub const num_objects = 200; // NUM_OBJECTS
pub const ban_rows = levelmap.rows; // 17
pub const ban_cols = levelmap.cols; // 22

/// player_t (globals.pre:207) — field names and order authoritative. The
/// fields are the C's signed `int`s; serialization bit_casts them to the
/// unsigned patterns checksum_fold_u32 consumes.
pub const Player = extern struct {
    action_left: c_int = 0,
    action_up: c_int = 0,
    action_right: c_int = 0,
    enabled: c_int = 0,
    dead_flag: c_int = 0,
    bumps: c_int = 0,
    bumped: [max_players]c_int = [_]c_int{0} ** max_players,
    x: c_int = 0,
    y: c_int = 0,
    x_add: c_int = 0,
    y_add: c_int = 0,
    direction: c_int = 0,
    jump_ready: c_int = 0,
    jump_abort: c_int = 0,
    in_water: c_int = 0,
    anim: c_int = 0,
    frame: c_int = 0,
    frame_tick: c_int = 0,
    image: c_int = 0,
};

/// object_t (globals.pre:235) — field names and order authoritative.
pub const Object = extern struct {
    used: c_int = 0,
    type: c_int = 0,
    x: c_int = 0,
    y: c_int = 0,
    x_add: c_int = 0,
    y_add: c_int = 0,
    x_acc: c_int = 0,
    y_acc: c_int = 0,
    anim: c_int = 0,
    frame: c_int = 0,
    ticks: c_int = 0,
    image: c_int = 0,
};

/// The canonical per-tick simulation state (docs/checksum-format.md). The
/// fields serialize in declaration order, which is the fixed fold order;
/// `ban_map` is [row][col] row-major like the C and folds as unsigned
/// (the C's cells are `unsigned int` in the checksum path).
pub const World = struct {
    frame_num: u32 = 0,
    rnd_call_count: u32 = 0,
    players: [max_players]Player = [_]Player{.{}} ** max_players,
    objects: [num_objects]Object = [_]Object{.{}} ** num_objects,
    ban_map: [ban_rows][ban_cols]u32 = [_][ban_cols]u32{[_]u32{0} ** ban_cols} ** ban_rows,
};

/// Bytes one World serializes to: 2 scalars + 22 ints/player + 12
/// ints/slot + 374 ban_map cells, 4 bytes each.
pub const dump_len = (2 + max_players * 22 + num_objects * 12 + ban_rows * ban_cols) * 4;

test "world struct mirrors the C layout" {
    // 22 ints per player, 12 per object slot.
    try std.testing.expectEqual(@as(usize, 88), @sizeOf(Player));
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(Object));
    // (2 + 88 + 2400 + 374) ints * 4 bytes.
    try std.testing.expectEqual(@as(usize, 11456), dump_len);
}

/// Append one int to `out` as 4 little-endian bytes — checksum_fold_u32's
/// byte order (main.c:1245), applied to the dump.
fn putU32(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: u32) !void {
    try out.appendSlice(allocator, &.{
        @truncate(value),
        @truncate(value >> 8),
        @truncate(value >> 16),
        @truncate(value >> 24),
    });
}

fn putPlayer(out: *std.ArrayList(u8), allocator: std.mem.Allocator, p: *const Player) !void {
    inline for (std.meta.fields(Player)) |field| {
        // bumped is the only non-scalar field; it folds element-wise.
        if (field.type == [max_players]c_int) {
            for (p.bumped[0..]) |v| try putU32(out, allocator, @bitCast(v));
        } else {
            try putU32(out, allocator, @bitCast(@field(p, field.name)));
        }
    }
}

fn putObject(out: *std.ArrayList(u8), allocator: std.mem.Allocator, o: *const Object) !void {
    inline for (std.meta.fields(Object)) |field| {
        try putU32(out, allocator, @bitCast(@field(o, field.name)));
    }
}

/// Append `w`'s canonical dump to `out`.
pub fn dumpTo(out: *std.ArrayList(u8), allocator: std.mem.Allocator, w: *const World) !void {
    try putU32(out, allocator, w.frame_num);
    try putU32(out, allocator, w.rnd_call_count);
    for (&w.players) |*p| try putPlayer(out, allocator, p);
    for (&w.objects) |*o| try putObject(out, allocator, o);
    for (&w.ban_map) |*row| for (row) |cell| try putU32(out, allocator, cell);
}

/// FNV-1a 32-bit over a serialized World — equivalent to what
/// headless_emit_checksum()'s per-u32 fold produces over the same bytes
/// (docs/checksum-format.md). Handy for comparing a dump against an
/// oracle CHECKSUM line without re-implementing the fold.
pub fn fnv1a32(bytes: []const u8) u32 {
    var hash: u32 = 2166136261;
    for (bytes) |byte| {
        hash ^= byte;
        hash = hash *% 16777619;
    }
    return hash;
}

test "empty world dumps all-zero bytes of the canonical length" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.testing.allocator);
    try dumpTo(&out, std.testing.allocator, &.{ .frame_num = 7, .rnd_call_count = 9 });
    const bytes = out.items;

    try std.testing.expectEqual(dump_len, bytes.len);
    // frame_num then rnd_call_count, little-endian, then nothing but zeros.
    try std.testing.expectEqualSlices(u8, &.{ 7, 0, 0, 0, 9, 0, 0, 0 }, bytes[0..8]);
    for (bytes[8..]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
}

test "negative fixed-point fields fold as their unsigned bit pattern" {
    var w: World = .{};
    w.players[0].x = -1;
    w.objects[199].y_add = -2;
    w.ban_map[16][21] = 4;

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.testing.allocator);
    try dumpTo(&out, std.testing.allocator, &w);
    const bytes = out.items;

    // 2 scalars, then player 0's action_left..bumped (10 ints), then x.
    const player_x = (2 + 10) * 4;
    try std.testing.expectEqualSlices(u8, &.{ 0xff, 0xff, 0xff, 0xff }, bytes[player_x..][0..4]);
    // last object slot's 6th field (y_add): 2 + 88 + 199*12 + 5 ints in.
    const obj_y_add = (2 + 88 + 199 * 12 + 5) * 4;
    try std.testing.expectEqualSlices(u8, &.{ 0xfe, 0xff, 0xff, 0xff }, bytes[obj_y_add..][0..4]);
    const ban_last = (2 + 88 + 2400 + 374 - 1) * 4;
    try std.testing.expectEqualSlices(u8, &.{ 4, 0, 0, 0 }, bytes[ban_last..][0..4]);
}

test "dump matches the C fold byte order" {
    // The dump is defined as the exact byte sequence checksum_fold_u32
    // consumes, so hashing it with plain FNV-1a must equal a fold over the
    // same fields in the same order.
    var w: World = .{};
    w.frame_num = 12345;
    w.rnd_call_count = 67;
    w.players[2].bumped[1] = -5;
    w.objects[3].image = 42;
    w.ban_map[0][0] = 1;

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.testing.allocator);
    try dumpTo(&out, std.testing.allocator, &w);

    // Fold the same fields the C way — 4 LE bytes per u32 through FNV-1a —
    // and the digest must equal hashing the dump directly.
    var hash: u32 = 2166136261;
    const fold = struct {
        fn f(h: *u32, value: u32) void {
            inline for ([_]u5{ 0, 8, 16, 24 }) |shift| {
                h.* ^= @as(u8, @truncate(value >> shift));
                h.* = h.* *% 16777619;
            }
        }
    }.f;
    fold(&hash, w.frame_num);
    fold(&hash, w.rnd_call_count);
    for (w.players) |p| {
        inline for (std.meta.fields(Player)) |pf| {
            if (pf.type == [max_players]c_int) {
                for (p.bumped) |v| fold(&hash, @bitCast(v));
            } else {
                fold(&hash, @bitCast(@field(&p, pf.name)));
            }
        }
    }
    for (w.objects) |o| inline for (std.meta.fields(Object)) |of|
        fold(&hash, @bitCast(@field(&o, of.name)));
    for (w.ban_map) |row| for (row) |cell| fold(&hash, cell);
    try std.testing.expectEqual(hash, fnv1a32(out.items));
}
