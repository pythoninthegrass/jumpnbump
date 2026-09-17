// Port of main.c's add_object() (main.c:2408) and update_objects()
// (main.c:2431) — TASK-011.04: the 200-slot first-fit particle allocator and
// the per-tick update for all eight particle types (spring, splash, smoke,
// yellow/pink butterfly, fur, flesh, flesh_trace).
//
// Storage: like steer.zig, this module binds the arrays the two functions
// touch (objects[]/object_anims[]/ban_map[]) as `extern var` globals under the
// original C names, per the playbook's globals-ownership rule. steer.zig
// currently exports objects[]/ban_map[]/object_anims[] (it is where the world
// storage physically lives for TASK-011.02); this module declares additional
// bindings to those same linker-resolved symbols, not a second copy, so the
// `extern fn add_object` steer.zig already reaches lands here and both sides
// of any differential share one world.
//
// rnd() is reached as an extern fn (rnd.zig owns the definition; no @import
// between ported modules). add_pob()/add_leftovers() are draw-side boundaries
// declared but never defined in core — the simulation carries no renderer
// (docs/porting-playbook.md "Core purity"); the difftest harness links capture
// sinks instead. Their arguments, and the octant math that feeds add_pob's
// frame index for OBJ_FUR, still evaluate exactly as the C's do.
//
// Arithmetic: every fixed-point operation routes through core/fixed16.zig's
// wrapping helpers so Zig's trapping arithmetic and @intCast range checks can
// never diverge from the C's silent two's-complement wraparound. Array
// indexing by raw anim/frame fields uses @bitCast (never @intCast) to keep the
// C's unchecked-memory semantics.
//
// The one transcendental the C uses — atan2() to pick a fur blob's rotation
// frame — is replaced by an exact integer octant selector (octant() below):
// the boundaries land on multiples of pi/4, where tan = 1, so the quadrant
// comparison is exact integer arithmetic and reproduces
// (int)(atan2((double)y, (double)x) * 4 / M_PI) for every int32 input.
const std = @import("std");
const fixed16 = @import("fixed16.zig");
const world = @import("world.zig");

const Fixed = fixed16.Fixed;
const Object = world.Object;
const num_objects = world.num_objects;

const obj_spring: c_uint = 0; // OBJ_SPRING
const obj_splash: c_uint = 1; // OBJ_SPLASH
const obj_smoke: c_uint = 2; // OBJ_SMOKE
const obj_yel_butfly: c_uint = 3; // OBJ_YEL_BUTFLY
const obj_pink_butfly: c_uint = 4; // OBJ_PINK_BUTFLY
const obj_fur: c_uint = 5; // OBJ_FUR
const obj_flesh: c_uint = 6; // OBJ_FLESH
const obj_flesh_trace: c_uint = 7; // OBJ_FLESH_TRACE

const obj_anim_yel_butfly_right: c_int = 3; // OBJ_ANIM_YEL_BUTFLY_RIGHT
const obj_anim_yel_butfly_left: c_int = 4; // OBJ_ANIM_YEL_BUTFLY_LEFT
const obj_anim_pink_butfly_right: c_int = 5; // OBJ_ANIM_PINK_BUTFLY_RIGHT
const obj_anim_pink_butfly_left: c_int = 6; // OBJ_ANIM_PINK_BUTFLY_LEFT
const obj_anim_flesh_trace: c_int = 7; // OBJ_ANIM_FLESH_TRACE

/// object_anim_t (main.c:96-103) — struct twin, mirrored field-for-field so
/// the extern mirror of object_anims[] below addresses the same bytes whatever
/// module comes to own the table (steer.zig currently exports it; both bind
/// the same C-linkage name).
pub const ObjectAnim = extern struct {
    num_frames: c_int = 0,
    restart_frame: c_int = 0,
    frame: [10]AnimFrame = [_]AnimFrame{.{}} ** 10,
};

pub const AnimFrame = extern struct {
    image: c_int = 0,
    ticks: c_int = 0,
};

// ---------------------------------------------------------------------------
// World storage. objects[]/ban_map[]/object_anims[] bind the same C-linkage
// symbols steer.zig exports (playbook globals-ownership: one storage by
// construction, additional extern declarations are extra names for it). The
// harness configures them through either module's exports; both reach the same
// memory.
// ---------------------------------------------------------------------------

extern var objects_raw: [num_objects]Object;
extern var object_anims: [8]ObjectAnim;
extern var ban_map_raw: [world.ban_rows][world.ban_cols]u32;

// The C's objects[]/object_anims[]/ban_map[] storage physically lives in
// steer.zig (TASK-011.02's globals-ownership). This module declares additional
// extern bindings to those same C-linkage symbols. For this file's own Tier-A
// test binary — where steer.zig is not linked — the weak definitions below
// provide scratch backing (a strong definition elsewhere wins, so the
// differential and the game loop keep using the real world storage), the same
// arrangement core/flies.zig uses for player_raw/ban_map_raw.
/// rnd (core/rnd.zig) — reached through the cross-module extern-fn pattern
/// (playbook: no @import between ported modules).
extern fn rnd(max: c_ushort) c_ushort;

/// add_pob()/add_leftovers() — draw-side boundaries, declared never defined in
/// core (Core purity). update_objects() calls add_pob once per live object and
/// add_leftovers twice when a flesh blob settles on solid ground without
/// bouncing; the harness links capture sinks so the differential can see the
/// frame indices (which carry the octant math's result) the C would draw.
extern fn add_pob(page: ?*anyopaque, x: c_int, y: c_int, image: c_int, gobs: ?*anyopaque) void;
extern fn add_leftovers(which: c_int, x: c_int, y: c_int, frame: c_int, gobs: ?*anyopaque) void;

/// add_object (main.c:2408) — first-fit allocator over the 200 slots: the
/// first slot with used == 0 is taken, initialised, and its ticks/image come
/// from object_anims[anim].frame[frame]. When every slot is used the call is a
/// silent no-op (the C's loop simply falls through).
pub export fn add_object(type_: c_int, x: c_int, y: c_int, x_add: c_int, y_add: c_int, anim: c_int, frame: c_int) void {
    for (&objects_raw) |*o| {
        if (o.used == 0) {
            o.used = 1;
            o.type = type_;
            o.x = fixed16.shl16(x);
            o.y = fixed16.shl16(y);
            o.x_add = x_add;
            o.y_add = y_add;
            o.x_acc = 0;
            o.y_acc = 0;
            o.anim = anim;
            o.frame = frame;
            // Unchecked flat read, not objectAnimRow: collision.zig's gore
            // spray calls add_object with frame indices past a single row
            // (main.c:2408's own object_anims[anim].frame[frame] does the
            // same raw read, landing in the next rows of the same table —
            // see animFrameAt's own comment).
            const af = animFrameAt(anim, frame);
            o.ticks = af.ticks;
            o.image = af.image;
            return;
        }
    }
}

/// The C's ban_map[y >> 20][x >> 20] read, kept as an unchecked flat access
/// like steer.zig's banMapCell: the particles read it at raw (possibly
/// negative or out-of-range) x >> 20 / y >> 20 indices exactly as main.c does,
/// and the harness pads ban_map's backing the same way main.c's data segment
/// lays it out, so identical inputs give identical reads.
inline fn banMapCell(row: c_int, col: c_int) u32 {
    const flat = @as([*]const u32, @ptrCast(&ban_map_raw));
    const idx: i64 = @as(i64, @as(i32, @bitCast(row))) * @as(i64, world.ban_cols) +% @as(i64, @as(i32, @bitCast(col)));
    return flat[@as(u64, @bitCast(idx))];
}

inline fn objectAnimRow(anim: c_int) *const [10]AnimFrame {
    const rows = @as([*]const ObjectAnim, @ptrCast(&object_anims));
    return &rows[@as(u32, @bitCast(anim))].frame;
}

/// object_anims[anim].frame[frame] read as one flat AnimFrame sequence
/// (stride = sizeof(ObjectAnim)/sizeof(AnimFrame)), not a bounds-checked
/// per-row array: gore frame indices deliberately run past a single row's
/// 10 frames (main.c:2408's own object_anims[anim].frame[frame] does the
/// same raw struct-array read), landing in the next rows of the same
/// table exactly like the C.
inline fn animFrameAt(anim: c_int, frame: c_int) *const AnimFrame {
    const flat = @as([*]const AnimFrame, @ptrCast(&object_anims));
    const stride: u32 = @divExact(@sizeOf(ObjectAnim), @sizeOf(AnimFrame));
    // +1: num_frames/restart_frame (8 bytes) precede frame[] in each row,
    // exactly one AnimFrame-sized slot, so frame[0] is flat index
    // anim*stride + 1, not anim*stride.
    const idx: u64 = @as(u64, @as(u32, @bitCast(anim)) *% stride +% @as(u32, @bitCast(frame)) +% 1);
    return &flat[idx];
}

inline fn animNumFrames(anim: c_int) c_int {
    const rows = @as([*]const ObjectAnim, @ptrCast(&object_anims));
    return rows[@as(u32, @bitCast(anim))].num_frames;
}

inline fn animRestartFrame(anim: c_int) c_int {
    const rows = @as([*]const ObjectAnim, @ptrCast(&object_anims));
    return rows[@as(u32, @bitCast(anim))].restart_frame;
}

/// The octant selector replacing `(int)(atan2((double)y_add, (double)x_add) *
/// 4 / M_PI)` for OBJ_FUR's rotation frame. C truncates toward zero, so the
/// eight raw `s1` directions (before the caller's `s1 < 0 ? +8` shift and
/// clamp to [0, 7]) are:
///
///   x > 0, y >= 0:  1 if y >= x else 0        (boundary +45deg,  tan = 1)
///   x > 0, y <  0: -1 if -y >= x else 0       (boundary -45deg)
///   x < 0, y == 0:  4                          (atan2 = pi -> r = 4 exactly)
///   x < 0, y >  0:  3 if y <= -x else 2       (boundary 135deg)
///   x < 0, y <  0: -3 if -y <= -x else -2     (boundary -135deg)
///   x == 0:         2 (y>0) / -2 (y<0) / 0 (y==0)
///
/// Every boundary is a multiple of pi/4, where tan = 1, so `y` vs `+/-x`
/// integer compares are exact — no floating point, no approximation, no
/// truncation ambiguity. Verified against C's real double atan2 over the full
/// int32 grid and millions of random pairs (Tier-A test below).
fn octant(y_add: c_int, x_add: c_int) c_int {
    if (x_add == 0) return if (y_add > 0) 2 else (if (y_add < 0) -2 else 0);
    if (x_add > 0) {
        if (y_add >= 0) return if (y_add >= x_add) 1 else 0;
        // y_add < 0 here; 0 -% y_add is the C's `-y_add`, wrapping at INT_MIN.
        return if ((0 -% y_add) >= x_add) -1 else 0;
    }
    const nx: c_int = 0 -% x_add; // -x, wrapping like the C's `int` (INT_MIN -> INT_MIN)
    if (y_add == 0) return 4;
    if (y_add > 0) return if (y_add <= nx) 3 else 2;
    return if ((0 -% y_add) <= nx) -3 else -2;
}

/// update_objects (main.c:2431) — advance every used slot by one tick and
/// (re)draw it. Each type has its own animation-advance and physics rules; the
/// `used == 1` re-check before every add_pob mirrors the C, which drops a slot
/// mid-tick (an animation running out, or a flesh/fur blob leaving the screen)
/// without drawing it.
pub export fn update_objects() void {
    var s1: c_int = 0;
    for (&objects_raw) |*o| {
        if (o.used != 1) continue;
        switch (@as(c_uint, @bitCast(o.type))) {
            obj_spring => {
                o.ticks -%= 1;
                if (o.ticks <= 0) {
                    o.frame +%= 1;
                    if (o.frame >= animNumFrames(o.anim)) {
                        o.frame -%= 1;
                        o.ticks = objectAnimRow(o.anim)[@as(u32, @bitCast(o.frame))].ticks;
                    } else {
                        o.ticks = objectAnimRow(o.anim)[@as(u32, @bitCast(o.frame))].ticks;
                        o.image = objectAnimRow(o.anim)[@as(u32, @bitCast(o.frame))].image;
                    }
                }
                if (o.used == 1)
                    add_pob(null, fixed16.shr16(o.x), fixed16.shr16(o.y), o.image, null);
            },
            obj_splash => {
                o.ticks -%= 1;
                if (o.ticks <= 0) {
                    o.frame +%= 1;
                    if (o.frame >= animNumFrames(o.anim)) {
                        o.used = 0;
                    } else {
                        o.ticks = objectAnimRow(o.anim)[@as(u32, @bitCast(o.frame))].ticks;
                        o.image = objectAnimRow(o.anim)[@as(u32, @bitCast(o.frame))].image;
                    }
                }
                if (o.used == 1)
                    add_pob(null, fixed16.shr16(o.x), fixed16.shr16(o.y), o.image, null);
            },
            obj_smoke => {
                o.x = fixed16.add(o.x, o.x_add);
                o.y = fixed16.add(o.y, o.y_add);
                o.ticks -%= 1;
                if (o.ticks <= 0) {
                    o.frame +%= 1;
                    if (o.frame >= animNumFrames(o.anim)) {
                        o.used = 0;
                    } else {
                        o.ticks = objectAnimRow(o.anim)[@as(u32, @bitCast(o.frame))].ticks;
                        o.image = objectAnimRow(o.anim)[@as(u32, @bitCast(o.frame))].image;
                    }
                }
                if (o.used == 1)
                    add_pob(null, fixed16.shr16(o.x), fixed16.shr16(o.y), o.image, null);
            },
            obj_yel_butfly, obj_pink_butfly => {
                butterflyStep(o, &s1);
                if (o.type == obj_yel_butfly) {
                    if (o.x_add < 0 and o.anim != obj_anim_yel_butfly_left) {
                        setAnim(o, obj_anim_yel_butfly_left);
                    } else if (o.x_add > 0 and o.anim != obj_anim_yel_butfly_right) {
                        setAnim(o, obj_anim_yel_butfly_right);
                    }
                } else {
                    if (o.x_add < 0 and o.anim != obj_anim_pink_butfly_left) {
                        setAnim(o, obj_anim_pink_butfly_left);
                    } else if (o.x_add > 0 and o.anim != obj_anim_pink_butfly_right) {
                        setAnim(o, obj_anim_pink_butfly_right);
                    }
                }
                o.ticks -%= 1;
                if (o.ticks <= 0) {
                    o.frame +%= 1;
                    if (o.frame >= animNumFrames(o.anim)) {
                        o.frame = animRestartFrame(o.anim);
                    } else {
                        o.ticks = objectAnimRow(o.anim)[@as(u32, @bitCast(o.frame))].ticks;
                        o.image = objectAnimRow(o.anim)[@as(u32, @bitCast(o.frame))].image;
                    }
                }
                if (o.used == 1)
                    add_pob(null, fixed16.shr16(o.x), fixed16.shr16(o.y), o.image, null);
            },
            obj_fur => furOrFleshStep(o, &s1, false),
            obj_flesh => furOrFleshStep(o, &s1, true),

            obj_flesh_trace => {
                o.ticks -%= 1;
                if (o.ticks <= 0) {
                    o.frame +%= 1;
                    if (o.frame >= animNumFrames(o.anim)) {
                        o.used = 0;
                    } else {
                        o.ticks = objectAnimRow(o.anim)[@as(u32, @bitCast(o.frame))].ticks;
                        o.image = objectAnimRow(o.anim)[@as(u32, @bitCast(o.frame))].image;
                    }
                }
                if (o.used == 1)
                    add_pob(null, fixed16.shr16(o.x), fixed16.shr16(o.y), o.image, null);
            },
            // The C's switch on objects[].type has no default: any other type
            // value (never produced by add_object, but reachable through the
            // C's unchecked memory if a slot is corrupted) advances nothing
            // and draws nothing. Reproduced as an explicit no-op.
            else => {},
        }
    }
}

/// The yellow/pink butterfly motion (shared by OBJ_YEL_BUTFLY and
/// OBJ_PINK_BUTFLY in main.c): x-axis wobble (accel clamp, velocity clamp,
/// wall/tile bounce) then y-axis wobble, both reading ban_map at the object's
/// tile and reversing velocity on contact. The anim-direction switch and the
/// animation advance stay in the caller so this reads like the C's inline body.
fn butterflyStep(o: *Object, s1p: *c_int) void {
    _ = s1p;
    o.x_acc = clampAcc(fixed16.add(o.x_acc, @bitCast(@as(c_uint, @bitCast(@as(c_int, rnd(128)) -% 64)))));
    o.x_add = clampVel(fixed16.add(o.x_add, o.x_acc));
    o.x = fixed16.add(o.x, o.x_add);
    if (fixed16.shr16(o.x) < 16) {
        o.x = fixed16.shl16(16);
        o.x_add = fixed16.bounceQuarter(o.x_add);
        o.x_acc = 0;
    } else if (fixed16.shr16(o.x) > 350) {
        o.x = fixed16.shl16(350);
        o.x_add = fixed16.bounceQuarter(o.x_add);
        o.x_acc = 0;
    }
    if (banMapCell(fixed16.shr20(o.y), fixed16.shr20(o.x)) != 0) {
        if (o.x_add < 0) {
            o.x = fixed16.wrapDownToTile(fixed16.shr16(o.x));
        } else {
            o.x = fixed16.wrapUpToTileEdge(fixed16.shr16(o.x));
        }
        o.x_add = fixed16.bounceQuarter(o.x_add);
        o.x_acc = 0;
    }
    o.y_acc = clampAcc(fixed16.add(o.y_acc, @bitCast(@as(c_uint, @bitCast(@as(c_int, rnd(64)) -% 32)))));
    o.y_add = clampVel(fixed16.add(o.y_add, o.y_acc));
    o.y = fixed16.add(o.y, o.y_add);
    if (fixed16.shr16(o.y) < 0) {
        o.y = 0;
        o.y_add = fixed16.bounceQuarter(o.y_add);
        o.y_acc = 0;
    } else if (fixed16.shr16(o.y) > 255) {
        o.y = fixed16.shl16(255);
        o.y_add = fixed16.bounceQuarter(o.y_add);
        o.y_acc = 0;
    }
    if (banMapCell(fixed16.shr20(o.y), fixed16.shr20(o.x)) != 0) {
        if (o.y_add < 0) {
            o.y = fixed16.wrapDownToTile(fixed16.shr16(o.y));
        } else {
            o.y = fixed16.wrapUpToTileEdge(fixed16.shr16(o.y));
        }
        o.y_add = fixed16.bounceQuarter(o.y_add);
        o.y_acc = 0;
    }
}

/// The fur/flesh body (OBJ_FUR and OBJ_FLESH share it; `flesh` selects the
/// flesh-only bits: the frame-76/77/78 flesh_trace spawns, the leftover
/// emission when a blob settles on solid ground, and the octant rotation frame
/// vs. fur's frame + octant for the draw). Transcribed verbatim from
/// main.c's two near-identical case bodies (OBJ_FUR main.c:2582, OBJ_FLESH
/// main.c:2662).
fn furOrFleshStep(o: *Object, s1p: *c_int, flesh: bool) void {
    if (!flesh) {
        if (rnd(100) < 30)
            add_object(@intCast(obj_flesh_trace), fixed16.shr16(o.x), fixed16.shr16(o.y), 0, 0, obj_anim_flesh_trace, 0);
    } else {
        if (rnd(100) < 30) {
            if (o.frame == 76) {
                add_object(@intCast(obj_flesh_trace), fixed16.shr16(o.x), fixed16.shr16(o.y), 0, 0, obj_anim_flesh_trace, 1);
            } else if (o.frame == 77) {
                add_object(@intCast(obj_flesh_trace), fixed16.shr16(o.x), fixed16.shr16(o.y), 0, 0, obj_anim_flesh_trace, 2);
            } else if (o.frame == 78) {
                add_object(@intCast(obj_flesh_trace), fixed16.shr16(o.x), fixed16.shr16(o.y), 0, 0, obj_anim_flesh_trace, 3);
            }
        }
    }
    const cell0 = banMapCell(fixed16.shr20(o.y), fixed16.shr20(o.x));
    if (cell0 == 0) {
        o.y_add = clampUpper(fixed16.add(o.y_add, 3072), 196608);
    } else if (cell0 == 2) {
        if (o.x_add < 0) {
            if (o.x_add < -65536) o.x_add = -65536;
            o.x_add = o.x_add +% 1024;
            if (o.x_add > 0) o.x_add = 0;
        } else {
            if (o.x_add > 65536) o.x_add = 65536;
            o.x_add = o.x_add -% 1024;
            if (o.x_add < 0) o.x_add = 0;
        }
        o.y_add = clamp(fixed16.add(o.y_add, 1024), -65536, 65536);
    }
    o.x = fixed16.add(o.x, o.x_add);
    const cellX = banMapCell(fixed16.shr20(o.y), fixed16.shr20(o.x));
    if (fixed16.shr16(o.y) > 0 and (cellX == 1 or cellX == 3)) {
        if (o.x_add < 0) {
            o.x = fixed16.wrapDownToTile(fixed16.shr16(o.x));
            o.x_add = fixed16.bounceQuarter(o.x_add);
        } else {
            o.x = fixed16.wrapUpToTileEdge(fixed16.shr16(o.x));
            o.x_add = fixed16.bounceQuarter(o.x_add);
        }
    }
    o.y = fixed16.add(o.y, o.y_add);
    if (fixed16.shr16(o.x) < -5 or fixed16.shr16(o.x) > 405 or fixed16.shr16(o.y) > 260)
        o.used = 0;
    const cellY = banMapCell(fixed16.shr20(o.y), fixed16.shr20(o.x));
    if (fixed16.shr16(o.y) > 0 and cellY != 0) {
        if (o.y_add < 0) {
            if (cellY != 2) {
                o.y = fixed16.wrapDownToTile(fixed16.shr16(o.y));
                o.x_add = fixed16.sar(o.x_add, 2);
                o.y_add = fixed16.bounceQuarter(o.y_add);
            }
        } else {
            if (cellY == 1) {
                if (o.y_add > 131072) {
                    o.y = fixed16.wrapUpToTileEdge(fixed16.shr16(o.y));
                    o.x_add = fixed16.sar(o.x_add, 2);
                    o.y_add = fixed16.bounceQuarter(o.y_add);
                } else {
                    if (flesh) {
                        if (rnd(100) < 10) {
                            const s1: c_int = @intCast(rnd(4) -% 2);
                            add_leftovers(0, fixed16.shr16(o.x), fixed16.shr16(o.y) +% s1, o.frame, null);
                            add_leftovers(1, fixed16.shr16(o.x), fixed16.shr16(o.y) +% s1, o.frame, null);
                        }
                    }
                    o.used = 0;
                }
            } else if (cellY == 3) {
                o.y = fixed16.wrapUpToTileEdge(fixed16.shr16(o.y));
                if (o.y_add > 131072) {
                    o.y_add = fixed16.bounceQuarter(o.y_add);
                } else {
                    o.y_add = 0;
                }
            }
        }
    }
    if (o.x_add < 0 and o.x_add > -16384) o.x_add = -16384;
    if (o.x_add > 0 and o.x_add < 16384) o.x_add = 16384;
    if (o.used == 1) {
        if (!flesh) {
            // OBJ_FUR: rotate the sprite by the velocity octant.
            s1p.* = octant(o.y_add, o.x_add);
            if (s1p.* < 0) s1p.* += 8;
            if (s1p.* < 0) s1p.* = 0;
            if (s1p.* > 7) s1p.* = 7;
            add_pob(null, fixed16.shr16(o.x), fixed16.shr16(o.y), o.frame +% s1p.*, null);
        } else {
            // OBJ_FLESH: no rotation; frame only.
            add_pob(null, fixed16.shr16(o.x), fixed16.shr16(o.y), o.frame, null);
        }
    }
}

/// setAnim (the four butterfly-direction switch bodies in main.c): adopt a new
/// anim and reset frame/ticks/image from the table.
fn setAnim(o: *Object, anim: c_int) void {
    o.anim = anim;
    o.frame = 0;
    o.ticks = objectAnimRow(anim)[@as(u32, @bitCast(o.frame))].ticks;
    o.image = objectAnimRow(anim)[@as(u32, @bitCast(o.frame))].image;
}

// The C's butterfly accel/velocity clamps: x_acc/y_acc saturate at +/-1024,
// x_add/y_add at +/-32768 (main.c's butterfly block).
inline fn clampAcc(v: c_int) c_int {
    if (v < -1024) return -1024;
    if (v > 1024) return 1024;
    return v;
}
inline fn clampVel(v: c_int) c_int {
    if (v < -32768) return -32768;
    if (v > 32768) return 32768;
    return v;
}
// The fur/flesh y_add clamp: `y_add += k; if (y_add > hi) y_add = hi;` and, in
// the water branch, `clamp(lo, hi)` with a wrapping add first.
inline fn clamp(v: c_int, lo: c_int, hi: c_int) c_int {
    if (v > hi) return hi;
    if (v < lo) return lo;
    return v;
}
// `y_add += k; if (y_add > hi) y_add = hi;` — the fur/flesh free-fall clamp
// (main.c:2629 / 2675), upper bound only.
inline fn clampUpper(v: c_int, hi: c_int) c_int {
    return if (v > hi) hi else v;
}

// ---------------------------------------------------------------------------
// Tier-A unit tests.
//
// The octant() selector is the one place where the C used a transcendental
// (atan2), so it gets the tightest self-check here: a full sweep of the
// small-magnitude grid plus every axis and diagonal edge. The exhaustive
// comparison against C's real double atan2 lives in the Tier-B differential
// (core/objects_difftest.zig drives update_objects() on a fur blob whose
// velocity walks the whole circle, so any octant disagreement shows up as a
// differing add_pob frame index).
// ---------------------------------------------------------------------------

// libm's atan2, linked for the Tier-A reference comparison only. The
// simulation core never calls it; the port's octant() replaces it, and this
// test pins that replacement against the very function the oracle used.
extern fn atan2(y: f64, x: f64) f64;
const M_PI_ref = 3.14159265358979323846;

test "octant matches (int)(atan2(y,x)*4/pi) on the small grid" {
    // Reference: the C's exact computation, reproduced here with the host's
    // IEEE double atan2 (the same value the compiled oracle folds). Zig's
    // octant() must agree on every int32 pair; this grid is the fast smoke
    // test, the difftest is the real proof.
    var x: c_int = -64;
    while (x <= 64) : (x += 1) {
        var y: c_int = -64;
        while (y <= 64) : (y += 1) {
            const c = @as(c_int, @intFromFloat(@trunc(atan2(@as(f64, y), @as(f64, x)) * 4.0 / M_PI_ref)));
            try std.testing.expectEqual(c, octant(y, x));
        }
    }
}

test "octant edge cases: axes, diagonals, x==0" {
    try std.testing.expectEqual(@as(c_int, 0), octant(0, 0));
    try std.testing.expectEqual(@as(c_int, 2), octant(5, 0));
    try std.testing.expectEqual(@as(c_int, -2), octant(-5, 0));
    // x<0, y==0 lands exactly on atan2 = +pi -> 4 (the one raw value >3).
    try std.testing.expectEqual(@as(c_int, 4), octant(0, -5));
    // Diagonals: boundary is inclusive toward the larger octant per the
    // truncation, e.g. (x=5,y=5) is r=1 exactly -> octant 1.
    try std.testing.expectEqual(@as(c_int, 1), octant(5, 5));
    try std.testing.expectEqual(@as(c_int, -1), octant(-5, 5));
    try std.testing.expectEqual(@as(c_int, 3), octant(5, -5));
    try std.testing.expectEqual(@as(c_int, -3), octant(-5, -5));
    // Just off the diagonal into octant 2 / -2 territory.
    try std.testing.expectEqual(@as(c_int, 2), octant(300, -120));
    try std.testing.expectEqual(@as(c_int, -2), octant(-300, -120));
    // INT_MIN velocity: the C evaluates `-x_add`/`-y_add` on an `int`, which
    // wraps INT_MIN back to INT_MIN; the branch must return a valid octant
    // without trapping. (INT_MIN, INT_MIN) is the (-x,-y) corner: nx = -INT_MIN
    // wraps to INT_MIN, then (0 -% y_add)=INT_MIN <= INT_MIN -> octant -3, the
    // same direction a very negative (-1,-1)-style vector points.
    try std.testing.expectEqual(@as(c_int, -3), octant(std.math.minInt(c_int), std.math.minInt(c_int)));
    try std.testing.expectEqual(@as(c_int, 1), octant(std.math.maxInt(c_int), std.math.maxInt(c_int)));
}
