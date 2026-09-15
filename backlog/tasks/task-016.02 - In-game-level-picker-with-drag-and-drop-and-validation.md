---
id: TASK-016.02
title: In-game level picker with drag-and-drop and validation
status: To Do
assignee: []
created_date: '2026-09-15 19:16'
labels: []
milestone: m-8
dependencies: []
parent_task_id: TASK-016
priority: low
type: task
ordinal: 56000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a menu screen for selecting a custom .dat level, supporting drag-and-drop of a .dat file onto the game window, with validation that produces a clear in-game error message for malformed or incompatible files rather than a crash.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A .dat file can be selected via an in-game picker and via drag-and-drop
- [ ] #2 A deliberately corrupted .dat file produces a clear, non-crashing in-game error
- [ ] #3 The picker lists previously loaded custom levels for quick re-selection
<!-- AC:END -->
