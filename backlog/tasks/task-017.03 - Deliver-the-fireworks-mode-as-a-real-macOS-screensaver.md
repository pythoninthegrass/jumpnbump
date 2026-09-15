---
id: TASK-017.03
title: Deliver the fireworks mode as a real macOS screensaver
status: To Do
assignee: []
created_date: '2026-09-15 19:16'
labels: []
milestone: m-8
dependencies: []
parent_task_id: TASK-017
priority: low
type: task
ordinal: 60000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement whichever delivery mechanism the spike recommended (embedded Godot in a ScreenSaverView, or a native Swift/Metal view linking the Zig core directly) so the ported fireworks mode installs and runs as a real macOS screensaver, selectable via System Settings.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The screensaver installs via a standard .saver bundle and appears in System Settings > Screen Saver
- [ ] #2 It runs correctly when triggered by the system idle timer and previews correctly in the System Settings preview pane
- [ ] #3 It exits cleanly when user input resumes
<!-- AC:END -->
