---
id: TASK-015.02
title: Port the pixel menu to Godot Control nodes
status: To Do
assignee: []
created_date: '2026-09-15 19:16'
labels: []
milestone: m-6
dependencies: []
parent_task_id: TASK-015
priority: high
type: task
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port menu.c's menu (player colour selection, AI toggle per player, key assignment) to Godot Control nodes, keeping menu.pcx as the visual backdrop and the original layout/interaction model, but with keyboard and gamepad navigation instead of raw mouse-click regions.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The menu visually matches the original menu.pcx layout
- [ ] #2 Each of the 4 player slots can be set to human (with colour choice) or AI
- [ ] #3 Key assignment for human players is reachable and functional from the menu
- [ ] #4 The menu is navigable by keyboard and gamepad, not only mouse
<!-- AC:END -->
