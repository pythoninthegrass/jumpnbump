---
id: TASK-011.07
title: Port game_loop into step() + pump() with an event stream
status: Done
assignee: []
created_date: '2026-09-15 19:15'
updated_date: '2026-09-17 14:50'
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
- [x] #1 zig build difftest passes against the full Phase 1 corpus end-to-end (not just per-subsystem traces) with zero checksum mismatches
- [x] #2 step() is a pure function of (world, inputs) -> (world, events) with no global mutable state outside the world struct
- [x] #3 pump() correctly derives the number of ticks to run from an injected delta, matching the original's 60Hz pacing
- [x] #4 The event stream covers at minimum: sfx triggers, object spawns, player deaths, and score changes
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added core/game_loop.zig: Inputs/Events/State + step()/pump(). step() runs applyInputs -> cpu_move -> updatePlayerActions -> steer_players -> collision_check -> update_objects -> update_flies in main.c's own order, then classifies sfx/death/score/spawn events from the tick's resulting diffs (state threaded explicitly per AC#2). pump() derives tick count from an injected delta_ms via a x3-scaled integer accumulator (1000*3/60==50 exactly) for AC#3's 60Hz pacing with no float.

AC#1 (core/game_loop_difftest.zig) replays all 10 Phase 1 corpus traces end-to-end through step(), reconstructing init_level()'s object-seeding sequence and loading the real data/jumpbump.dat level (not the synthetic per-subsystem test grids other difftests use) so checksums match the actual recorded corpus. Zero mismatches across all 10 traces, verified both via zig build difftest and by running the freshly-built legacy jumpnbump -headless binary directly against every corpus file.

Found and fixed three real, pre-existing bugs surfaced by full end-to-end replay (none were reachable by any prior per-subsystem difftest):
1. core/collision.zig's furGore/fleshGore and core/steer.zig's smokePuff/two inline smoke sites assumed add_object()'s multi-rnd()-argument call lists evaluate left to right; the shipped gcc-built oracle actually evaluates right to left for this call shape (verified empirically: a minimal repro compiles differently under zig cc/clang vs system gcc). Fixed the Zig draw order to match gcc's actual order, and edited core/c_ref/collision.c and core/c_ref/steer.c (test-only renamed-C references, not main.c) to sequence the same calls explicitly so they no longer depend on their own compiler's (clang's) opposite unspecified-evaluation-order choice.
2. core/steer.zig's `spring_branch_off` flag (added in TASK-011.02) defaulted to 1 (skip), so springAnimation()'s spring-object visual reset never ran in production; nothing ever set it to 0. Removed the flag and call springAnimation() unconditionally, matching main.c's unconditional reset.
3. core/steer.zig's banTile() cast a negative row/col to u32 before widening to usize, turning a small backward (in-bounds-adjacent) pointer offset into a multi-gigabyte forward one -- segfaulting instead of reading the adjacent memory the real oracle's raw pointer arithmetic reads. Fixed by computing the flat offset in isize and wrapping it into the base pointer's address at full (usize) pointer width.

Also fixed an unrelated regression from this task's own build.zig edit: diff_test_files had been replaced with a single-element array instead of appended to, silently dropping rnd/cpu_move/flies/steer/objects/collision difftests from `zig build difftest`. Restored the full list. Made core/steer.zig's two inline Tier-A tests self-contained (seed their own ban_map fixture) since they're pulled transitively into the shared Tier-B binary where a linked C reference's strong ban_map_raw definition, or another corpus trace's leftover state, can otherwise leave them searching an all-zero grid forever.

Verified: zig build test/difftest/abi/abitest all pass; legacy `make` build succeeds; all 10 corpus traces produce zero checksum mismatches against a freshly built jumpnbump -headless binary.
<!-- SECTION:NOTES:END -->
