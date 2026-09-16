---
id: TASK-010.04
title: Port levelmap.txt parser to Zig
status: Done
assignee: []
created_date: '2026-09-15 19:14'
updated_date: '2026-09-16 16:08'
labels: []
milestone: m-2
dependencies: []
parent_task_id: TASK-010
priority: medium
type: task
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port read_level's parsing of levelmap.txt (a 16-row by 22-column ASCII grid of digits 0-4 mapping to BAN_VOID/SOLID/WATER/ICE/SPRING) into ban_map to Zig, including the quirk where row 16 (the 17th row) is force-filled as BAN_SOLID regardless of what's in the file.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Parsing data/levelmap.txt in Zig produces a ban_map identical to the C read_level output
- [x] #2 The row-16 force-solid-floor behavior is preserved and covered by a test
- [x] #3 Malformed or short level files produce a clear error rather than out-of-bounds reads
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Ported levelmap.txt parsing (main.c read_level) to core/levelmap.zig.

- parse(buf, flip) reads 16 rows of 22 digits ('0'-'4'), skipping any non-digit byte between cells (newlines in practice) exactly like read_level's inner while-loop; `flip` mirrors each row's column order (main.c's `flip` global).
- Row 16 (the 17th row of the resulting 17x22 ban_map) is force-filled BAN_SOLID after parsing, regardless of what (if anything) the file contains there — unit tested directly.
- Verified against the real data/levelmap.txt: parsed output cross-checked against an independent Python re-implementation of read_level's exact digit-scanning algorithm reading the same file — all 16 rows match, including the row-14 quirk (column 9 is '4'/BAN_SPRING, not '1', which the stale hardcoded C default array in main.c's static initializer does NOT match — that initializer is a different fallback default, not what read_level actually produces from the shipped file, so it was not used as the verification reference).
- Malformed/short input (EOF before 16*22 digits are found) returns error.Truncated rather than reading out of bounds, unlike the original C (which has no such bound and would read arbitrarily far past the buffer).

All of `zig build test`, `difftest`, `abi`, `abitest`, and `zig fmt --check .` pass; no .c files modified.
<!-- SECTION:FINAL_SUMMARY:END -->
