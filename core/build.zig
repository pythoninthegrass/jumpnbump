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
const unit_test_files = [_][]const u8{ "dat.zig", "gob.zig", "pcx.zig", "levelmap.zig", "fixed16.zig", "world.zig" };

fn addTestStep(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const step = b.step("test", "Run Tier-A unit tests for ported Zig modules");
    for (unit_test_files) |file| {
        const mod = b.createModule(.{
            .root_source_file = b.path(file),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        mod.linkSystemLibrary("bz2", .{});
        const mod_test = b.addTest(.{ .root_module = mod });
        step.dependOn(&b.addRunArtifact(mod_test).step);
    }
}

// Tier-B differential tests: behavioral-equivalence checks between a
// pre-port C reference (symbols renamed via the preprocessor, following
// zelda3's compileRenamedCRef technique) and its ported .zig module, replayed
// over the TASK-008 corpus. rnd_difftest.zig started as the TASK-008.04
// harness pilot; as of TASK-011.01 it carries the real rnd(), fixed16 and
// world-layout differentials. Corpus-replay entries join as later TASK-011.*
// ports land.
const diff_test_files = [_][]const u8{ "rnd_difftest.zig", "cpu_move_difftest.zig" };

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

    for (diff_test_files) |file| {
        const mod = b.createModule(.{
            .root_source_file = b.path(file),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        const mod_test = b.addTest(.{ .root_module = mod });
        if (std.mem.eql(u8, file, "rnd_difftest.zig")) {
            mod_test.root_module.addObjectFile(rnd_ref);
            mod_test.root_module.addObjectFile(fixed16_ref);
        }
        if (std.mem.eql(u8, file, "cpu_move_difftest.zig")) {
            mod_test.root_module.addCSourceFile(.{ .file = b.path("c_ref/cpu_move_harness.c"), .flags = &.{"-fwrapv"} });
            mod_test.root_module.addObjectFile(cpu_move_ref);
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
