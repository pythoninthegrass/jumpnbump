// Port of main.c's cpu_move() (main.c:1866) and map_tile() (main.c:1852) —
// TASK-011.05, the bot pathing logic that reads ban_map to steer
// AI-controlled players.
//
// Per tick, for every AI-controlled enabled player, cpu_move() picks the
// nearest other enabled player by squared fixed-point distance, decides
// left/right/jump flags (lm/rm/jm) from target geometry plus the tiles
// under and around the bunny, then presses or releases that player's own
// three keys through addkey()/keyb[] — the same keyboard state
// steer_players() reads for human players. All decisions are integer
// (16.16 positions shifted to pixels, plain int tile constants); no rnd()
// call and no float anywhere in the subsystem.
//
// Globals follow the playbook's ownership rule: `ai` (the per-player CPU
// flag) has no home in core/ yet, so this module declares the extern
// mirror and owns the backing storage. `player[]` and `ban_map[]` are the
// two pieces of larger state the porting plan gives to other TASK-011.*
// modules (world layout fixed by world.zig, physics by TASK-011.02), so
// they stay extern-only here — the difftest harness (cpu_move_difftest.zig)
// provides the missing definitions, and the module that claims them later
// becomes the single definition without touching this file. The keyboard
// state cpu_move drives (keyb[] plus the headless addkey()/key_pressed()
// from sdl/interrpt.c) is also owned by the harness; this module reaches
// it through extern declarations only.
const std = @import("std");
const fixed16 = @import("fixed16.zig");

pub const max_players = 4; // JNB_MAX_PLAYERS

/// player_t (globals.pre:207) — struct-twin mirror of the fields cpu_move
/// reads: presence (enabled), position (x/y), and the bump bookkeeping it
/// shares with collision code. Layout matches world.zig's Player.
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

/// ban_map (main.c:74) — [row][col] unsigned tile grid. extern-only: the
/// module that owns level state defines the array.
pub extern var ban_map_raw: [17][22]c_uint;

/// ai[] (main.c:68) — per-player CPU flag, set from the headless AI mask
/// (or the menu, once that path is ported). Declared extern per
/// globals.pre:92; this module owns the storage until a later port claims
/// it, mirroring how rnd.zig owns rnd_call_count.
pub export var ai: [max_players]c_int = [_]c_int{0} ** max_players;

/// player_raw[] (main.c:54) — extern-only; see the file header.
pub extern var player_raw: [max_players]Player;

/// keyb[] (sdl/interrpt.c:42) — the keyboard state cpu_move writes via
/// addkey() and reads via key_pressed(). extern-only; the harness (or,
/// later, a ported input module) defines it.
pub extern var keyb: [256]i8;

/// Tile constants (globals.pre:159).
pub const ban_void = 0;
pub const ban_water = 2;

/// Key codes for the four bunnies (globals.pre:102, SDL SDLK_* values).
/// The C's `key &= 0x7f` before addkey() maps each through the
/// (unsigned char) index keyb[] is read with, so these low-7-bit
/// identities are what the port has to reproduce exactly.
pub const key_pl = [max_players][3]c_int{
    .{ 276, 275, 273 }, // p1 left, right, jump (SDLK_LEFT/RIGHT/UP)
    .{ 97, 100, 119 }, // p2 a, d, w
    .{ 106, 108, 105 }, // p3 j, l, i
    .{ 260, 262, 264 }, // p4 keypad 4, 6, 8
};

/// addkey()/key_pressed() (sdl/interrpt.c:269/295, the non-kaillera
/// build) — the C's addkey() sets keyb[key & 0x7fff] from the 0x8000
/// release bit; the last_keys[] ring it also maintains feeds only the
/// cheat recognizer, which never consults AI-set keys, so it stays out of
/// this port. Declared extern fn so the harness can supply the C's own
/// storage semantics; the Zig bodies here mirror them.
fn addkey(key: c_uint) void {
    if ((key & 0x8000) == 0) {
        keyb[@intCast(key & 0x7fff)] = 1;
    } else {
        keyb[@intCast(key & 0x7fff)] = 0;
    }
}

fn keyPressed(key: c_int) c_int {
    // C's keyb[(unsigned char) key]: an implicit truncating cast, not a
    // range check, so values outside 0..255 (e.g. SDLK_UP = 273) wrap the
    // same way (unsigned char) does rather than trapping.
    const idx: u8 = @truncate(@as(c_uint, @bitCast(key)));
    return keyb[idx];
}

/// map_tile (main.c:1852): the tile at a pixel coordinate, BAN_VOID
/// outside the grid. The C's own bounds mixup — `pos_x < 17 || pos_y < 22`
/// tested against a 22-column, 17-row grid — is reproduced verbatim, and
/// the index is the C's `ban_map_raw[pos_y][pos_x]` with y selecting the row.
pub fn mapTile(pos_x: c_int, pos_y: c_int) c_int {
    // >> 4 on a signed int floors toward negative infinity; Zig's signed
    // >> matches, and fixed16.sar pins the same behavior for review.
    const x = fixed16.sar(pos_x, 4);
    const y = fixed16.sar(pos_y, 4);

    if (x < 0 or x >= 17 or y < 0 or y >= 22)
        return ban_void;

    // The bounds above admit y in [0,22) against a 17-row grid and x in
    // [0,17) against 22 columns. Indexing the flat cell sequence with the
    // C's own `y * 22 + x` (wrapping in 32 bits) keeps those out-of-range
    // reads on the same cells the C's contiguous array reads.
    // The bounds check above lets y reach 21 against ban_map's 17 rows, so
    // this read can run past the declared array the same way the C's bare
    // `ban_map[pos_y][pos_x]` does — an unchecked many-item pointer, not a
    // bounds-checked array, so it reads on into whatever memory follows
    // ban_map exactly like the C reference does, rather than panicking.
    const flat = y *% 22 +% x;
    const cells: [*]const c_uint = @ptrCast(&ban_map_raw);
    const idx: u32 = @bitCast(flat);
    return @bitCast(cells[idx]);
}

/// One AI tick for player `who` (the body of cpu_move's outer loop).
/// Returns false when the C `continue`s past the player: not an AI bunny,
/// not enabled, or no target found.
fn movePlayer(i: usize) bool {
    if (ai[i] == 0 or player_raw[i].enabled == 0) {
        return false;
    }

    // Nearest other enabled player by squared fixed-point distance. The C
    // compares `players_distance < nearest_distance || nearest_distance ==
    // -1` with both sides plain `int`: a signed comparison, so a
    // deltax²+deltay² that wraps into negative territory (-fwrapv, same as
    // the oracle) reads as "closer" than any positive nearest_distance —
    // reproduced verbatim, not corrected to unsigned. Ties keep the first
    // (lowest j) because `<` excludes equality.
    var target: ?usize = null;
    var nearest_distance: c_int = -1;
    var j: usize = 0;
    while (j < max_players) : (j += 1) {
        if (i == j or player_raw[j].enabled == 0) {
            continue;
        }
        const deltax = player_raw[j].x -% player_raw[i].x;
        const deltay = player_raw[j].y -% player_raw[i].y;
        const players_distance = deltax *% deltax +% deltay *% deltay;

        const closer = players_distance < nearest_distance or nearest_distance == -1;
        if (closer) {
            target = j;
            nearest_distance = players_distance;
        }
    }

    const t = target orelse return false;

    const cur_posx = player_raw[i].x >> 16;
    const cur_posy = player_raw[i].y >> 16;
    const tar_posx = player_raw[t].x >> 16;
    const tar_posy = player_raw[t].y >> 16;

    var lm: c_int = 0;
    var rm: c_int = 0;
    var jm: c_int = 0;

    // X-axis movement: chase, with the C's anti-jitter flips.
    if (tar_posx > cur_posx) {
        // Target on the right side: go after him.
        lm = 0;
        rm = 1;
    } else {
        // Target on the left side.
        lm = 1;
        rm = 0;
    }

    // Distance deltas between the target and us, for the two geometry
    // overrides below.
    const dx = tar_posx -% cur_posx;
    const dy = cur_posy -% tar_posy;
    if (dy < 32 and dy > 0 and dx < 32 + 8 and dx > -32) {
        // Close and slightly above: run the other way instead.
        lm = @intFromBool(lm == 0);
        rm = @intFromBool(rm == 0);
    } else if (dx < 4 + 8 and dx > -4) {
        // Makes the bunnies less "nervous" (the C's doubled `lm=0; lm=0;`
        // leaves rm from the chase branch — reproduced, not "fixed").
        lm = 0;
        lm = 0;
    }

    // Y-axis movement: the jump decision ladder. The key_pressed() checks
    // read this player's own jump key, which cpu_move itself rewrote on
    // the previous tick.
    const jump_key = keyPressed(key_pl[i][2]);
    if (mapTile(cur_posx, cur_posy +% 16) != ban_void and jump_key != 0) {
        // On ground with the jump key held: release it first or the bunny
        // can never jump again.
        jm = 0;
    } else if (mapTile(cur_posx, cur_posy -% 8) != ban_void and
        mapTile(cur_posx, cur_posy -% 8) != ban_water)
    {
        // Don't jump if there is something over it.
        jm = 0;
    } else if (mapTile(cur_posx -% (lm *% 8) +% (rm *% 16), cur_posy) != ban_void and
        mapTile(cur_posx -% (lm *% 8) +% (rm *% 16), cur_posy) != ban_water and
        cur_posx > 16 and cur_posx < 352 - 16 - 8)
    {
        // Obstacle on the way: jump over it.
        jm = 1;
    } else if ((jump_key != 0) and
        (mapTile(cur_posx -% (lm *% 8) +% (rm *% 16), cur_posy +% 8) != ban_void and
            mapTile(cur_posx -% (lm *% 8) +% (rm *% 16), cur_posy +% 8) != ban_water))
    {
        // This makes it possible to jump over 2 tiles.
        jm = 1;
    } else if (cur_posy -% tar_posy < 32 and cur_posy -% tar_posy > 0 and
        tar_posx -% cur_posx < 32 + 8 and tar_posx -% cur_posx > -32)
    {
        // Don't jump — running away.
        jm = 0;
    } else if (tar_posy <= cur_posy) {
        // Target on the upper side.
        jm = 1;
    } else {
        // Target below.
        jm = 0;
    }

    // Apply movements: press (addkey(key & 0x7f)) or release
    // (addkey((key & 0x7f) | 0x8000)) this player's left/right/jump keys.
    inline for (0..3) |slot| {
        const flag = if (slot == 0) lm else if (slot == 1) rm else jm;
        const key = key_pl[i][slot] & 0x7f;
        if (flag != 0) {
            addkey(@intCast(key));
        } else {
            addkey(@intCast(key | 0x8000));
        }
    }

    return true;
}

/// cpu_move (main.c:1866): one AI tick for every player.
pub export fn cpu_move() void {
    for (0..max_players) |i| {
        _ = movePlayer(i);
    }
}
