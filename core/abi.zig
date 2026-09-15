// Sole home of `export fn` in core/ (TASK-012.02). Populated once
// ../include/jumpnbump.h exists: every declaration there gets a matching
// callconv(.c) export fn here, wrapping the ported simulation modules
// (TASK-011.*). Empty for now — TASK-003 only needs `zig build abi` to
// produce a (currently symbol-less) static library.
