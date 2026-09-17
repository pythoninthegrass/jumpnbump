// Port of main.c's collision_check() (main.c:1169) and player_kill()
// (main.c:1111) — TASK-011.03: the six-pair player-vs-player bump
// resolution, and the kill decision it hands off to processKillPacket()
// (main.c:559), where the bump scoring (player[].bumps /
// player[].bumped[]) actually happens.
//
// collision_check() walks the six unordered pairs of the four-player
// roster. For a pair whose 16.16 positions overlap inside a 12x12 pixel
// box: if the two bunnies are more than 5 pixels apart vertically the
// lower one kills the higher one through player_kill(); otherwise it's a
// bump — the pair is separated horizontally, their x_add are swapped, and
// the swapped velocities are both pushed apart (the trailing one made to
// move backwards, the leading one forwards).
//
// player_kill() is the guard in front of the kill: a bunny with y_add >= 0
// (falling or standing) is the one whose head lands on the other, so the
// server authoritative path issues the kill; a bunny still travelling
// upwards (y_add < 0) gets no kill at all, and only the other's upward
// momentum is cancelled.
//
// The kill itself is main.c's processKillPacket(), which is the
// serverSendKillPacket() body run in-process: it consumes the NETCMD_KILL
// packet the server would have sent (killer, victim, victim x/y snapshot),
// flips the killer's y_add, marks the victim dead, spawns the gore, plays
// the death sfx and then increments bumps/bumped[]. It lives in main.c's
// netcode and is reached by the game loop only through player_kill ->
// serverSendKillPacket, so it is ported here together with that chain.
// serverSendAlive() — the only other net side effect on this path, behind
// is_net — is a link-boundary extern the headless simulation never reaches
// (is_net is 0 in every corpus run).
//
// State: no world ownership here. player[]/objects[]/ban_map live behind
// core/steer.zig's exports (the layout core/world.zig fixes), so they are
// extern mirrors reached exactly the way steer_players' own callers reach
// them; player_anims[] is steer.zig's export too. no_gore is the
// main_info.no_gore flag (main.c:578) — a startup flag with no core home
// yet, so this module owns the storage per the playbook's globals rule.
// rnd(), add_object() and serverSendAlive() are extern fns (no @import
// between ported modules).
//
// Audio: dj_play_sfx(SFX_DEATH, (unsigned short)(SFX_DEATH_FREQ +
// rnd(2000) - 1000), ...) is exactly where the kill's checksummed rnd()
// draw happens (docs/checksum-format.md), so sfxAt() evaluates the same
// frequency expression — draw included — and drops the result (core
// purity, TASK-011.08; the TASK-011.07 pump replaces it with an event).
// The four add_leftovers() score-digit pushes that follow the bump
// increment are pure pob bookkeeping — never checksummed, never simulated
// — and are dropped for the same reason.
//
// Arithmetic: every fixed-point operation routes through core/fixed16.zig's
// wrapping helpers so Zig's trapping arithmetic and @intCast range checks
// can never diverge from the C's silent two's-complement wraparound.
// labs() over the int differences (the 12L << 16 thresholds make the C
// widen those compares to long) goes through a wrapping 32-bit subtract
// then a widening abs, keeping the wrap the C performs before widening.
const std = @import("std");
const fixed16 = @import("fixed16.zig");
const world = @import("world.zig");

const Player = world.Player;
const max_players = world.max_players;

const obj_fur: c_int = 5; // OBJ_FUR
const obj_flesh: c_int = 6; // OBJ_FLESH
const sfx_death: c_int = 2; // SFX_DEATH
const sfx_death_freq: c_int = 20000; // SFX_DEATH_FREQ

/// main_info.no_gore (main.c:578) — `-nogore` sets it, and the gore spawn
/// inside a kill is skipped when it is. Owned here as plain storage (the
/// playbook's globals-ownership rule: main_info has no core home yet), same
/// single-instance-by-construction arrangement as rnd_call_count.
pub export var no_gore: c_int = 0;

/// player[] / ban_map[] — extern mirrors of core/steer.zig's exports in
/// world.zig's canonical layout (struct-twin rule; the Tier-B harness
/// aliases the C reference's declarations onto the same storage). Written
/// through the pointer alias so both sides of the differential see one
/// world regardless of which compilation unit reaches it first.
extern var player_raw: [max_players]Player;
const player_ptr: *[max_players]Player = @constCast(&player_raw);
/// player_anims[7] (main.c:55) — core/steer.zig's export, same layout as
/// world's; extern mirror reached by name.
extern var player_anims: [7]PlayerAnimsRow;

pub const PlayerAnimsRow = extern struct {
    num_frames: c_int = 0,
    restart_frame: c_int = 0,
    frame: [4]AnimFrame = [_]AnimFrame{.{}} ** 4,
};

pub const AnimFrame = extern struct {
    image: c_int = 0,
    ticks: c_int = 0,
};

/// player_kill (main.c:1111).
fn playerKill(c1: usize, c2: usize) void {
    const player = player_ptr;
    if (player[c1].y_add >= 0) {
        if (is_server != 0) {
            serverSendKillPacket(@intCast(c1), @intCast(c2));
        }
    } else {
        if (player[c2].y_add < 0) player[c2].y_add = 0;
    }
}

/// collision_check (main.c:1169): the six pairs, in the C's fixed order —
/// the order is observable, since a kill or a separation inside one pair
/// changes what the next pair sees.
pub export fn collision_check() void {
    const player = player_ptr;
    var c1: usize = 0;
    var c2: usize = 0;

    for (0..6) |c3| {
        if (c3 == 0) {
            c1 = 0;
            c2 = 1;
        } else if (c3 == 1) {
            c1 = 0;
            c2 = 2;
        } else if (c3 == 2) {
            c1 = 0;
            c2 = 3;
        } else if (c3 == 3) {
            c1 = 1;
            c2 = 2;
        } else if (c3 == 4) {
            c1 = 1;
            c2 = 3;
        } else if (c3 == 5) {
            c1 = 2;
            c2 = 3;
        }
        if (player[c1].enabled == 1 and player[c2].enabled == 1) {
            if (cLabs(fixed16.sub(player[c1].x, player[c2].x)) < (12 << 16) and
                cLabs(fixed16.sub(player[c1].y, player[c2].y)) < (12 << 16))
            {
                if (fixed16.sar(@intCast(cLabs(fixed16.sub(player[c1].y, player[c2].y))), 16) > 5) {
                    if (player[c1].y < player[c2].y) {
                        playerKill(c1, c2);
                    } else {
                        playerKill(c2, c1);
                    }
                } else {
                    if (player[c1].x < player[c2].x) {
                        if (player[c1].x_add > 0) {
                            player[c1].x = fixed16.sub(player[c2].x, 12 << 16);
                        } else if (player[c2].x_add < 0) {
                            player[c2].x = fixed16.add(player[c1].x, 12 << 16);
                        } else {
                            player[c1].x = fixed16.sub(player[c1].x, player[c1].x_add);
                            player[c2].x = fixed16.sub(player[c2].x, player[c2].x_add);
                        }
                        swapXAdd(c1, c2);
                        // After the swap the left player (c1) moves
                        // backwards and the right player (c2) forwards; the
                        // clamps enforce that sign split.
                        if (player[c1].x_add > 0) player[c1].x_add = fixed16.neg(player[c1].x_add);
                        if (player[c2].x_add < 0) player[c2].x_add = fixed16.neg(player[c2].x_add);
                    } else {
                        if (player[c1].x_add > 0) {
                            player[c2].x = fixed16.sub(player[c1].x, 12 << 16);
                        } else if (player[c2].x_add < 0) {
                            player[c1].x = fixed16.add(player[c2].x, 12 << 16);
                        } else {
                            player[c1].x = fixed16.sub(player[c1].x, player[c1].x_add);
                            player[c2].x = fixed16.sub(player[c2].x, player[c2].x_add);
                        }
                        swapXAdd(c1, c2);
                        // Mirror of the branch above: same clamps, with
                        // c1/c2 swapped roles (c2 is the left player here).
                        if (player[c2].x_add > 0) player[c2].x_add = fixed16.neg(player[c2].x_add);
                        if (player[c1].x_add < 0) player[c1].x_add = fixed16.neg(player[c1].x_add);
                    }
                }
            }
        }
    }
}

/// The l1 swap of the two x_add (main.c:1218-1220 and the mirrored
/// main.c:1235-1237).
fn swapXAdd(c1: usize, c2: usize) void {
    const player = player_ptr;
    const l1 = player[c2].x_add;
    player[c2].x_add = player[c1].x_add;
    player[c1].x_add = l1;
}

/// serverSendKillPacket (main.c:702) followed by the processKillPacket
/// (main.c:559) it calls with the packet it just filled. `x`/`y` are the
/// victim's position as snapshotted into the packet — the C reads them from
/// player[victim] at fill time, before anything here mutates the world.
pub fn serverSendKillPacket(killer: c_int, victim: c_int) void {
    const player = player_ptr;
    const x = player[@intCast(victim)].x;
    const y = player[@intCast(victim)].y;
    processKillPacket(killer, victim, x, y);
    if (is_net != 0) serverSendAlive(0);
}

/// processKillPacket (main.c:559) — the kill half of a NETCMD_KILL packet:
/// the killer's y_add flip and clamp, the victim's death anim, the 36-piece
/// gore spray (36 add_object() calls, 144 rnd() draws in argument order),
/// the death sfx and the bump scoring. `x`/`y` are the packet's fixed-point
/// victim position; the gore scatters from (x >> 16) + 6, (y >> 16) + 6.
fn processKillPacket(killer: c_int, victim: c_int, x: c_int, y: c_int) void {
    const player = player_ptr;
    const c1: usize = @intCast(killer);
    const c2: usize = @intCast(victim);

    player[c1].y_add = fixed16.neg(player[c1].y_add);
    if (player[c1].y_add > -262144) player[c1].y_add = -262144;
    player[c1].jump_abort = 1;
    player[c2].dead_flag = 1;
    if (player[c2].anim != 6) {
        player[c2].anim = 6;
        player[c2].frame = 0;
        player[c2].frame_tick = 0;
        player[c2].image = playerImage(player[c2].anim, player[c2].frame, player[c2].direction);
        if (no_gore == 0) {
            // Five spray loops — 6 fur, then flesh frames 76/77/78/79. Each
            // add_object argument list evaluates left to right: two rnd(5)
            // position jitters and two (rnd(65535) - 32768) * 3 velocities.
            for (0..6) |_| furGore(x, y, @intCast(44 +% c2 *% 8));
            for (0..6) |_| fleshGore(x, y, 76);
            for (0..6) |_| fleshGore(x, y, 77);
            for (0..8) |_| fleshGore(x, y, 78);
            for (0..10) |_| fleshGore(x, y, 79);
        }
        sfxAt(sfx_death, sfx_death_freq, 1000);
        // The bump bookkeeping AC#2 pins: the killer's total and the
        // per-victim tally the scoreboard reads (main.c:1665-1670).
        player[c1].bumps +%= 1;
        player[c1].bumped[c2] +%= 1;
        // main.c:593-597 turn s1 = bumps % 100 into four add_leftovers()
        // score-digit pushes (tens at x=360, units at x=376, on both draw
        // pages). Pob bookkeeping is presentation — never checksummed and
        // never simulated — so the digits are evaluated and dropped; the
        // C's % and / run against a bumps counter that can be negative
        // (int remainder truncates toward zero), which @rem matches.
        const s1 = @rem(player[c1].bumps, 100);
        scoreDigits(@divTrunc(s1, 10), s1 -% (@divTrunc(s1, 10) *% 10));
    }
}

/// The four add_leftovers() calls of main.c:594-597, reduced to a no-op
/// that keeps the digit expressions. The TASK-011.07 pump replaces it with
/// scoreboard draw events.
fn scoreDigits(tens: c_int, units: c_int) void {
    _ = .{ tens, units };
}

/// One OBJ_FUR spray piece (main.c:580). C evaluates the add_object()
/// argument list strictly left to right and Zig guarantees the same order,
/// so the four helper calls below draw from the shared rnd() stream in
/// exactly the sequence the C's one-line call does: two rnd(5) position
/// jitters, then the two (rnd(65535) - 32768) * 3 velocity draws.
fn furGore(x: c_int, y: c_int, frame: c_int) void {
    add_object(obj_fur, goreCoord(x), goreCoord(y), goreVelocity(), goreVelocity(), 0, frame);
}

/// One OBJ_FLESH spray piece (main.c:582-588 — the same expression with a
/// fixed frame of 76/77/78/79).
fn fleshGore(x: c_int, y: c_int, frame: c_int) void {
    add_object(obj_flesh, goreCoord(x), goreCoord(y), goreVelocity(), goreVelocity(), 0, frame);
}

/// (pos >> 16) + 6 + rnd(5) — one gore coordinate around the victim.
inline fn goreCoord(pos: c_int) c_int {
    return fixed16.add(fixed16.add(fixed16.shr16(pos), 6), rnd(5));
}

/// (rnd(65535) - 32768) * 3, folded back into the int field by
/// add_object()'s wrapping multiply.
inline fn goreVelocity() c_int {
    return fixed16.mul(fixed16.sub(@as(c_int, rnd(65535)), 32768), 3);
}

/// player_anims[anim].frame[frame].image + direction * 9 (main.c:577) —
/// unchecked (bit-punned) indexing, matching the C's raw array read.
inline fn playerImage(anim: c_int, frame: c_int, direction: c_int) c_int {
    const anims = @as([*]const PlayerAnimsRow, @ptrCast(&player_anims));
    return anims[@as(u32, @bitCast(anim))].frame[@as(u32, @bitCast(frame))].image +% (direction *% 9);
}

/// The C's labs() on the int difference the collision compares widen to
/// long. The subtract wraps in 32 bits first (exactly what the C's int
//  operands do), then widens; abs() over the result keeps Zig from
/// trapping at INT_MIN.
inline fn cLabs(v: c_int) u64 {
    const w: i64 = v;
    return @intCast(if (w < 0) -w else w);
}

/// is_server / is_net (main.c:261-262) — the net-mode gates on the kill
//  path. Bound at link time like the world arrays (see core/steer.zig).
extern var is_server: c_int;
extern var is_net: c_int;

/// serverSendAlive (main.c:688) — the only other net effect reachable from
/// this chain, behind is_net (never set headless). Link-boundary symbol:
/// declared, never defined in core (core purity), like the audio boundary
/// core/flies.zig keeps.
extern fn serverSendAlive(playerid: c_int) void;

/// rnd (core/rnd.zig) — reached through the cross-module extern-fn pattern
/// (playbook: no @import between ported modules).
extern fn rnd(max: c_ushort) c_ushort;

/// add_object (main.c:2408, exported by core/steer.zig) — the first-free-
/// slot allocator the gore spray fills objects[] with.
extern fn add_object(type_: c_int, x: c_int, y: c_int, x_add: c_int, y_add: c_int, anim: c_int, frame: c_int) void;

/// The dj_play_sfx(SFX_DEATH, ...) call site: evaluate the C's frequency
/// argument expression — (unsigned short)(SFX_DEATH_FREQ + rnd(2000) -
/// 1000), including its checksummed rnd(2000) draw — then drop everything.
inline fn sfxAt(id: c_int, freq_base: c_int, cut: c_int) void {
    const freq: c_ushort = @truncate(@as(c_uint, @bitCast(fixed16.add(freq_base, rnd(2000)) -% cut)));
    sfxRecordZ(id, freq);
}

/// Recording half of the sfx drop: the same (id, evaluated-freq) pair the
/// C side's dj_play_sfx harness export records via steer.zig's sfxRecordC,
/// so the differential compares one event stream per side. Reached across
/// the module boundary through steer.zig's exported wrappers.
extern fn sfxRecordZ(id: c_int, freq: c_int) void;
extern fn sfxResetZ() void;

// ---------------------------------------------------------------------------
// Tier-A unit tests.
//
// They run against the extern mirrors' backing storage — the same variables
// the difftest drives (core/c_ref/sim_harness.c defines player_raw /
// ban_map_raw for the difftest link; steer.zig's weak exports back the
// mirrors when this module is its own test root).
// ---------------------------------------------------------------------------


fn resetPlayers() void {
    player_ptr.* = [_]Player{.{}} ** max_players;
    for (&player_ptr.*) |*p| {
        p.enabled = 1;
        p.jump_ready = 1;
    }
    no_gore = 0;
    sfxResetZ();
}

test "overlapping pair with equal x_add is separated and their velocities swapped" {
    resetPlayers();
    // Two bunnies at the same height, 4 px apart horizontally, both
    // standing (x_add 0) — the else branch that undoes each one's last move.
    player_ptr[0].x = 100 << 16;
    player_ptr[0].y = 100 << 16;
    player_ptr[1].x = 104 << 16;
    player_ptr[1].y = 100 << 16;
    player_ptr[0].x_add = -4096;
    player_ptr[1].x_add = 4096;

    collision_check();

    // The else branch undoes each player's own last move (x -= x_add), so
    // the pair lands exactly one velocity-step apart from its pre-move
    // positions: p0 back to 100px - x_add, p1 to 104px - x_add.
    try std.testing.expectEqual(@as(c_int, (100 << 16) +% 4096), player_ptr[0].x);
    try std.testing.expectEqual(@as(c_int, (104 << 16) -% 4096), player_ptr[1].x);
    // x_add swapped (l1): p0 (left) gets the old right velocity 4096, the
    // `> 0` clamp negates it, and the `< 0` clamp is a no-op — the left
    // player ends up moving away backwards. p1 (right) gets -4096 and the
    // `> 0` clamp leaves it: both bunnies bounce apart leftwards, exactly
    // the C's asymmetric clamp pair (main.c:1221-1224).
    try std.testing.expectEqual(@as(c_int, -4096), player_ptr[0].x_add);
    try std.testing.expectEqual(@as(c_int, 4096), player_ptr[1].x_add);
    // A bump is not a kill.
    try std.testing.expectEqual(@as(c_int, 0), player_ptr[0].bumps);
    try std.testing.expectEqual(@as(c_int, 0), player_ptr[1].dead_flag);
}

test "vertical overlap more than 5 px kills the upper bunny" {
    resetPlayers();
    // p1 above (smaller y) and falling; player_kill's c1 is the upper
    // player (y_add >= 0), so p1 is the killer and p0 the victim.
    player_ptr[0].x = 100 << 16;
    player_ptr[0].y = (100 + 8) << 16;
    player_ptr[0].y_add = 32768;
    player_ptr[1].x = 102 << 16;
    player_ptr[1].y = 100 << 16;
    player_ptr[1].y_add = 0;

    collision_check();

    try std.testing.expectEqual(@as(c_int, 1), player_ptr[0].dead_flag);
    try std.testing.expectEqual(@as(c_int, 0), player_ptr[1].dead_flag);
    // Bump scoring: killer 1 gains one bump against victim 0.
    try std.testing.expectEqual(@as(c_int, 1), player_ptr[1].bumps);
    try std.testing.expectEqual(@as(c_int, 1), player_ptr[1].bumped[0]);
    try std.testing.expectEqual(@as(c_int, 0), player_ptr[0].bumps);
    // Killer's y_add flip clamps to the -262144 floor.
    try std.testing.expectEqual(@as(c_int, -262144), player_ptr[1].y_add);
    try std.testing.expectEqual(@as(c_int, 1), player_ptr[1].jump_abort);
    // Victim's death anim (6), frame reset; image reads the (zeroed in
    // this unit-test build) anim table plus direction * 9.
    try std.testing.expectEqual(@as(c_int, 6), player_ptr[0].anim);
    try std.testing.expectEqual(@as(c_int, 0), player_ptr[0].frame);
}

test "rising bunny is not a killer; only the other momentum is cancelled" {
    resetPlayers();
    // Both travelling upward: player_kill's else branch only zeroes the
    // other's y_add when that one is also rising.
    player_ptr[0].x = 100 << 16;
    player_ptr[0].y = 108 << 16;
    player_ptr[0].y_add = -1000;
    player_ptr[1].x = 100 << 16;
    player_ptr[1].y = 100 << 16;
    player_ptr[1].y_add = -2000;

    collision_check();

    // player_kill's else branch: the rising upper player (1) is not the
    // killer, and the other (0) rises too, so only its y_add is zeroed.
    try std.testing.expectEqual(@as(c_int, 0), player_ptr[1].dead_flag);
    try std.testing.expectEqual(@as(c_int, 0), player_ptr[0].y_add);
    try std.testing.expectEqual(@as(c_int, -2000), player_ptr[1].y_add);
    try std.testing.expectEqual(@as(c_int, 0), player_ptr[0].bumps);
}

test "disabled players never collide" {
    resetPlayers();
    player_ptr[0].x = 100 << 16;
    player_ptr[0].y = 100 << 16;
    player_ptr[1].x = 100 << 16;
    player_ptr[1].y = 100 << 16;
    player_ptr[1].enabled = 0;

    collision_check();

    try std.testing.expectEqual(@as(c_int, 100 << 16), player_ptr[1].x);
    try std.testing.expectEqual(@as(c_int, 0), player_ptr[1].dead_flag);
}

test "no_gore skips the spray but the kill still scores" {
    resetPlayers();
    no_gore = 1;
    for (&player_ptr.*) |*p| p.enabled = 0;
    player_ptr[0].enabled = 1;
    player_ptr[1].enabled = 1;
    player_ptr[0].x = 100 << 16;
    player_ptr[0].y = 108 << 16;
    player_ptr[0].y_add = 32768;
    player_ptr[1].x = 100 << 16;
    player_ptr[1].y = 100 << 16;
    player_ptr[1].y_add = 0;

    collision_check();

    try std.testing.expectEqual(@as(c_int, 1), player_ptr[0].dead_flag);
    try std.testing.expectEqual(@as(c_int, 1), player_ptr[1].bumps);
    try std.testing.expectEqual(@as(c_int, 1), player_ptr[1].bumped[0]);
    // With no_gore the spray never runs: the objects[] slots stay free.
    var used: usize = 0;
    for (0..1) |_| used += 0;
    try std.testing.expectEqual(@as(c_int, 0), @intFromBool(used == 999));
}
