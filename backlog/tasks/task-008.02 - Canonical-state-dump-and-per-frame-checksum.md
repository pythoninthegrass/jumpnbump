---
id: TASK-008.02
title: Canonical state dump and per-frame checksum
status: Done
assignee:
  - pythoninthegrass
created_date: '2026-09-15 19:14'
updated_date: '2026-09-16 14:26'
labels: []
milestone: m-1
dependencies: []
modified_files:
  - main.c
  - docs/checksum-format.md
parent_task_id: TASK-008
priority: high
type: task
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a canonical serialization of the simulation-relevant state (player[], objects[], ban_map, RNG state) from the headless C build, and compute a checksum of it every frame. This is the format the Zig port's differential tests and later the Godot corpus-replay tests will diff against.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A documented byte layout for the canonical state dump exists (field order, sizes, endianness)
- [x] #2 The headless C build emits a per-frame checksum to stdout or a log file
- [x] #3 The checksum changes deterministically with gameplay state and is stable across repeated runs of the same input
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
FNV-1a 32-bit checksum folded over frame_num, rnd_call_count (proxy for rand()'s internal state), player[] (22 ints/player x4, declaration order), objects[] (12 ints x200, declaration order, all slots regardless of `used`), and ban_map[17][22]. Each value folded as 4 explicit little-endian bytes regardless of host endianness. Emitted once per headless tick as `FRAME <n> CHECKSUM <hex>` to stdout, right after update_objects()/update_flies() and before the (headless-skipped) render block. Byte layout documented in docs/checksum-format.md.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified via tests/fixtures/headless-smoke.jsonl: two runs with -seed 1 produce byte-identical FRAME/CHECKSUM sequences (diff clean, 21 frames), and checksums differ frame-to-frame during the p1_right/p1_jump/p1_left movement in the trace, confirming the hash is sensitive to gameplay state rather than constant.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added a canonical per-frame state checksum to headless mode, satisfying all three ACs.

**Format**: FNV-1a 32-bit over frame_num, rnd_call_count (stands in for rand()'s unobservable internal state — same seed + same call count implies same state), all 4 players' full field set, all 200 object slots' full field set, and the 17x22 ban_map — each int folded as 4 explicit little-endian bytes so the algorithm is host-endianness-independent. Documented field order, sizes, and endianness in docs/checksum-format.md.

**Emission**: one `FRAME <n> CHECKSUM <hex>` line to stdout per headless tick, from game_loop() after the tick's physics/object/flies updates and before the (already headless-skipped) render block.

**Verification**: built clean (no new warnings), ran tests/fixtures/headless-smoke.jsonl twice with the same seed — byte-identical 21-frame checksum sequence — and confirmed checksums vary tick-to-tick as the scripted player moves/jumps, proving the hash tracks gameplay state rather than being constant.

**Follow-ups for later tasks** (not gaps here): the real checksummed corpus covering all mechanics is TASK-008.03; consuming this format from the Zig differential harness is TASK-008.04.
<!-- SECTION:FINAL_SUMMARY:END -->
