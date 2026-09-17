---
id: TASK-011.04
title: Port add_object / update_objects particle system to Zig
status: Done
assignee: []
created_date: '2026-09-15 19:15'
labels: []
milestone: m-3
dependencies: []
parent_task_id: TASK-011
priority: high
type: task
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port main.c's add_object and update_objects (~lines 2284-2643), covering all 8 particle types (spring, splash, smoke, yellow/pink butterfly, fur, flesh, flesh_trace) to Zig.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 zig build difftest passes against the Phase 1 corpus for all traces exercising every one of the 8 OBJ_* particle types, with zero checksum mismatches
- [x] #2 The 200-slot objects[] array's reuse/allocation behavior matches the C original exactly
<!-- AC:END -->
