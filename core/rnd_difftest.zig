const std = @import("std");
const rnd_zig = @import("rnd.zig");

const c = @cImport({
    @cInclude("stdlib.h");
});

extern fn c_rnd(max: c_ushort) c_ushort;

test "rnd.zig passthrough matches the renamed C reference" {
    // Phase 1 pilot (TASK-008.04): rnd() has no per-tick simulation state to
    // replay yet (real corpus replay is TASK-011.*'s job, once a module with
    // actual game state is ported). This proves the harness plumbing itself
    // -- a renamed-C object linked into a Zig test module, diffed against a
    // plain Zig fn -- works end-to-end with zero mismatches, driving both
    // sides for as many ticks as the shortest committed corpus trace
    // (tests/corpus/01-single-player-basic.jsonl, docs in
    // tests/corpus/README.md) has frames.
    const corpus_ticks: usize = 36;

    var mismatches: usize = 0;
    var tick: usize = 0;
    while (tick < corpus_ticks) : (tick += 1) {
        const max: u16 = @intCast((tick % 250) + 1);
        const seed: c_uint = @intCast(tick + 1);

        c.srand(seed);
        const got = rnd_zig.rnd(max);

        c.srand(seed);
        const want = c_rnd(max);

        if (got != want) {
            std.debug.print("tick {d}: zig rnd({d})={d} != c_ref rnd({d})={d}\n", .{ tick, max, got, max, want });
            mismatches += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), mismatches);
}
