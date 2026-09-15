---
id: TASK-008.02
title: Canonical state dump and per-frame checksum
status: To Do
assignee: []
created_date: '2026-09-15 19:14'
labels: []
milestone: m-1
dependencies: []
parent_task_id: TASK-008
priority: high
type: task
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a canonical serialization of the simulation-relevant state (player[], objects[], ban_map, RNG state) from the headless C build, and compute a checksum of it every frame. This is the format the Zig port's differential tests and later the Godot corpus-replay tests will diff against.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A documented byte layout for the canonical state dump exists (field order, sizes, endianness)
- [ ] #2 The headless C build emits a per-frame checksum to stdout or a log file
- [ ] #3 The checksum changes deterministically with gameplay state and is stable across repeated runs of the same input
<!-- AC:END -->
