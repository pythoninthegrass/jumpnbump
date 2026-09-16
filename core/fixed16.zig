// 16.16 fixed-point helpers for the Zig simulation core (TASK-011.01),
// ported per docs/porting-playbook.md.
//
// Everything positional in main.c is a plain C `int` holding a 16.16
// fixed-point value (player[].x/y, x_add/y_add, x_acc/y_acc in globals.pre):
// `v >> 16` recovers a pixel coordinate, thresholds are written `(12L << 16)`,
// and the whole simulation is integer-only (the playbook's no-float rule).
//
// C evaluates all of that arithmetic with silent two's-complement wraparound
// and implementation-defined arithmetic-shift truncation; Zig traps on
// overflow in Debug/ReleaseSafe and range-checks every @intCast. Every
// helper below is therefore a wrapping (`+%`, `-*`, `*%`, `<<|`) or
// bit-preserving (`@bitCast`) expression over 32-bit ints, with the exact
// C call site it stands in for named in its comment — never a plain `+` or
// `@intCast` where the C would truncate silently.
const std = @import("std");

/// A 16.16 fixed-point quantity: position or velocity, exactly as wide as
/// the C `int` fields in player_t/object_t it mirrors.
pub const Fixed = i32;

/// `a + b` over fixed-point values — e.g. `player[].x += player[].x_add`
/// (main.c:2189), the gravity accumulation `objects[].y_add += 3072`
/// (main.c:2675), and the butterfly wobble `x_acc += rnd(128) - 64`
/// (main.c:2488).
pub fn add(a: Fixed, b: Fixed) Fixed {
    return a +% b;
}

/// `a - b` over fixed-point values — e.g. the collision pushback
/// `player[c1].x -= player[c1].x_add` (main.c:1210).
pub fn sub(a: Fixed, b: Fixed) Fixed {
    return a -% b;
}

/// Unary `-a` — e.g. `player[].y_add = -player[].y_add` (main.c:568). Only
/// INT_MIN differs from mathematical negation, wrapping to itself exactly
/// as the C does.
pub fn neg(a: Fixed) Fixed {
    return 0 -% a;
}

/// `a * m` — the particle velocity scalers `(rnd(65535) - 32768) * 3` and
/// `... * 2` (main.c:580, main.c:2919), folded back into an `int` when
/// stored to x_add/y_add by add_object().
pub fn mul(a: Fixed, m: Fixed) Fixed {
    return a *% m;
}

/// `v >> 16` — recover the integer pixel from a fixed-point position
/// (main.c:2190 and throughout). Arithmetic shift right, so negative
/// values floor toward negative infinity (pre-rounding toward -1 pixel),
/// which Zig's `>>` on signed ints already matches exactly.
pub fn shr16(v: Fixed) Fixed {
    return v >> 16;
}

/// `v >> 20` — the 16-pixel ban_map tile index,
/// `ban_map[objects[].y >> 20][objects[].x >> 20]` (main.c:2508).
pub fn shr20(v: Fixed) Fixed {
    return v >> 20;
}

/// `v >> n` for a runtime shift count — e.g. the velocity damp
/// `objects[].x_add >>= 2` (main.c:2645). The C shift count is a plain
/// `int` and out-of-range counts are UB in the abstract; this pins the
/// behavior observed from the compiled oracle, where a count of 32 or
/// more is taken modulo 32 (x86's shift instruction masks the count the
/// same way).
pub fn sar(v: Fixed, n: u31) Fixed {
    return v >> @as(u5, @truncate(n));
}

/// `-v >> 2` — the wall-bounce velocity damp,
/// `objects[].x_add = -objects[].x_add >> 2` (main.c:2501). The unary
/// minus binds tighter than `>>` in C, so this is `(-v) >> 2`: negate with
/// wraparound first, then floor-divide by 4.
pub fn bounceQuarter(v: Fixed) Fixed {
    return neg(v) >> 2;
}

/// Shift left with C's silent truncation: the bits that fall off the top
/// are discarded (Zig's `<<` on a signed int matches for in-range shifts,
/// and Zig's `<<|` is *saturating*, not wrapping, so it's never right
/// here; routing through u32 keeps the wrap explicit).
fn shlWrapping(v: i32, comptime n: u5) Fixed {
    return @bitCast(@as(u32, @bitCast(v)) << @intCast(n));
}

/// `(long) pixel << 16` — the pixel-to-fixed conversions in add_object()
/// (main.c:2416) and the player spawn in cpu_move() (main.c:2382 use the
/// `(long)` form). On the 32-bit-int targets this codebase ships on, the
/// `(long)` is a no-op and the result is truncated back into an `int`
/// field, so the whole expression is a wrapping 32-bit shift.
pub fn shl16(pixel: i32) Fixed {
    return shlWrapping(pixel, 16);
}

/// `pixel << 16` without the `(long)` cast — `player[].x = (((s1 + 16) &
/// 0xfff0)) << 16` and its siblings (main.c:2208-2312), and the object
/// equivalents at main.c:2510. Identical result to shl16(); kept distinct
/// so each ported call site names the C form it came from.
pub fn shl16Raw(pixel: i32) Fixed {
    return shlWrapping(pixel, 16);
}

/// `v << 4` — the tile-to-pixel conversions beside the fixed-point
/// comparisons, `abs((s1 << 4) - (player[].x >> 16))` (main.c:2377).
pub fn shl4(v: Fixed) Fixed {
    return shlWrapping(v, 4);
}

/// `(v + 16) & 0xfff0) << 16` — snap a pixel coordinate down to the next
/// 16-pixel boundary and back to fixed, with the addition and mask both
/// wrapping in 32 bits like the C (main.c:2208, main.c:2510).
pub fn wrapDownToTile(v: i32) Fixed {
    return shl16Raw((v +% 16) & 0xfff0);
}

/// `(((v + 16) & 0xfff0) - 16) << 16` — the same snap one tile lower
/// (main.c:2214, main.c:2307).
pub fn wrapDownToTilePrev(v: i32) Fixed {
    return shl16Raw(((v +% 16) & 0xfff0) -% 16);
}

/// `((v - 16) & 0xfff0) << 16` — snap up toward the previous tile
/// (main.c:2513).
pub fn wrapUpToTile(v: i32) Fixed {
    return shl16Raw((v -% 16) & 0xfff0);
}

/// `(((v - 16) & 0xfff0) + 15) << 16` — the up-snap that lands one pixel
/// short of the tile edge (main.c:2515). The mask applies before the +15
/// in the C, so the low bits the mask zeroed are what the +15 fills.
pub fn wrapUpToTileEdge(v: i32) Fixed {
    return shl16Raw(((v -% 16) & 0xfff0) +% 15);
}

/// `((v >> 16) & 0xfff0) << 16` — the fixed-point form of the tile snap,
/// `player[].y = ((player[].y >> 16) & 0xfff0) << 16` (main.c:2224).
pub fn snapFixedToTile(v: Fixed) Fixed {
    return shl16Raw(shr16(v) & 0xfff0);
}

test "add/sub/neg wrap like C instead of trapping" {
    try std.testing.expectEqual(@as(Fixed, -2147483648), add(2147483647, 1));
    try std.testing.expectEqual(@as(Fixed, 2147483647), sub(-2147483648, 1));
    try std.testing.expectEqual(@as(Fixed, -2147483648), neg(-2147483648));
    try std.testing.expectEqual(@as(Fixed, -123), neg(123));
}

test "mul wraps to the low 32 bits like the C int multiply" {
    // (rnd(65535) - 32768) * 3 maxes at 32767*3 = 98301; the wrap matters
    // for the adversarial inputs the difftest drives.
    try std.testing.expectEqual(@as(Fixed, 98301), mul(32767, 3));
    try std.testing.expectEqual(@as(Fixed, 2147483647), mul(2147483647, 1));
    // 2147483647 * 2 wraps to -2 (0xfffffffe), exactly the C int result.
    try std.testing.expectEqual(@as(Fixed, -2), mul(2147483647, 2));
    try std.testing.expectEqual(@as(Fixed, 0), mul(1073741824, 4));
}

test "shr16/shr20 floor toward negative infinity like C >>" {
    try std.testing.expectEqual(@as(Fixed, 10), shr16(10 << 16));
    try std.testing.expectEqual(@as(Fixed, 0), shr16(65535)); // 0.9999 px
    try std.testing.expectEqual(@as(Fixed, -1), shr16(-1)); // -0.000015 px
    try std.testing.expectEqual(@as(Fixed, -17), shr16(-(17 << 16) + 1));
    try std.testing.expectEqual(@as(Fixed, 3), shr20(3 << 20));
    try std.testing.expectEqual(@as(Fixed, -1), shr20(-(1 << 20)));
}

test "bounceQuarter is (-v) >> 2 with C precedence" {
    try std.testing.expectEqual(@as(Fixed, -32768), bounceQuarter(131072));
    try std.testing.expectEqual(@as(Fixed, -1), bounceQuarter(3)); // (-3) >> 2 floors to -1
    // neg(INT_MIN) wraps back to INT_MIN, then >> 2 is an ordinary shift.
    try std.testing.expectEqual(@as(Fixed, -536870912), bounceQuarter(-2147483648));
}

test "shifts truncate into 32 bits" {
    try std.testing.expectEqual(@as(Fixed, 65536), shl16(1));
    try std.testing.expectEqual(@as(Fixed, -65536), shl16(65535)); // 0xffff << 16 wraps low
    try std.testing.expectEqual(@as(Fixed, -65536), shl16(-1));
    try std.testing.expectEqual(@as(Fixed, 262144), shl4(16384));
}

test "tile snaps match the C expressions" {
    // ((20 + 16) & 0xfff0) = 32; each snap lands on the 16-px grid.
    try std.testing.expectEqual(@as(Fixed, 32 << 16), wrapDownToTile(20));
    try std.testing.expectEqual(@as(Fixed, 16 << 16), wrapDownToTilePrev(20));
    // ((20 - 16) & 0xfff0) = 4 & 0xfff0 = 0 -> 0; the edge variant adds
    // the +15 inside the mask's gap: (0 + 15) -> pixel 15.
    try std.testing.expectEqual(@as(Fixed, 0), wrapUpToTile(20));
    try std.testing.expectEqual(@as(Fixed, 15 << 16), wrapUpToTileEdge(20));
    try std.testing.expectEqual(@as(Fixed, 32 << 16), snapFixedToTile(33 << 16));
    // (-65536 >> 16) & 0xfff0 = 0xfff0 = 65520 (the C's unsigned-bit mask
    // on a negative pixel), << 16 truncates to -1048576 — a quirk of the
    // C's own masking on negative coordinates, reproduced, not "fixed".
    try std.testing.expectEqual(@as(Fixed, -1048576), snapFixedToTile(-1 << 16));
}
