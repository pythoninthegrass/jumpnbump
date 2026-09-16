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
}

// Tier-A unit tests for ported Zig modules (docs/porting-playbook.md).
// Empty until TASK-011.* ports a main.c subsystem into its own core/*.zig
// module; each porting subtask appends its module's test file here.
const unit_test_files = [_][]const u8{ "dat.zig", "gob.zig", "pcx.zig", "levelmap.zig" };

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
// over the TASK-008 corpus. rnd_difftest.zig (TASK-008.04) is a trivial
// passthrough pilot proving the harness end-to-end; real corpus-replay
// entries are added as TASK-011.* ports land.
const diff_test_files = [_][]const u8{"rnd_difftest.zig"};

fn addDiffTestStep(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const step = b.step("difftest", "Run Tier-B differential tests against renamed C references");

    const rnd_ref = compileRenamedCRef(b, target, optimize, "rnd_c_ref", "c_ref/rnd.c", &.{"rnd"});

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
    const ref_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const dflags = b.allocator.alloc([]const u8, syms.len) catch @panic("OOM");
    for (syms, 0..) |sym, i|
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
