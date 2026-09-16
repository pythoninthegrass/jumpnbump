---
id: TASK-011.05
title: Port cpu_move bunny AI to Zig
status: Done
assignee: []
created_date: '2026-09-15 19:15'
labels: []
milestone: m-3
dependencies: []
parent_task_id: TASK-011
priority: high
type: task
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port main.c's cpu_move (~lines 1742-1945), the bot pathing logic that reads ban_map to steer AI-controlled players, to Zig.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 zig build difftest passes against the Phase 1 corpus for all AI-enabled traces, with zero checksum mismatches, including AI behavior on water/ice/spring tiles
<!-- AC:END -->
