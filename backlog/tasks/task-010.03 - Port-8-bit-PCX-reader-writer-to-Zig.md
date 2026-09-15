---
id: TASK-010.03
title: Port 8-bit PCX reader/writer to Zig
status: To Do
assignee: []
created_date: '2026-09-15 19:14'
labels: []
milestone: m-2
dependencies: []
parent_task_id: TASK-010
priority: high
type: task
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port 8-bit paletted PCX decoding (and the encoding used by gobpack) to Zig, covering level.pcx, mask.pcx, menu.pcx, menumask.pcx, and the *.pcx/*.txt frame-table pairs in data/. This also lets gobpack's private, duplicated read_pcx/write_pcx implementation be replaced by one shared codec.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The Zig decoder produces identical pixel data and 768-byte palette to read_pcx for every PCX file in data/
- [ ] #2 A round-trip encode/decode of a PCX produces pixel-identical output
- [ ] #3 gobpack's duplicated PCX code is noted as a future dedup target once the Zig CLI replacement lands
<!-- AC:END -->
