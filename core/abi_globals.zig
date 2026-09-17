// Real, single-definition storage for the world-state arrays every ported
// Phase 3 module (core/steer.zig, core/objects.zig, core/collision.zig,
// core/flies.zig, core/cpu_move.zig) reaches through `extern var`
// (player_raw[]/objects_raw[]/ban_map_raw[]/keyb[]/no_gore) — the
// production-build counterpart to core/c_ref/sim_harness.c's role in the
// Tier-A/B test binaries (TASK-012.02).
//
// This has to be its own compilation unit, linked into core/abi.zig's
// module as a pre-compiled object (see core/build.zig's addAbiStep), rather
// than a set of `export var`s inside abi.zig itself: core/steer.zig and
// core/collision.zig each carry their own *weak* fallback definitions of
// these same names (for when either module is its own standalone Tier-A
// test root), and abi.zig `@import`s game_loop.zig which in turn `@import`s
// both — putting a second, *strong* definition in the same Zig compilation
// as those weak ones trips Zig's own export-collision check before any
// linker even runs. Compiling this file separately and linking the object
// (exactly the technique core/build.zig's game_loop_difftest.zig wiring
// already uses for core/c_ref/sim_harness.c, for the identical reason) lets
// ordinary ELF weak-symbol override (strong beats weak) resolve it at the
// final link step instead.
const world = @import("world.zig");

export var player_raw: [world.max_players]world.Player = [_]world.Player{.{}} ** world.max_players;
export var objects_raw: [world.num_objects]world.Object = [_]world.Object{.{}} ** world.num_objects;
export var ban_map_raw: [world.ban_rows][world.ban_cols]u32 = [_][world.ban_cols]u32{[_]u32{0} ** world.ban_cols} ** world.ban_rows;
export var keyb: [256]i8 = [_]i8{0} ** 256;
export var no_gore: c_int = 0;
