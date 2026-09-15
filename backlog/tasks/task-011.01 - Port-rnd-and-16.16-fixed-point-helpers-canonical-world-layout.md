---
id: TASK-011.01
title: 'Port rnd() and 16.16 fixed-point helpers, canonical world layout'
status: To Do
assignee: []
created_date: '2026-09-15 19:14'
labels: []
milestone: m-3
dependencies: []
parent_task_id: TASK-011
priority: high
type: task
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port rnd() (the LCG used throughout main.c) and the 16.16 fixed-point arithmetic helpers used by x_add/y_add velocities to Zig first, as the leaf dependency everything else in Phase 3 builds on. Define the canonical Zig world struct layout and its serialization format, matching the Phase 1 canonical state dump byte-for-byte so the difftest harness can diff against it directly.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zig build difftest shows rnd() producing identical sequences to the C rnd() for at least 10,000 calls from various seeds
- [ ] #2 16.16 fixed-point add/multiply/shift helpers match C integer-overflow and truncation semantics exactly (watch for @intCast range-checking vs C's silent truncation, per zelda3's docs/development.md hazard notes)
- [ ] #3 The canonical world struct serializes to the same byte layout as the Phase 1 canonical state dump
<!-- AC:END -->
