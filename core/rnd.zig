// Port of main.c's rnd() (main.c:3562) — TASK-011.01, the leaf dependency
// every other TASK-011.* module draws random values from.
//
// Despite the task description's "LCG" phrasing, rnd() is a thin wrapper
// over libc rand(), not a custom linear congruential generator: the state
// machine is glibc's, seeded once via srand() at startup (main.c:3250).
// This module owns rnd() plus the checksum scaffolding counter around it.
// It keeps libc's < 0x7fff / == 0x7fff / else #if preprocessor branches as
// comptime ifs, exactly like the C.

const c = @cImport({
    @cInclude("stdlib.h");
});

/// rnd_call_count (main.c:72): incremented on every rnd() call; stands in
/// for rand()'s unobservable internal PRNG state in the canonical
/// checksum (docs/checksum-format.md). main.c declares it `unsigned int`;
/// exported like the C's global so later modules mirror it with
/// `extern var` per the playbook's globals-ownership rule.
pub export var rnd_call_count: c_uint = 0;

/// rnd(max) (main.c:3562): the next rand() draw reduced mod max, returned
/// as u16 — the C's (unsigned short) cast keeps the low 16 bits, so this
/// must truncate, not range-check, even though rand()'s low bits stay
/// inside u16 on every RAND_MAX the branches accept.
pub export fn rnd(max: u16) u16 {
    rnd_call_count +%= 1;
    if (c.RAND_MAX < 0x7fff) {
        @compileError("rand returns too small values");
    } else if (c.RAND_MAX == 0x7fff) {
        // (unsigned short)((rand()*2) % (int)max) — the *2 is safe inside
        // the int range the branch implies, so no wrapping operator.
        const r: u16 = @intCast(@mod(c.rand() * 2, @as(c_int, max)));
        return r;
    } else {
        const r: u16 = @intCast(@mod(c.rand(), @as(c_int, max)));
        return r;
    }
}

/// Seed both halves of the RNG state the C seeds together: libc's PRNG
/// via srand() and rnd_call_count (main.c:3250 reseeds srand(); the
/// counter's zeroing rides along here so a harness can reset both sides
/// with one call).
pub fn seed(seed_: u32) void {
    rnd_call_count = 0;
    c.srand(seed_);
}
