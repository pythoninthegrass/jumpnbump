---
id: TASK-012
title: Freeze the jnb C ABI and build the GDExtension
status: Done
assignee: []
created_date: '2026-09-15 19:13'
updated_date: '2026-09-17 17:36'
labels: []
milestone: m-4
dependencies: []
priority: high
type: task
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Parent task. Design and freeze include/jumpnbump.h, a C ABI for the Zig simulation core following the disciplined pattern used by neo_snake's include/neo_snake.h (opaque caller-owned world, uint8_t-typedef'd enums never a bare C enum across the boundary, static-asserted struct sizes, two-call length-then-fill convention for every buffer). Build the godot-cpp GDExtension shim (extension/) that forwards every method 1:1 to the C ABI with no game logic of its own, including the macOS arm64 framework bundle packaging. Depends on Phase 3 (the Zig simulation core) being complete — do not start until all Phase 3 tasks are Done.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 All five subtasks are complete
- [x] #2 `zig cc -std=c11 -Wall -Wextra` compiles a program that only includes include/jumpnbump.h with zero warnings
- [x] #3 `nm -g --defined-only` on the built core shows only symbols matching ^_?jnb_
- [ ] #4 The GDExtension loads in a minimal Godot project on both Linux and macOS arm64
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
All five subtasks complete (TASK-012.01-05, commits 1a3d48b, 5638954, b5ffe22, 53006ed, b8b51c2):
- include/jumpnbump.h: frozen ABI header, static_asserted structs, no bare C enums, `zig cc -std=c11 -Wall -Wextra` compiles a header-only usage file with zero warnings (AC#2 — verified).
- core/abi.zig: sole `jnb_*` exporter; `core/abi_globals.zig` backs the pre-existing extern-var module architecture; a post-link objcopy pass localizes every non-`jnb_` symbol. `nm -g --defined-only` on the built static lib shows only `^_?jnb_` symbols (AC#3 — verified).
- core/abitest.zig: Tier-C conformance suite reached only via `@cImport`, purity-enforced by tools/validate_abi_test_purity.py; a real bug in jnb_world_dump's two-call contract was found and fixed along the way.
- extension/: godot-cpp GDExtension shim built via SCons on Linux, JumpnbumpWorld forwards every method 1:1 to a single jnb_* call, custom.py sets use_static_cpp=False. Produces game/bin/libjumpnbump.linux.template_debug.x86_64.so with entry symbol jumpnbump_library_init confirmed via `nm -D`.
- extension/SConstruct macOS block + game/bin/jumpnbump.gdextension written, matching neo_snake's proven pattern.

AC#4 ("The GDExtension loads in a minimal Godot project on both Linux and macOS arm64") is NOT fully verified: the Linux .so builds and exports the correct entry symbol, but no actual Godot project load-test was performed (that's Phase 5/TASK-014 territory per this repo's docs — game/ is still a placeholder until TASK-014.01). macOS is entirely unverified in this environment (no macOS SDK on this Linux dev machine; `scons platform=macos arch=arm64` fails inside godot-cpp's own toolchain detection before reaching this repo's code, an expected environment limitation). Treat AC#4 as open until someone runs a real Godot load-test on both platforms — tracked implicitly by Phase 5's TASK-014 work and by TASK-012.05's own unchecked AC#2/#3.
<!-- SECTION:FINAL_SUMMARY:END -->
