---
id: TASK-011.07
title: Port game_loop into step() + pump() with an event stream
status: To Do
assignee: []
created_date: '2026-09-15 19:15'
labels: []
milestone: m-3
dependencies: []
parent_task_id: TASK-011
priority: high
type: task
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port main.c's game_loop (~lines 1239-1430) into a pure Zig step(world, inputs) function representing exactly one tick, plus a pump() accumulator on top of it (matching neo_snake's ns_step/ns_pump split). step() must emit an ordered event stream (sfx cue, spawn, death, score change) instead of touching any presentation state, since the Godot layer in Phase 5 consumes events rather than diffing snapshots. This is the last and most integrative subtask in Phase 3 — it depends on every other Phase 3 subtask being complete.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zig build difftest passes against the full Phase 1 corpus end-to-end (not just per-subsystem traces) with zero checksum mismatches
- [ ] #2 step() is a pure function of (world, inputs) -> (world, events) with no global mutable state outside the world struct
- [ ] #3 pump() correctly derives the number of ticks to run from an injected delta, matching the original's 60Hz pacing
- [ ] #4 The event stream covers at minimum: sfx triggers, object spawns, player deaths, and score changes
<!-- AC:END -->
