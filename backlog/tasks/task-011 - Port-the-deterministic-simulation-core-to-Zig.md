---
id: TASK-011
title: Port the deterministic simulation core to Zig
status: Done
assignee: []
created_date: '2026-09-15 19:13'
updated_date: '2026-09-17 15:27'
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
- [x] #1 All eight subtasks are complete
- [x] #2 The full Zig sim core passes zig build difftest against the C oracle corpus from Phase 1 with zero mismatches
- [x] #3 The SDL C binary still builds and runs correctly throughout, using the C implementations until each is superseded
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
All eight subtasks (TASK-011.01-011.08) are complete and merged into local main. The deterministic simulation core (rnd/fixed-point/world layout, steer_players/position_player, collision_check/player_kill, add_object/update_objects particle system, cpu_move AI, update_flies, game_loop's step()/pump() with an event stream, and the core-purity boundary check) is fully ported to Zig.

zig build test/difftest/abi/abitest all pass on main. All 10 Phase 1 corpus traces produce zero checksum mismatches against a freshly built jumpnbump -headless binary (verified directly against the legacy oracle, not just via the Zig harness). The legacy SDL C binary still builds and runs via `make`. tools/validate_simulation_boundary.py --sim-only confirms the simulation core references no presentation or audio API and does no file I/O outside the asset-loading paths.

Two real, pre-existing bugs were found and fixed during TASK-011.07's full end-to-end corpus replay (unreachable by any prior per-subsystem difftest): a C argument-evaluation-order assumption in collision.zig/steer.zig's gore/smoke rnd() draws (the shipped gcc-built oracle evaluates right-to-left, not left-to-right), and steer.zig's spring_branch_off flag defaulting to skip the spring object's visual reset in production. A third bug (banTile's negative-offset pointer arithmetic) caused a segfault on the four-player corpus trace and was fixed by computing the offset in isize at full pointer width. TASK-011.08's boundary checker also surfaced a real core-purity gap (add_pob/add_leftovers/dj_set_sfx_channel_volume calls in already-merged objects.zig/flies.zig) which was resolved by extending the event stream with draw/sfx_volume classes rather than silently dropping verification coverage.
<!-- SECTION:FINAL_SUMMARY:END -->
