const std = @import("std");

// Phase 0 (TASK-003) of the C -> Zig port: wire up the four build steps the
// rest of the porting plan hangs off of, against an empty/stub core/. No
// simulation code exists yet, so `test` and `difftest` are empty step
// aggregators (populated incrementally as TASK-011.* ports land) while `abi`
// and `abitest` build/exercise real (currently empty) stub files, since
// TASK-012.02/TASK-012.03 need a concrete module to grow into rather than a
// step that starts from nothing. Targets Zig 0.16.0, pinned in
// ../.tool-versions and verified via `mise which zig`.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    addTestStep(b, target, optimize);
    addDiffTestStep(b, target, optimize);
    const abi_lib = addAbiStep(b, target, optimize);
    addAbiTestStep(b, target, optimize, abi_lib);
    addCliTools(b, target, optimize);
}

// TASK-010.05: Zig CLI rewrites of modify/jnbpack.c, modify/jnbunpack.c, and
// modify/gobpack.c, built on the dat/gob/pcx codecs above. Not part of the
// pure simulation core (they do real file I/O against argv), so each gets
// its own `zig build <name>` install step rather than joining `test`.
const cli_tools = [_]struct { name: []const u8, file: []const u8 }{
    .{ .name = "jnbpack", .file = "jnbpack_cli.zig" },
    .{ .name = "jnbunpack", .file = "jnbunpack_cli.zig" },
    .{ .name = "gobpack", .file = "gobpack_cli.zig" },
};

fn addCliTools(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    inline for (cli_tools) |tool| {
        const mod = b.createModule(.{
            .root_source_file = b.path(tool.file),
            .target = target,
            .optimize = optimize,
        });
        const exe = b.addExecutable(.{ .name = tool.name, .root_module = mod });
        const install = b.addInstallArtifact(exe, .{});
        const step = b.step(tool.name, "Build the Zig " ++ tool.name ++ " CLI");
        step.dependOn(&install.step);
    }
}

// Tier-A unit tests for ported Zig modules (docs/porting-playbook.md).
// Empty until TASK-011.* ports a main.c subsystem into its own core/*.zig
// module; each porting subtask appends its module's test file here.
const unit_test_files = [_][]const u8{ "dat.zig", "gob.zig", "pcx.zig", "levelmap.zig", "fixed16.zig", "world.zig", "flies.zig", "steer.zig", "objects.zig" };

fn addTestStep(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const step = b.step("test", "Run Tier-A unit tests for ported Zig modules");
    // steer.zig (and every future port that reaches another subsystem's
    // C-named global through the playbook's extern pattern — extern fn rnd,
    // extern var is_server) needs those names resolvable when its module is
    // built standalone. Compile the originals for this step only: rnd from
    // the same c_ref/rnd.c the Tier-B reference is built from (byte-identical
    // logic to core/rnd.zig's export, so unit tests exercise the identical
    // libc rand()-backed stream), with the rename suppressed so it keeps the
    // original name; is_server as an exported Zig global pinned to the
    // single-player value.
    const rnd_native_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    rnd_native_mod.addCSourceFile(.{ .file = b.path("c_ref/rnd.c"), .flags = &.{"-fwrapv"} });
    const rnd_native = b.addObject(.{ .name = "rnd_unit_ref", .root_module = rnd_native_mod });
    for (unit_test_files) |file| {
        const mod = b.createModule(.{
            .root_source_file = b.path(file),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        mod.linkSystemLibrary("bz2", .{});
        // TASK-011.06: flies.zig reaches rnd() as an extern fn (the
        // no-@import rule), so its Tier-A binary links rnd.zig's object the
        // same way the difftest entries link their renamed-C references.
        if (std.mem.eql(u8, file, "flies.zig")) {
            const rnd_obj = b.addObject(.{
                .name = "flies_unit_rnd",
                .root_module = b.createModule(.{
                    .root_source_file = b.path("rnd.zig"),
                    .target = target,
                    .optimize = optimize,
                    .link_libc = true,
                }),
            });
            mod.addObjectFile(rnd_obj.getEmittedBin());
        }
        // TASK-011.02: steer.zig (and every future port that reaches
        // another subsystem's C-named global through the playbook's extern
        // pattern — extern fn rnd, extern var is_server) needs those names
        // resolvable when its module is built standalone.
        if (std.mem.eql(u8, file, "steer.zig")) {
            mod.addObjectFile(rnd_native.getEmittedBin());
            // The Zig TU exporting is_server/is_net for standalone module
            // builds (see core/unit_net_globals.zig's header comment): compiled
            // as an object, not a test runner, so the module's own test binary
            // stays the single entry point.
            const net_globals_mod = b.createModule(.{
                .root_source_file = b.path("unit_net_globals.zig"),
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            });
            const net_globals_obj = b.addObject(.{ .name = "unit_net_globals", .root_module = net_globals_mod });
            mod.addObjectFile(net_globals_obj.getEmittedBin());
            // TASK-011.04: steer_players() reaches add_object() as an extern fn
            // (its canonical home moved to objects.zig). Link objects.zig's
            // export for the standalone steer unit-test build. objects.zig's
            // own extern globals (objects[]/object_anims[]/ban_map[]) resolve to
            // steer.zig's exports in this compilation, so no separate backing TU
            // is needed; only add_pob/add_leftovers (which neither steer.zig nor
            // objects.zig defines) need stubs, and those come from
            // unit_objects_globals' weak-free fn-only path below.
            const objects_obj = b.addObject(.{
                .name = "steer_unit_objects",
                .root_module = b.createModule(.{
                    .root_source_file = b.path("objects.zig"),
                    .target = target,
                    .optimize = optimize,
                    .link_libc = true,
                }),
            });
            mod.addObjectFile(objects_obj.getEmittedBin());
            // add_pob/add_leftovers stubs (objects.zig references them; the
            // renderer boundary is out of the core). Only the two fns are
            // exported here — the world arrays come from steer.zig above, so
            // the arrays-exporting unit_objects_globals.zig would collide.
            const obj_draw_obj = b.addObject(.{
                .name = "steer_unit_objects_draw",
                .root_module = b.createModule(.{
                    .root_source_file = b.path("unit_objects_draw.zig"),
                    .target = target,
                    .optimize = optimize,
                    .link_libc = true,
                }),
            });
            mod.addObjectFile(obj_draw_obj.getEmittedBin());
        }
        // TASK-011.04: objects.zig reaches rnd() as an extern fn (the
        // no-@import rule) and links libm's atan2 only inside its octant()
        // self-check (the reference the port replaces), so its Tier-A binary
        // needs the same rnd object steer.zig uses plus libm.
        if (std.mem.eql(u8, file, "objects.zig")) {
            mod.addObjectFile(rnd_native.getEmittedBin());
            mod.linkSystemLibrary("m", .{});
            // The Zig TU exporting objects[]/object_anims[]/ban_map[]/add_pob/
            // add_leftovers for standalone module builds (see
            // core/unit_objects_globals.zig's header comment): objects.zig
            // declares them extern (steer.zig owns them in the full build), so
            // its own test binary needs backing definitions compiled as an
            // object, not a test runner.
            const obj_globals_mod = b.createModule(.{
                .root_source_file = b.path("unit_objects_globals.zig"),
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            });
            const obj_globals_obj = b.addObject(.{ .name = "unit_objects_globals", .root_module = obj_globals_mod });
            mod.addObjectFile(obj_globals_obj.getEmittedBin());
        }
        const mod_test = b.addTest(.{ .root_module = mod });
        step.dependOn(&b.addRunArtifact(mod_test).step);
    }
}

// Tier-B differential tests: behavioral-equivalence checks between a
// pre-port C reference (symbols renamed via the preprocessor, following
// zelda3's compileRenamedCRef technique) and its ported .zig module, replayed
// over the TASK-008 corpus. rnd_difftest.zig started as the TASK-008.04
// harness pilot; as of TASK-011.01 it carries the real rnd(), fixed16 and
// world-layout differentials, and steer_difftest.zig (TASK-011.02) is the
// first per-tick stateful replay: the C reference is extracted verbatim from
// main.c by core/c_ref/extract_steered.py into core/c_ref/steer.c. Corpus-
// replay entries join as later TASK-011.* ports land.
const diff_test_files = [_][]const u8{ "rnd_difftest.zig", "cpu_move_difftest.zig", "flies_difftest.zig", "steer_difftest.zig", "objects_difftest.zig" };

fn addDiffTestStep(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const step = b.step("difftest", "Run Tier-B differential tests against renamed C references");

    // -fwrapv (added inside compileRenamedCRef) matters most here: rnd()'s
    // `%` against a value that can be INT_MIN is UB the oracle relies on
    // wrapping through, and UBSan checks would abort the difftest binary
    // instead.
    const rnd_ref = compileRenamedCRef(b, target, optimize, "rnd_c_ref", "c_ref/rnd.c", &.{"rnd"});
    // TASK-011.01: the fixed16 helpers are renamed at their _ref suffix so
    // each C expression keeps a name distinct from the Zig helper it mirrors.
    const cpu_move_ref = compileRenamedCRefSanitized(b, target, optimize, "cpu_move_c_ref", "c_ref/cpu_move.c", &.{ "cpu_move_ref", "map_tile_ref" }, .off);
    const fixed16_ref = compileRenamedCRef(b, target, optimize, "fixed16_c_ref", "c_ref/fixed16.c", &.{
        "fp_add_ref",
        "fp_sub_ref",
        "fp_neg_ref",
        "fp_mul_small_ref",
        "fp_pixel_shr16_ref",
        "fp_pixel_shr20_ref",
        "fp_sar_int_ref",
        "fp_bounce_quarter_ref",
        "fp_to_fixed_ref",
        "fp_from_pixel_shl_ref",
        "fp_wrap_mask_shl16_ref",
        "fp_wrap_mask_sub_shl16_ref",
        "fp_wrap_hi_shl16_ref",
        "fp_wrap_hi_plus15_shl16_ref",
        "fp_pixel_shl4_ref",
        "fp_to_tile20_ref",
    });
    // TASK-011.06: get_closest_player_to_point/update_flies/spawn_flies
    // renamed so they don't collide with flies.zig's own exports of those
    // names.
    const flies_ref = compileRenamedCRef(b, target, optimize, "flies_c_ref", "c_ref/flies.c", &.{
        "get_closest_player_to_point",
        "update_flies",
        "spawn_flies",
    });
    // TASK-011.02: steer.c is generated from main.c (see the script's
    // docstring); the rename list is its two ported entry points — the
    // reference's own helpers are file-static or already c_-prefixed.
    const steer_ref = compileRenamedCRef(b, target, optimize, "steer_c_ref", "c_ref/steer.c", &.{
        "steer_players",
        "position_player",
    });
    // TASK-011.04: objects.c is generated from main.c (see the script's
    // docstring); the rename list is its two ported entry points. add_pob/
    // add_leftovers are unrenamed (harness-owned, shared with the Zig port);
    // the C's internal update_objects -> add_object call resolves to
    // c_add_object through the same -D rename.
    // sanitize_c = .off: the particle physics reads ban_map[y >> 20][x >> 20]
    // at raw (sometimes negative or past-the-edge) indices exactly as the
    // oracle does — a butterfly climbing to y < 0 or a fur blob flying off to
    // x < -5*65536 — and the real binary falls through to whatever memory
    // follows ban_map. Zig's C frontend instruments static-array indexing with
    // runtime bounds checks that would trap instead; .off restores the oracle's
    // actual (unsafe, but shared-memory-safe here) behaviour for this reference,
    // the same way c_ref/cpu_move.c's map_tile mixup needs it. The harness pads
    // ban_map's backing identically on both sides, so identical inputs give
    // identical reads.
    const objects_ref = compileRenamedCRefSanitized(b, target, optimize, "objects_c_ref", "c_ref/objects.c", &.{
        "add_object",
        "update_objects",
    }, .off);

    for (diff_test_files) |file| {
        const mod = b.createModule(.{
            .root_source_file = b.path(file),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        mod.linkSystemLibrary("m", .{});
        const mod_test = b.addTest(.{ .root_module = mod });
        if (std.mem.eql(u8, file, "rnd_difftest.zig")) {
            mod_test.root_module.addObjectFile(rnd_ref);
            mod_test.root_module.addObjectFile(fixed16_ref);
        }
        if (std.mem.eql(u8, file, "cpu_move_difftest.zig")) {
            mod_test.root_module.addCSourceFile(.{ .file = b.path("c_ref/cpu_move_harness.c"), .flags = &.{"-fwrapv"} });
            mod_test.root_module.addObjectFile(cpu_move_ref);
        }
        if (std.mem.eql(u8, file, "flies_difftest.zig")) {
            mod_test.root_module.addCSourceFile(.{ .file = b.path("c_ref/flies_harness.c"), .flags = &.{"-fwrapv"} });
            mod_test.root_module.addObjectFile(flies_ref);
        }
        if (std.mem.eql(u8, file, "steer_difftest.zig")) {
            mod_test.root_module.addObjectFile(rnd_ref);
            mod_test.root_module.addObjectFile(steer_ref);
            // TASK-011.04: add_object()/update_objects() now live in
            // objects.zig, which steer_difftest.zig @imports directly (so its
            // root module already carries those exports — linking objects.zig a
            // second time here would duplicate them). Only the draw stubs
            // (add_pob/add_leftovers), which neither steer.zig nor objects.zig
            // defines, are added as a separate object.
            const steer_draw_obj = b.addObject(.{
                .name = "steer_dt_objects_draw",
                .root_module = b.createModule(.{
                    .root_source_file = b.path("unit_objects_draw.zig"),
                    .target = target,
                    .optimize = optimize,
                    .link_libc = true,
                }),
            });
            mod_test.root_module.addObjectFile(steer_draw_obj.getEmittedBin());
        }
        if (std.mem.eql(u8, file, "objects_difftest.zig")) {
            // The C reference's rnd() goes through c_rnd_from -> rnd_mod.rnd
            // (the harness's export), and objects.zig reaches rnd as an extern
            // fn; both bind rnd.zig's export, so link it like the difftests
            // above link rnd_ref. objects.c's atan2 is the oracle's own, kept
            // intact in the reference for the octant comparison.
            mod_test.root_module.addObjectFile(rnd_ref);
            mod_test.root_module.addObjectFile(objects_ref);
        }
        step.dependOn(&b.addRunArtifact(mod_test).step);
    }
}

// Compile a pre-port C source to an object with each of `syms` renamed to
// c_<name>, so it can link alongside the ported Zig module (which owns the
// original names) without colliding. The rename happens at the preprocessor
// level (`-D<sym>=c_<sym>`) rather than post-hoc with objcopy: the
// preprocessor rewrites every token occurrence in the TU (the definition and
// any same-TU references), which matches objcopy's symbol-table rewrite
// (definitions plus undefined cross-TU references) and, unlike objcopy,
// needs no external tool and works identically on ELF and Mach-O (whose
// leading-underscore symbol names silently defeat a bare-name objcopy
// invocation on macOS). Ported verbatim from zelda3's build.zig
// (compileRenamedCRef).
fn compileRenamedCRef(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, name: []const u8, src: []const u8, syms: []const []const u8) std.Build.LazyPath {
    return compileRenamedCRefSanitized(b, target, optimize, name, src, syms, null);
}

// cpu_move.c (TASK-011.05) deliberately exercises main.c's own map_tile
// bounds-check mixup (pos_x checked against 17, pos_y against 22, on a
// 22-column/17-row grid), reading past ban_map[][] the same way the real
// oracle binary does. Zig's C frontend instruments static-array indexing
// with the same runtime bounds checks as Zig's own arrays in Debug/
// ReleaseSafe, which would trap on that read instead of letting it fall
// through to whatever memory follows — sanitize_c = .off restores the
// oracle's actual (unsafe, but not undefined for this shared-memory
// harness) behavior for just this one reference object.
fn compileRenamedCRefSanitized(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, name: []const u8, src: []const u8, syms: []const []const u8, sanitize_c: ?std.zig.SanitizeC) std.Build.LazyPath {
    const ref_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .sanitize_c = sanitize_c,
    });
    // -fwrapv: signed overflow is UB in the abstract and this codebase
    // relies on two's-complement wraparound in practice (the oracle
    // Makefile builds main.c with -ffast-math, which implies the same
    // no-trapping stance). Without it, Zig's own clang emits UBSan checks
    // into the reference's arithmetic — which aborts the difftest binary
    // the moment a helper is probed at an overflow corner, instead of
    // returning the wrap the compiled oracle actually performs. The
    // difftest asserts zig-vs-reference agreement, which holds for any
    // flag set where the reference doesn't trap.
    const dflags = b.allocator.alloc([]const u8, syms.len + 1) catch @panic("OOM");
    dflags[0] = "-fwrapv";
    for (syms, 1..) |sym, i|
        dflags[i] = b.fmt("-D{s}=c_{s}", .{ sym, sym });
    ref_mod.addCSourceFile(.{ .file = b.path(src), .flags = dflags });
    const ref_obj = b.addObject(.{
        .name = name,
        .root_module = ref_mod,
    });
    return ref_obj.getEmittedBin();
}

// abi.zig (TASK-012.02) is the sole Zig file permitted to `export fn` the
// surface declared in ../include/jumpnbump.h. Built as a static library so
// the GDExtension shim (extension/, TASK-012.04) and the abitest suite below
// can link against it without depending on Zig's own module system. `.pic`
// matches neo_snake's convention: it ends up in a `ld -shared` step later,
// where non-PIC relocations in a static archive fail.
fn addAbiStep(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const abi = b.createModule(.{
        .root_source_file = b.path("abi.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
    });
    const abi_lib = b.addLibrary(.{
        .name = "jumpnbump",
        .linkage = .static,
        .root_module = abi,
    });
    b.installArtifact(abi_lib);
    const abi_step = b.step("abi", "Build the static library exporting the C ABI (core/abi.zig)");
    abi_step.dependOn(&b.addInstallArtifact(abi_lib, .{}).step);
    return abi_lib;
}

// abitest.zig (TASK-012.03) is the Tier-C ABI conformance suite: once
// ../include/jumpnbump.h exists, it reaches abi_lib exclusively through
// @cImport, never by importing core Zig modules directly (checked
// separately by a purity script, following neo_snake's
// tools/validate_abi_test_purity.py). Until then it's a placeholder that
// proves the step runs against the empty abi_lib built above.
fn addAbiTestStep(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, abi_lib: *std.Build.Step.Compile) void {
    const abitest = b.createModule(.{
        .root_source_file = b.path("abitest.zig"),
        .target = target,
        .optimize = optimize,
    });
    abitest.linkLibrary(abi_lib);
    const abitest_exe = b.addTest(.{ .root_module = abitest });
    const run_abitest = b.addRunArtifact(abitest_exe);
    const abitest_step = b.step("abitest", "Run the Tier-C ABI conformance tests (core/abitest.zig)");
    abitest_step.dependOn(&run_abitest.step);
}
