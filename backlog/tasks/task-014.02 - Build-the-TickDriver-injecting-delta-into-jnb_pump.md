---
id: TASK-014.02
title: Build the TickDriver injecting delta into jnb_pump
status: Done
assignee: []
created_date: '2026-09-15 19:16'
updated_date: '2026-09-18 00:15'
labels: []
milestone: m-5
dependencies: []
parent_task_id: TASK-014
priority: high
type: task
ordinal: 44000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Write game/simulation/tick_driver.gd and game/simulation/world.gd (a pure pass-through wrapper over JumpnbumpWorld re-exporting its constants, matching neo_snake's SimulationWorld), driven from _process with injected delta so it stays independently unit-testable. TickDriver calls world.pump(dt_us) each frame; a gate boolean handles pause without touching the core.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 TickDriver.advance_frame(world, delta_ms, running, gate) is a pure static function taking delta as a parameter, testable without a running scene
- [x] #2 Pausing sets gate=false and the world state does not advance while paused
- [x] #3 The 60Hz original tick rate is preserved through jnb_pump's internal accumulator, not reimplemented in GDScript
<!-- AC:END -->
