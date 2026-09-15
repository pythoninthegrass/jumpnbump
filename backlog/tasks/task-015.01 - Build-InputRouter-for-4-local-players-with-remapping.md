---
id: TASK-015.01
title: Build InputRouter for 4 local players with remapping
status: To Do
assignee: []
created_date: '2026-09-15 19:16'
labels: []
milestone: m-6
dependencies: []
parent_task_id: TASK-015
priority: high
type: task
ordinal: 50000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Build game/platform/input_router.gd routing keyboard input for up to 4 local players with defaults matching the original scheme (P1 arrows+up, P2 WASD, P3 IJL, P4 numpad 4/6/8), gamepad support, and a persisted keybind codec for remapping. Be aware of the neo_snake gotcha: rebinds are applied from a save file at startup, so a later change to the coded defaults has no effect on a machine that already has a save file — document this explicitly in the implementation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Default keybindings match the original KEY_PL1..4_LEFT/RIGHT/JUMP scheme from globals.pre
- [ ] #2 At least one gamepad can control a player
- [ ] #3 Rebinding a key persists across restarts via a save file, and the save-file-precedence gotcha is documented in a code comment
- [ ] #4 InputRouter emits direction/jump signals only; it holds no game state
<!-- AC:END -->
