---
id: TASK-012.03
title: Write the ABI conformance test suite (abitest.zig)
status: To Do
assignee: []
created_date: '2026-09-15 19:15'
labels: []
milestone: m-4
dependencies: []
parent_task_id: TASK-012
priority: medium
type: task
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Write core/abitest.zig, a test suite that reaches the built static library only through @cImport("jumpnbump.h") — never by directly calling internal Zig functions — to verify the C ABI surface behaves correctly end-to-end: world init/reset, input queueing, step/pump, serialization round-trips, event draining, and checksums.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zig build abitest passes and exercises every function in include/jumpnbump.h
- [ ] #2 A purity check (following neo_snake's tools/validate_abi_test_purity.py pattern) confirms abitest.zig never imports core Zig modules directly, only the C header
<!-- AC:END -->
