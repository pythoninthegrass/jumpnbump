---
id: TASK-011
title: Port the deterministic simulation core to Zig
status: To Do
assignee: []
created_date: '2026-09-15 19:13'
labels: []
milestone: m-3
dependencies: []
priority: high
type: task
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Parent task. Port main.c's physics, collision, AI, particle, and game-loop logic to Zig, bottom-up leaf-first (fixed-point helpers first, game_loop last), one subsystem at a time per zelda3's incremental methodology. Every subtask must keep the SDL C binary building and pass the Phase 1 differential-test harness before the next subtask begins. The simulation state is entirely integer/fixed-point (player_t, object_t, ban_map, 16.16 fixed-point velocities) with no floats, which makes exact byte-for-byte differential testing possible throughout. Depends on Phase 1 and Phase 2 being complete — do not start until all their tasks are Done.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All eight subtasks are complete
- [ ] #2 The full Zig sim core passes zig build difftest against the C oracle corpus from Phase 1 with zero mismatches
- [ ] #3 The SDL C binary still builds and runs correctly throughout, using the C implementations until each is superseded
<!-- AC:END -->
