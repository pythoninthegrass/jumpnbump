---
id: TASK-012
title: Freeze the jnb C ABI and build the GDExtension
status: To Do
assignee: []
created_date: '2026-09-15 19:13'
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
- [ ] #1 All five subtasks are complete
- [ ] #2 `zig cc -std=c11 -Wall -Wextra` compiles a program that only includes include/jumpnbump.h with zero warnings
- [ ] #3 `nm -g --defined-only` on the built core shows only symbols matching ^_?jnb_
- [ ] #4 The GDExtension loads in a minimal Godot project on both Linux and macOS arm64
<!-- AC:END -->
