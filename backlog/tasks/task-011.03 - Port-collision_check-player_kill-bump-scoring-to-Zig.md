---
id: TASK-011.03
title: Port collision_check / player_kill / bump scoring to Zig
status: To Do
assignee: []
created_date: '2026-09-15 19:14'
labels: []
milestone: m-3
dependencies: []
parent_task_id: TASK-011
priority: high
type: task
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port main.c's collision_check (player-vs-player bump resolution, ~lines 1165-1239) and player_kill/bump-scoring logic to Zig. Depends on the physics subtask being done first since collision resolution reads player positions/velocities.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zig build difftest passes against the Phase 1 corpus for all traces exercising player bumps and kills, with zero checksum mismatches
- [ ] #2 The bumped[4] per-player bump tracking and bumps counter match the C original exactly
<!-- AC:END -->
