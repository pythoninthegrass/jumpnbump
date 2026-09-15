---
id: TASK-016.03
title: 'Optional: Zig ProTracker (.mod) player for custom-level music'
status: To Do
assignee: []
created_date: '2026-09-15 19:16'
labels: []
milestone: m-8
dependencies: []
parent_task_id: TASK-016
priority: low
type: task
ordinal: 57000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port a ProTracker .mod playback engine to Zig so custom .dat levels can ship and play their own music at runtime without requiring the build-time .mod-to-OGG conversion step used for the base game's music in Phase 5. This is explicitly optional/conditional — only pursue it if custom levels commonly ship their own music.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A .mod file bundled in a custom .dat plays correctly at runtime via the Zig player
- [ ] #2 Playback quality is close enough to the original dj_* mixer that it isn't a regression for existing .mod assets
- [ ] #3 This task is explicitly marked optional in the task tracker and does not block the rest of Phase 8
<!-- AC:END -->
