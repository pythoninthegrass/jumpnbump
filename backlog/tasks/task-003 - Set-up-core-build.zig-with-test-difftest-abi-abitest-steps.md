---
id: TASK-003
title: Set up core/build.zig with test/difftest/abi/abitest steps
status: To Do
assignee: []
created_date: '2026-09-15 19:12'
labels: []
milestone: m-0
dependencies: []
priority: high
type: chore
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Zig build graph for core/ with named build steps: `test` (unit tests), `difftest` (differential tests against renamed C references), `abi` (build the C-ABI-exporting static lib), and `abitest` (ABI conformance tests reaching the lib only via @cImport). No simulation code exists yet — this task only needs the build graph to compile an empty core/ with these four steps wired up and runnable via `zig build <step>`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `zig build test`, `zig build difftest`, `zig build abi`, and `zig build abitest` all run successfully against an empty/stub core/
- [ ] #2 Zig 0.16.0 (the pinned version) is used, verified via `mise which zig`
- [ ] #3 The build.zig structure documents (in comments) which step each future porting task will populate
<!-- AC:END -->
