---
id: TASK-016
title: Support custom user .dat levels
status: To Do
assignee: []
created_date: '2026-09-15 19:14'
labels: []
milestone: m-8
dependencies: []
priority: low
type: task
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Parent task. Add runtime loading of user-created .dat files (as documented in levelmaking/) through the Zig asset codecs, building Godot textures/atlases at runtime instead of at build time, plus an in-game level picker with drag-and-drop and validation/error reporting for malformed files. Optionally, port a Zig ProTracker (.mod) player so custom levels can ship and play their own music without a build-time OGG conversion step. Depends on Phase 6 (playable macOS) being complete — do not start until all Phase 6 tasks are Done.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All three subtasks are complete
- [ ] #2 A community-made .dat file from levelmaking/ examples loads and plays correctly at runtime
- [ ] #3 Malformed or incompatible .dat files produce a clear in-game error rather than a crash
<!-- AC:END -->
