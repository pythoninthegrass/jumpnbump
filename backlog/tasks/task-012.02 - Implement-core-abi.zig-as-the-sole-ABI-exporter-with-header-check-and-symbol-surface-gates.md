---
id: TASK-012.02
title: >-
  Implement core/abi.zig as the sole ABI exporter, with header-check and
  symbol-surface gates
status: To Do
assignee: []
created_date: '2026-09-15 19:15'
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
- [ ] #1 zig build abi produces a static library exporting exactly the functions declared in include/jumpnbump.h, no more, no fewer
- [ ] #2 task core:abi-symbols (or equivalent) fails if any exported symbol doesn't match ^_?jnb_
- [ ] #3 A CI check fails if any Zig file other than core/abi.zig contains export fn
<!-- AC:END -->
