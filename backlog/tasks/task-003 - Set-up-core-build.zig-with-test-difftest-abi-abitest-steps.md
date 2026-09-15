---
id: TASK-003
title: Set up core/build.zig with test/difftest/abi/abitest steps
status: Done
assignee: []
created_date: '2026-09-15 19:12'
updated_date: '2026-09-15 20:09'
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
- [x] #1 `zig build test`, `zig build difftest`, `zig build abi`, and `zig build abitest` all run successfully against an empty/stub core/
- [x] #2 Zig 0.16.0 (the pinned version) is used, verified via `mise which zig`
- [x] #3 The build.zig structure documents (in comments) which step each future porting task will populate
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Follow neo_snake's core/build.zig convention (test/abi/abitest steps, abi.zig as sole exporter) and zelda3's compileRenamedCRef technique (documented as the future basis for difftest) since jumpnbump ports existing C, unlike neo_snake's from-scratch corpus replay. Wire all four steps against empty stub files (abi.zig, abitest.zig) with empty test/difftest module-file arrays that future porting tasks (TASK-011.*, TASK-008.04, TASK-012.02, TASK-012.03) append to.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified `mise which zig` resolves to /home/lance/.local/share/mise/installs/zig/0.16.0/bin/zig (matches .tool-versions).

Ran `zig build test`, `zig build difftest`, `zig build abi`, `zig build abitest` from core/ -- all exit 0 against the empty stub (abi.zig/abitest.zig placeholders, empty unit_test_files/diff_test_files arrays).

zig build abi produces zig-out/lib/libjumpnbump.a (currently symbol-less, since abi.zig has no exports yet -- TASK-012.02).

Added .zig-cache/ and zig-out/ to .gitignore; core/'s build artifacts weren't previously covered.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Created core/build.zig wiring up the four named steps (`test`, `difftest`, `abi`, `abitest`) against an empty/stub core/, per the task's scope (no simulation code yet).

- `test`/`difftest` are step aggregators over empty `unit_test_files`/`diff_test_files` arrays, mirroring zelda3's pattern -- each future TASK-011.* port appends its own test file; TASK-008.04 will add the renamed-C-reference (`compileRenamedCRef`) machinery to `difftest` once a ported module exists to diff against.
- `abi` builds `core/abi.zig` (currently an empty placeholder file with no `export fn`) as a static lib (`libjumpnbump.a`, `.pic = true` for the eventual GDExtension shared-lib link), for TASK-012.02 to populate.
- `abitest` runs `core/abitest.zig` (a placeholder `std.testing.expect(true)` test) linked against the abi lib; once `../include/jumpnbump.h` exists (TASK-012.01) it will switch to `@cImport`-only conformance tests (TASK-012.03).
- Comments throughout the build.zig cross-reference the task IDs that will populate each stub, satisfying AC #3.

Verified: `mise which zig` resolves to the pinned 0.16.0, and all four `zig build <step>` commands exit 0 from `core/`. Added `.zig-cache/` and `zig-out/` to `.gitignore` (previously uncovered).

No Taskfile/CI wiring included -- out of scope for this task (TASK-006 covers CI).
<!-- SECTION:FINAL_SUMMARY:END -->
