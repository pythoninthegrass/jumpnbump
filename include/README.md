# include/

`jumpnbump.h`: the frozen C ABI boundary between `core/` (Zig) and
`extension/` (C++ GDExtension shim). `core/abi.zig` is the sole exporter
of this surface, and an ABI conformance suite (`abitest.zig`) checks the
header and symbol surface stay in lockstep (`TASK-012.01`, `TASK-012.02`,
`TASK-012.03`).

World lifecycle, per-tick input/step/pump, per-player/per-object state,
canonical dump/checksum, and ordered event draining are declared here
(`TASK-012.01`); `core/abi_header_check.c` is a compile-only smoke test
proving every declared symbol is genuinely usable, run via
`zig cc -std=c11 -Wall -Wextra -c core/abi_header_check.c`. See the
header's own top comment for why `jnb_world` is a small caller-owned
handle rather than the whole simulation: jumpnbump's already-ported
Phase 3 modules reach `player[]`/`objects[]`/`ban_map[]` through
fixed-symbol `extern var`s, not a runtime pointer, so at most one
`jnb_world` is meaningful per process. `core/abi.zig` (`TASK-012.02`)
provides the implementation.
