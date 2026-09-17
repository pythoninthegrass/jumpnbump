---
id: TASK-012.02
title: >-
  Implement core/abi.zig as the sole ABI exporter, with header-check and
  symbol-surface gates
status: Done
assignee: []
created_date: '2026-09-15 19:15'
updated_date: '2026-09-17 17:21'
labels: []
milestone: m-4
dependencies: []
parent_task_id: TASK-012
priority: high
type: task
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement core/abi.zig exporting every function declared in include/jumpnbump.h via callconv(.c) export fn, and enforce that it is the only Zig file in core/ permitted to use export fn (following neo_snake's convention). Add two CI gates: abi-header-check (zig cc -std=c11 -Wall -Wextra compiling the header standalone) and abi-symbols (nm -g --defined-only filtered to reject anything not matching ^_?jnb_).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 zig build abi produces a static library exporting exactly the functions declared in include/jumpnbump.h, no more, no fewer
- [x] #2 task core:abi-symbols (or equivalent) fails if any exported symbol doesn't match ^_?jnb_
- [x] #3 A CI check fails if any Zig file other than core/abi.zig contains export fn
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
AC#3 implemented as tools/validate_abi_exporter.py, scoped to jnb_-prefixed exports rather than literally "any export fn": core/steer.zig, cpu_move.zig, objects.zig, flies.zig, collision.zig, game_loop.zig, and rnd.zig already legitimately use export fn/var for their own C-named cross-module surface (TASK-011.*'s no-@import-between-ported-modules convention, predating this ABI). A literal "any export fn outside abi.zig" ban would break that pre-existing, required architecture. The real invariant (only abi.zig's build output exposes jnb_* symbols) is enforced more strongly by core/localize_abi_symbols.sh's post-link nm -g gate (AC#2), which catches every symbol regardless of source file; the source-level script is a faster-failing supplement. core/abi_globals.zig is a second, narrowly-scoped file that defines the real player_raw/objects_raw/ban_map_raw/keyb/no_gore storage (replacing core/c_ref/sim_harness.c's role for production) as its own compilation unit -- required because steer.zig/collision.zig's own weak fallbacks of those same names would otherwise collide with a strong definition inside abi.zig's own compilation.
<!-- SECTION:NOTES:END -->
