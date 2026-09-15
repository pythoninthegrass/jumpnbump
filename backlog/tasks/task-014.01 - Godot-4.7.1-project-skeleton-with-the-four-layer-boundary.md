---
id: TASK-014.01
title: Godot 4.7.1 project skeleton with the four-layer boundary
status: To Do
assignee: []
created_date: '2026-09-15 19:15'
labels: []
milestone: m-5
dependencies: []
parent_task_id: TASK-014
priority: high
type: task
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Godot 4.7.1 project under game/ with a single main.tscn and script, everything else assembled in code, and the four-layer directory split (game/simulation/, game/presentation/, game/platform/, game/content/) matching neo_snake's convention. Write a boundary-validator script (tools/validate_simulation_boundary.py equivalent) that fails if any script outside game/simulation/ references the GDExtension class, and wire it into task check.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 game/project.godot targets Godot 4.7 with the original 400x256 design viewport, canvas_items stretch mode, and delta_smoothing disabled
- [ ] #2 A single main.tscn exists; all other nodes are added in _ready()
- [ ] #3 The four directories exist with an enforced boundary: only game/simulation/ may reference JumpnbumpWorld or its class name
- [ ] #4 task game:boundary-check fails on a deliberately-introduced violation and passes once removed
<!-- AC:END -->
