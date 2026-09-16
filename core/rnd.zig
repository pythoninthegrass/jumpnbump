const c = @cImport({
    @cInclude("stdlib.h");
});

/// Phase 1 (TASK-008.04) differential-test pilot: a trivial passthrough
/// "port" of main.c's rnd() (minus the headless-only rnd_call_count
/// bookkeeping added in TASK-008.02, which isn't part of the RNG formula).
/// Exists only to prove the renamed-C-reference difftest harness works
/// end-to-end before any real TASK-011.* module exists to diff for real.
pub fn rnd(max: u16) u16 {
    if (c.RAND_MAX < 0x7fff) @compileError("rand returns too small values");
    if (c.RAND_MAX == 0x7fff) {
        return @intCast(@mod(c.rand() *% 2, @as(c_int, max)));
    }
    return @intCast(@mod(c.rand(), @as(c_int, max)));
}
