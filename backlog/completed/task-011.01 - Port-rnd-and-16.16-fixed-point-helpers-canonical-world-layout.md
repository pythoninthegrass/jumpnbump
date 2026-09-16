---
id: TASK-011.01
title: 'Port rnd() and 16.16 fixed-point helpers, canonical world layout'
status: Done
assignee: []
created_date: '2026-09-15 19:14'
updated_date: '2026-09-16 18:22'
labels: []
milestone: m-3
dependencies: []
parent_task_id: TASK-011
priority: high
type: task
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port rnd() (the LCG used throughout main.c) and the 16.16 fixed-point arithmetic helpers used by x_add/y_add velocities to Zig first, as the leaf dependency everything else in Phase 3 builds on. Define the canonical Zig world struct layout and its serialization format, matching the Phase 1 canonical state dump byte-for-byte so the difftest harness can diff against it directly.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 zig build difftest shows rnd() producing identical sequences to the C rnd() for at least 10,000 calls from various seeds
- [x] #2 16.16 fixed-point add/multiply/shift helpers match C integer-overflow and truncation semantics exactly (watch for @intCast range-checking vs C's silent truncation, per zelda3's docs/development.md hazard notes)
- [x] #3 The canonical world struct serializes to the same byte layout as the Phase 1 canonical state dump
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
core/rnd.zig graduates from the TASK-008.04 pilot into the real port: rnd() (libc rand() wrapper, comptime RAND_MAX branches kept as the C's #if), rnd_call_count ownership (exported global), and seed(). core/fixed16.zig adds the 16.16 helper set enumerated from main.c's actual x_add/y_add/x_acc/y_acc usage (add/sub/neg/mul, shr16/shr20/sar, bounceQuarter = -v>>2, wrapping shl4/shl16, the (v±16)&0xfff0<<16 tile snaps, snapFixedToTile); all wrap/truncate like C — Zig's <<| is saturating, so left shifts go through @bitCast to u32. core/world.zig defines the canonical World layout (player_t/object_t struct twins per globals.pre + frame_num/rnd_call_count + ban_map 17x22) and dumpTo(), emitting exactly the 11456-byte little-endian byte sequence checksum_fold_u32 folds (docs/checksum-format.md). core/c_ref/fixed16.c is the renamed-C reference for the helpers; compileRenamedCRef now adds -fwrapv so the reference wraps like the -ffast-math oracle instead of trapping in UBSan. rnd_difftest.zig replaces the 36-tick pilot: 11,700 rnd() calls across 9 seeds x 1300 (fresh-seed pairs, asm memory barriers to keep the optimizer from reordering srand/rnd across iterations), fixed16 boundary + 20k-iteration fuzz vs the compiled C, and world dump determinism/length checks. world.zig's Tier-A fold-equivalence test pins the dump byte order against a field-by-field C-order fold.
<!-- SECTION:NOTES:END -->
