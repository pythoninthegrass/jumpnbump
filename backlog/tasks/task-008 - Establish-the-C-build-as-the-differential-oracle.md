---
id: TASK-008
title: Establish the C build as the differential oracle
status: Done
assignee: []
created_date: '2026-09-15 19:12'
updated_date: '2026-09-16 14:46'
labels: []
milestone: m-1
dependencies: []
priority: high
type: task
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Parent task. Every subsystem ported to Zig in Phase 3 must be verified against the original C behavior. This phase makes that possible: run the existing SDL C build headlessly and deterministically, dump canonical state with a checksum every frame, record a corpus of input traces covering the game's mechanics, and build the differential-test harness that will compile the pre-port .c a second time under renamed symbols and diff its output against the Zig port. This phase gates all of Phase 3 — no simulation code should be ported to Zig until the oracle corpus exists.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 All four subtasks are complete and the resulting corpus + harness can validate a trivial Zig stub against the C original
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
All four subtasks (008.01-008.04) are Done. 008.01: headless deterministic C build. 008.02: FNV-1a per-frame canonical-state checksum (docs/checksum-format.md). 008.03: 9 checksummed JSONL corpus traces under tests/corpus/, plus -headless-players/-headless-ai to cover 1-4 players and AI on/off. 008.04: core/build.zig's `difftest` step, with rnd_difftest.zig as a trivial passthrough pilot (main.c's rnd() vs a Zig reimplementation, both diffed against a renamed-C-reference built via zelda3's -D<sym>=c_<sym> technique) validating the harness end-to-end with zero mismatches.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Established the C build as the Phase 3 differential-test oracle. All four subtasks landed:

- **TASK-008.01**: `-headless -seed -input` mode on the existing SDL C build — fixed 60Hz tick, no wall-clock dependency, scripted JSONL input, seeded RNG.
- **TASK-008.02**: an FNV-1a canonical-state checksum (player[]/objects[]/ban_map/rnd_call_count) emitted once per headless tick, byte layout documented in docs/checksum-format.md.
- **TASK-008.03**: `-headless-players`/`-headless-ai` extend headless mode to multiple/CPU-controlled players; 9 checksummed JSONL traces committed under tests/corpus/ covering 1/2/4 players, AI on/off, gore on/off, flies on/off, water/ice/spring tile contact, and bump-kills, with a README documenting the format and how to add traces.
- **TASK-008.04**: `core/build.zig`'s `difftest` step ports zelda3's preprocessor-based (`-D<sym>=c_<sym>`) C-symbol-renaming technique — no objcopy, so no macOS leading-underscore gotcha — and a trivial `rnd_difftest.zig` pilot proves the renamed-C-reference-vs-Zig harness works end-to-end with zero mismatches.

Phase 3 (`TASK-011.*`) can now port `main.c` subsystems into `core/*.zig` modules one at a time, each verified against this oracle corpus via `zig build difftest` before moving to the next.

No gaps carried forward from the subtasks beyond the expected ones: real per-tick corpus replay in `difftest` (vs. the current rnd()-only pilot) lands naturally as each `TASK-011.*` module is ported, since that's the first point a Zig module has real per-tick state to checksum.
<!-- SECTION:FINAL_SUMMARY:END -->
