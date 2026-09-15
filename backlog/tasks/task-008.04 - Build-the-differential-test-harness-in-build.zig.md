---
id: TASK-008.04
title: Build the differential-test harness in build.zig
status: To Do
assignee: []
created_date: '2026-09-15 19:14'
labels: []
milestone: m-1
dependencies: []
parent_task_id: TASK-008
priority: high
type: task
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a difftest step to core/build.zig that compiles the pre-port .c source a second time with preprocessor-renamed symbols (e.g. -DFuncName=c_FuncName, following zelda3's compileRenamedCRef technique at ~/git/zelda3/build.zig), links it alongside the corresponding Zig port, and replays the Phase 1 corpus through both, diffing checksums per tick. This harness is what every Phase 3 porting subtask will run before being considered complete.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zig build difftest runs the corpus through a renamed-C-reference and a Zig stub and reports per-tick checksum mismatches
- [ ] #2 The harness works on macOS despite the documented macOS objcopy/symbol-renaming gotcha from zelda3's build.zig
- [ ] #3 A trivial passthrough Zig stub (e.g. wrapping rnd()) validates the harness end-to-end with zero mismatches
<!-- AC:END -->
