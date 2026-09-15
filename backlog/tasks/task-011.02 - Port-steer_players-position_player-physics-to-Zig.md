---
id: TASK-011.02
title: Port steer_players / position_player physics to Zig
status: To Do
assignee: []
created_date: '2026-09-15 19:14'
labels: []
milestone: m-3
dependencies: []
parent_task_id: TASK-011
priority: high
type: task
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port main.c's steer_players and position_player (lines ~1945-2284): gravity, jumping, and water/ice/spring tile interactions using 16.16 fixed-point velocities. Depends on the fixed-point helpers subtask being done first.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zig build difftest passes against the Phase 1 corpus for all traces exercising water/ice/spring tiles and jumping, with zero checksum mismatches
- [ ] #2 The SDL C binary still builds and plays correctly using the C steer_players/position_player until this port supersedes them
<!-- AC:END -->
