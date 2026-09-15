# include/

`jumpnbump.h`: the frozen C ABI boundary between `core/` (Zig) and
`extension/` (C++ GDExtension shim). `core/abi.zig` is the sole exporter
of this surface, and an ABI conformance suite (`abitest.zig`) checks the
header and symbol surface stay in lockstep (`TASK-012.01`, `TASK-012.02`,
`TASK-012.03`).

Placeholder until `TASK-012.01` writes the header.
