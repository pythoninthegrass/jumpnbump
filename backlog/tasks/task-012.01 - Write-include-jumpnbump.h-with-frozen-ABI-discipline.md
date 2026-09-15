---
id: TASK-012.01
title: Write include/jumpnbump.h with frozen-ABI discipline
status: To Do
assignee: []
created_date: '2026-09-15 19:15'
labels: []
milestone: m-4
dependencies: []
parent_task_id: TASK-012
priority: high
type: task
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Write include/jumpnbump.h following neo_snake's include/neo_snake.h discipline: opaque jnb_world type never defined in the header, caller-owned memory via jnb_world_size()/jnb_world_align()/jnb_world_init() with no destroy function, uint8_t-typedef'd enums with anonymous enum constants (never a bare C enum crossing the ABI, since enum width is unspecified), NSTATIC_ASSERT-equivalent size checks on every ABI struct, and a two-call length-then-fill convention for every variable-size buffer (e.g. body/state copies).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 include/jumpnbump.h defines the world lifecycle, input queueing, step/pump, state serialization, event draining, and checksum functions needed to drive the Phase 3 sim core
- [ ] #2 Every struct crossing the ABI has a static_assert on its sizeof
- [ ] #3 No enum in the header is a bare C enum; all are typedef'd fixed-width integers with named constants
- [ ] #4 zig cc -std=c11 -Wall -Wextra compiles a file that only includes this header with zero warnings
<!-- AC:END -->
