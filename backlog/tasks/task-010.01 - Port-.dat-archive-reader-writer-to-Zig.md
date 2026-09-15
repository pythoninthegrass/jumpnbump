---
id: TASK-010.01
title: Port .dat archive reader/writer to Zig
status: To Do
assignee: []
created_date: '2026-09-15 19:14'
labels: []
milestone: m-2
dependencies: []
parent_task_id: TASK-010
priority: high
type: task
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port the .dat archive format to Zig: u32 entry count, entries of {char[12] name, u32 offset, u32 size}, followed by concatenated payloads, with transparent gzip/bzip2 decompression of the outer file. Preserve the prefix-match lookup behavior of dat_open (strnicmp against strlen(file_name), not equality) bug-for-bug, since real .dat files and menu.c depend on it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The Zig reader opens data/jumpbump.dat and returns byte-identical payloads to dat_open/dat_filelen for every named entry
- [ ] #2 The prefix-match lookup quirk (querying "menu" can match "menumask.pcx") is preserved and covered by a test
- [ ] #3 gzip and bzip2 outer-file decompression both work
- [ ] #4 A writer can round-trip: pack then unpack produces byte-identical files to the C jnbpack output
<!-- AC:END -->
