---
id: TASK-012.01
title: Write include/jumpnbump.h with frozen-ABI discipline
status: Done
assignee: []
created_date: '2026-09-15 19:15'
updated_date: '2026-09-17 17:12'
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
- [x] #1 include/jumpnbump.h defines the world lifecycle, input queueing, step/pump, state serialization, event draining, and checksum functions needed to drive the Phase 3 sim core
- [x] #2 Every struct crossing the ABI has a static_assert on its sizeof
- [x] #3 No enum in the header is a bare C enum; all are typedef'd fixed-width integers with named constants
- [x] #4 zig cc -std=c11 -Wall -Wextra compiles a file that only includes this header with zero warnings
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Wrote include/jumpnbump.h: world lifecycle (jnb_world_size/align/init/reset), per-tick input+step+pump, per-player/per-object views, canonical dump+checksum (core/world.zig's dumpTo/fnv1a32), and ordered event drain (core/game_loop.zig's Events). jnb_result is int32_t, jnb_event_kind is uint8_t — no bare C enum crosses the ABI. Every struct has a JNB_STATIC_ASSERT on its sizeof. core/abi_header_check.c compiles clean with `zig cc -std=c11 -Wall -Wextra` (verified, zero warnings).

Key design divergence from neo_snake, documented in the header's top comment: jumpnbump's already-ported Phase 3 modules reach player[]/objects[]/ban_map[] via fixed-symbol `extern var`, not a runtime pointer, so jnb_world cannot be fully relocatable caller memory the way ns_world is. jnb_world_size() covers only the genuinely per-instance bookkeeping (game_loop.zig's State + PumpState) — at most one jnb_world is meaningful per process, stated explicitly rather than left implicit. jnb_world_init takes raw level bytes + length (parsed via core/levelmap.zig) since core/ has no file I/O outside dat.zig/levelmap.zig. No deserialize/load function: core/world.zig only implements dumpTo(), so the ABI doesn't invent round-trip behavior that doesn't exist yet.
<!-- SECTION:FINAL_SUMMARY:END -->
