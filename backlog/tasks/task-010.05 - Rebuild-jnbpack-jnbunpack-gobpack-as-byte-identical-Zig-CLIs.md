---
id: TASK-010.05
title: Rebuild jnbpack/jnbunpack/gobpack as byte-identical Zig CLIs
status: To Do
assignee: []
created_date: '2026-09-15 19:14'
labels: []
milestone: m-2
dependencies: []
parent_task_id: TASK-010
priority: high
type: task
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Using the Zig .dat/.gob/PCX codecs from the sibling subtasks, rebuild jnbpack, jnbunpack, and gobpack as thin Zig CLI wrappers. Verify their output is byte-identical to the current C tools' output across every file in data/. This also removes gobpack.c's private duplicated copies of read_pcx/write_pcx and gob_t once the Zig codecs are the single source of truth.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Running the Zig jnbpack on data/'s DATAFILES list produces a byte-identical jumpbump.dat to the C jnbpack
- [ ] #2 Running the Zig gobpack on rabbit/objects/numbers/font produces byte-identical .gob files to the C gobpack
- [ ] #3 jnbunpack round-trips: unpacking the Zig-built jumpbump.dat recovers the original input files byte-for-byte
- [ ] #4 modify/'s C tools are kept (not deleted) as the reference for this comparison, per the never-delete-the-.c rule
<!-- AC:END -->
