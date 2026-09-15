---
id: TASK-010.04
title: Port levelmap.txt parser to Zig
status: To Do
assignee: []
created_date: '2026-09-15 19:14'
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
- [ ] #1 Parsing data/levelmap.txt in Zig produces a ban_map identical to the C read_level output
- [ ] #2 The row-16 force-solid-floor behavior is preserved and covered by a test
- [ ] #3 Malformed or short level files produce a clear error rather than out-of-bounds reads
<!-- AC:END -->
