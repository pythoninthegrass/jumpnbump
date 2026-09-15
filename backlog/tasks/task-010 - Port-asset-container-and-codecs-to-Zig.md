---
id: TASK-010
title: Port asset container and codecs to Zig
status: To Do
assignee: []
created_date: '2026-09-15 19:13'
labels: []
milestone: m-2
dependencies: []
priority: high
type: task
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Parent task. Port the .dat archive format, the .gob sprite format, 8-bit PCX decoding, and levelmap.txt parsing from C (main.c, sdl/gfx.c, modify/) to Zig, preserving every quirk of the original formats bug-for-bug so existing data files and any future user-created .dat files remain compatible. Reimplement the jnbpack/jnbunpack/gobpack CLI tools in Zig, verified byte-identical to the current C tools' output on the existing data/ assets. Depends on Phase 1 (the C oracle) being complete — do not start until all Phase 1 tasks are Done.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All five subtasks are complete
- [ ] #2 The Zig-built jnbpack/jnbunpack/gobpack produce byte-identical output to the C tools on all files in data/
<!-- AC:END -->
