---
id: TASK-016.01
title: Runtime .dat loading and atlas building for custom levels
status: To Do
assignee: []
created_date: '2026-09-15 19:16'
labels: []
milestone: m-8
dependencies: []
parent_task_id: TASK-016
priority: low
type: task
ordinal: 55000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add runtime (not build-time) loading of user-created .dat files through the Zig asset codecs from Phase 2, building Godot ImageTexture/atlas resources on the fly instead of ahead-of-time, so players can drop in community-made .dat files documented in levelmaking/.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A .dat file not present at build time can be loaded at runtime and produces correctly rendered sprites and level layers
- [ ] #2 Runtime atlas construction does not require a Godot editor re-import step
- [ ] #3 Loading time for a typical custom .dat is reasonable (no multi-second stall)
<!-- AC:END -->
