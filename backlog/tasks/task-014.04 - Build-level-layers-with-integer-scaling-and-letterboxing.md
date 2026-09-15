---
id: TASK-014.04
title: Build level layers with integer scaling and letterboxing
status: To Do
assignee: []
created_date: '2026-09-15 19:16'
labels: []
milestone: m-5
dependencies: []
parent_task_id: TASK-014
priority: medium
type: task
ordinal: 46000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Compose the background and masked-foreground level layers from the asset pipeline at the original 400x256 design resolution, with correct integer scaling and letterboxing on wider/taller windows via canvas_items/keep stretch mode.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The level renders at 400x256 with the masked foreground correctly composited over sprites
- [ ] #2 Resizing the window preserves aspect ratio via letterboxing with no stretching distortion
- [ ] #3 Window sizing logic is set in code (not hardcoded in project.godot) to allow for future display-scale awareness, matching the neo_snake GameScreen._ready() pattern
<!-- AC:END -->
